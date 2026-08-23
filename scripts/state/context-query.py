#!/usr/bin/env python3
"""context-query.py — Query seletiva de contexto com BM25 puro (zero deps).

Uso:
    python3 scripts/context-query.py --ticket TCK-0119 --top-k 3
    python3 scripts/context-query.py --query "keyword matching" --top-k 5
    python3 scripts/context-query.py --ticket TCK-0119 --top-k 3 --verbose

Design: DES-0130
Ticket: TCK-0119a
"""

from __future__ import annotations

import argparse
import glob
import json
import math
import os
import re
import sys
import time
import unicodedata
from concurrent.futures import ThreadPoolExecutor
from pathlib import Path

from lib.bootstrap import get_repo_root

# ── config ──────────────────────────────────────────────────────────
K1 = 1.5
B = 0.75
MAX_FILE_BYTES = 12 * 1024  # 12 KB cobre ~99 % dos arquivos (média 2,4 KB)
_REPO_ROOT = get_repo_root()
CACHE_DIR = _REPO_ROOT / ".archagents" / ".index"
# TCK-1188/DES-0760 (PLN-0017 S2): bm25_index.json APOSENTADO — o corpus
# tokenizado vive na tabela retrieval_docs do .archagents/.index.db (build
# via build-index.py). Só resta o result-cache leve (cq_results.json).
RESULT_CACHE_FILE = CACHE_DIR / "cq_results.json"
NUM_WORKERS = min(32, (os.cpu_count() or 4) + 4)

# ── concurrency guard (TCK-0364 camada 1) ──────────────────────────
# Prevents runaway process explosions: caps concurrent context-query
# instances via a file lock + atomic counter. Default 4, overridable
# via CBOPS_CQ_MAX_CONCURRENT env var.
CQ_MAX_CONCURRENT = int(os.environ.get("CBOPS_CQ_MAX_CONCURRENT", "4"))
CQ_LOCK_FILE = Path(os.environ.get(
    "CBOPS_CQ_LOCK_FILE",
    str(_REPO_ROOT / ".archagents" / ".cq-concurrency.lock"),
))


def _acquire_concurrency_slot() -> bool:
    """Try to acquire a concurrency slot. Returns True if acquired, False if
    the max concurrent limit is exceeded (caller should exit gracefully).

    Uses fcntl.flock for mutual exclusion on the counter file, with an
    atomic increment/decrement pattern. The lock is held for the duration
    of the process via the returned file handle (stored on the function
    object so it persists until process exit).
    """
    import fcntl
    CQ_LOCK_FILE.parent.mkdir(parents=True, exist_ok=True)
    try:
        fh = open(CQ_LOCK_FILE, "r+")
    except FileNotFoundError:
        fh = open(CQ_LOCK_FILE, "w+")
    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        raw = fh.read().strip()
        count = int(raw) if raw else 0
        if count >= CQ_MAX_CONCURRENT:
            fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
            fh.close()
            return False
        fh.seek(0)
        fh.truncate()
        fh.write(str(count + 1))
        fh.flush()
        # Keep fh open — lock held until process exit. Store on function to
        # prevent GC closing the fd prematurely.
        _acquire_concurrency_slot._fh = fh
        return True
    except (OSError, ValueError) as e:
        # Fail-open: if the lock mechanism breaks, allow the process to run
        # (don't block work due to a guard failure).
        # TCK-1107/DES-0654: fail-open ALTO — guard desligado vira warning.
        logger.warning(
            "DEGRADED: guard de concorrência falhou (%s: %s) — processo segue "
            "SEM o limite de %d instâncias (CBOPS_CQ_MAX_CONCURRENT)",
            type(e).__name__, e, CQ_MAX_CONCURRENT)
        try:
            fh.close()
        except Exception:
            pass
        return True


def _release_concurrency_slot() -> None:
    """Release the concurrency slot on process exit."""
    import fcntl
    fh = getattr(_acquire_concurrency_slot, "_fh", None)
    if fh is None:
        return
    try:
        fcntl.flock(fh.fileno(), fcntl.LOCK_EX)
        fh.seek(0)
        raw = fh.read().strip()
        count = max(int(raw) - 1, 0) if raw else 0
        fh.seek(0)
        fh.truncate()
        fh.write(str(count))
        fh.flush()
        fcntl.flock(fh.fileno(), fcntl.LOCK_UN)
    except (OSError, ValueError) as e:
        # TCK-1107/DES-0654: slot vazado infla o contador e pode bloquear
        # instâncias futuras — fail-open preservado, mas agora ALTO.
        logger.warning(
            "DEGRADED: release do slot de concorrência falhou (%s: %s) — "
            "contador em %s pode ficar inflado (slots vazam até reset manual)",
            type(e).__name__, e, CQ_LOCK_FILE)
    finally:
        try:
            fh.close()
        except Exception:
            pass


import atexit
atexit.register(_release_concurrency_slot)

# ── tokenização ─────────────────────────────────────────────────────
_re_word = re.compile(r"[a-zA-Z0-9_\-/]{2,}")
_stopwords = frozenset({
    "the", "and", "for", "are", "but", "not", "you", "all", "can",
    "had", "her", "was", "one", "our", "out", "day", "get", "has",
    "him", "his", "how", "its", "may", "new", "now", "old", "see",
    "two", "way", "who", "boy", "did", "she", "use", "her", "than",
    "them", "well", "were", "that", "with", "have", "this", "will",
    "your", "from", "they", "know", "want", "been", "good", "much",
    "some", "time", "very", "when", "come", "here", "just", "like",
    "long", "make", "many", "over", "such", "take", "these", "think",
    "where", "being", "every", "great", "might", "shall", "still",
    "those", "while", "would", "there", "could", "should", "other",
    "after", "first", "never", "really", "right", "something",
    "things", "through", "years", "always", "before", "during",
    "little", "without", "de", "da", "do", "dos", "das", "em", "um",
    "uma", "para", "com", "sem", "por", "que", "se", "os", "as",
    "no", "na", "nos", "nas", "ao", "aos", "ou", "mais", "menos",
    "sobre", "entre", "depois", "antes", "durante", "contra",
    "desde", "até", "após", "perante", "trás", "porque", "como",
    "quando", "onde", "quem", "cujo", "cuja", "cujos", "cujas",
    "qual", "quais", "quanto", "quanta", "quantos", "quantas",
    "todo", "toda", "todos", "todas", "nenhum", "nenhuma", "nenhuns",
    "nenhumas", "algum", "alguma", "alguns", "algumas", "outro",
    "outra", "outros", "outras", "mesmo", "mesma", "mesmos",
    "mesmas", "próprio", "própria", "próprios", "próprias", "tal",
    "tais", "qualquer", "quaisquer", "cada", "outrem", "algo",
    "tudo", "nada", "alguém", "ninguém", "outrem", "quemquer",
    "quaisquer", "bastante", "demais", "vário", "vária", "vários",
    "várias", "tanto", "tanta", "tantos", "tantas", "e", "ou", "mas",
    "porém", "todavia", "contudo", "entretanto", "então", "logo",
    "pois", "porque", "porquanto", "visto", "uma", "vez", "que",
    "embora", "conquanto", "ainda", "salvo", "exceto", "menos",
    "a", "o", "e", "é", "são", "foi", "foram", "ser", "estar",
    "ter", "haver", "fazer", "dar", "ir", "vir", "ver", "saber",
    "querer", "poder", "dever", "pensar", "achar", "parecer",
    "ficar", "passar", "deixar", "tomar", "colocar", "encontrar",
    "continuar", "manter", "levar", "trazer", "voltar", "entrar",
    "sair", "chegar", "partir", "morar", "viver", "morrer",
    "nascer", "crescer", "tornar", "virar", "começar", "acabar",
    "terminar", "seguir", "retornar", "recomeçar",
})


def _fold_token(token: str) -> str:
    """TCK-1141/DES-0743 (FND-0094): accent-folding via NFKD + strip de
    combining marks — "índice"→"indice", "ação"→"acao".
    Identidade para ASCII puro (zero impacto em tokens já sem acento)."""
    return "".join(
        ch for ch in unicodedata.normalize("NFKD", token)
        if not unicodedata.combining(ch)
    )


def tokenize(text: str) -> list[str]:
    """Tokeniza em palavras minúsculas, removendo stopwords.

    TCK-1141/DES-0743 (FND-0094): accent-folding (NFKD) ANTES do regex e do
    filtro de tamanho — o regex `[a-zA-Z0-9_\\-/]{2,}` é ASCII-only e
    fragmentava tokens acentuados do corpus PT-BR ("índice"→"ndice", "ação"
    evaporava em fragmentos de 1 char). O filtro `len>2` opera sobre o token
    JÁ dobrado, então "ação"→"acao" (4 chars) sobrevive. Índice
    (_read_and_tokenize) e query (main / extract_query_from_ticket) passam
    por esta função — os dois lados casam no mesmo folded-space.
    """
    folded = _fold_token(text)
    tokens = [t.lower() for t in _re_word.findall(folded) if len(t) > 2]
    return [t for t in tokens if t not in _stopwords]


# ── frontmatter parser (delegado para lib/frontmatter.py) ──────────
from lib.frontmatter import FRONTMATTER_RE, parse_frontmatter  # noqa: E402  TCK-0390: single compiled regex
from lib.ops_logging import setup_logging  # noqa: E402

logger = setup_logging(name="context-query")

# ── BM25 ────────────────────────────────────────────────────────────
class BM25Index:
    def __init__(self, docs: dict[str, list[str]]) -> None:
        """docs: path -> tokens"""
        self.paths = list(docs.keys())
        self.docs = [docs[p] for p in self.paths]
        self.N = len(self.docs)
        self.avgdl = sum(len(d) for d in self.docs) / self.N if self.N else 1
        self.df: dict[str, int] = {}
        self.tf: list[dict[str, int]] = []

        for tokens in self.docs:
            tf_doc: dict[str, int] = {}
            seen: set[str] = set()
            for t in tokens:
                tf_doc[t] = tf_doc.get(t, 0) + 1
                if t not in seen:
                    seen.add(t)
                    self.df[t] = self.df.get(t, 0) + 1
            self.tf.append(tf_doc)

    def idf(self, term: str) -> float:
        df = self.df.get(term, 0)
        return math.log((self.N - df + 0.5) / (df + 0.5) + 1.0)

    def score(self, query_tokens: list[str]) -> list[tuple[str, float]]:
        results: list[tuple[str, float]] = []
        for idx, tokens in enumerate(self.docs):
            dl = len(tokens)
            if dl == 0:
                results.append((self.paths[idx], 0.0))
                continue
            score = 0.0
            for t in query_tokens:
                tf = self.tf[idx].get(t, 0)
                if tf == 0:
                    continue
                idf = self.idf(t)
                denom = tf + K1 * (1 - B + B * (dl / self.avgdl))
                score += idf * (tf * (K1 + 1)) / denom
            results.append((self.paths[idx], score))
        return results


# ── indexação paralela ──────────────────────────────────────────────
def _read_and_tokenize(path: str) -> tuple[str, list[str]] | None:
    try:
        with open(path, "rb") as f:
            # Lê 1 byte além do corte só para DETECTAR truncamento (sem stat
            # extra no caminho feliz): len > MAX_FILE_BYTES ⇒ há conteúdo
            # invisível à busca.
            raw = f.read(MAX_FILE_BYTES + 1)
        if len(raw) > MAX_FILE_BYTES:
            # TCK-1141/DES-0743 (FND-0095): 44 .md do corpus excedem 12KB e
            # eram truncados em silêncio — fail-silent → ALTO (padrão
            # TCK-1107: uma linha, path + marker DEGRADED, stderr via logger).
            raw = raw[:MAX_FILE_BYTES]
            logger.warning(
                "DEGRADED: indexação BM25 truncou %s em %d bytes (%d KB) — "
                "conteúdo além do corte fica invisível à busca",
                path, MAX_FILE_BYTES, MAX_FILE_BYTES // 1024)
        text = raw.decode("utf-8", errors="ignore")
        return (path, tokenize(text))
    except Exception as e:
        # TCK-1107/DES-0654: arquivo some do índice BM25 em silêncio → ALTO.
        logger.warning(
            "DEGRADED: indexação BM25 pulou %s (%s: %s) — arquivo fora do "
            "índice; buscas não o encontram", path, type(e).__name__, e)
        return None


# TCK-0470: snapshots exportados (.archagents/13-execution/snapshots/**) são
# cópias completas da árvore .archagents — nunca devem entrar no índice BM25
# nem servir de candidato a ticket path (o cache chegou a 1.4GB por indexar
# dezenas de cópias inteiras do backlog).
EXCLUDE_PATH_MARKERS = ("13-execution/snapshots",)


def _is_excluded_path(path: str) -> bool:
    """True se `path` cai numa área que nunca deve ser indexada/escaneada
    (ex.: snapshots exportados em 13-execution/snapshots/)."""
    normalized = path.replace(os.sep, "/")
    return any(marker in normalized for marker in EXCLUDE_PATH_MARKERS)


def scan_files(root: str | None = None) -> list[str]:
    if root is None:
        root = str(_REPO_ROOT / ".archagents")
    found = glob.glob(os.path.join(root, "**", "*.md"), recursive=True)
    return [p for p in found if not _is_excluded_path(p)]


def build_index(paths: list[str]) -> BM25Index:
    docs: dict[str, list[str]] = {}
    with ThreadPoolExecutor(max_workers=NUM_WORKERS) as exe:
        for result in exe.map(_read_and_tokenize, paths):
            if result is not None:
                docs[result[0]] = result[1]
    return BM25Index(docs)


def index_mtime(paths: list[str]) -> float:
    mtimes = []
    for p in paths:
        try:
            mtimes.append(os.path.getmtime(p))
        except OSError as e:
            # TCK-1107/DES-0654: mtime perdido deixa o frescor do índice
            # otimista (cache pode ficar stale) → ALTO.
            logger.warning(
                "DEGRADED: mtime ilegível para %s (%s: %s) — arquivo ignorado "
                "no frescor do índice (cache pode ficar stale)",
                p, type(e).__name__, e)
    return max(mtimes) if mtimes else 0.0


# ── retrieval store SQLite (TCK-1188/DES-0760, PLN-0017 S2) ────────
# O corpus tokenizado vive na tabela retrieval_docs do .archagents/.index.db
# (único escritor: build-index.py). Query time lê as rows, recompõe o
# BM25Index em memória e pontua com o MESMO scorer de sempre — paridade de
# ranking por construção (mesmos tokens persistidos pelo mesmo tokenizer).
_RETRIEVAL_MTIME_KEY = "retrieval_mtime"


def _load_retrieval_store(root: Path) -> tuple[dict[str, list[str]], float] | None:
    """Lê (docs, retrieval_mtime) do SQLite. None = store ausente/ilegível."""
    from lib.db import get_db
    db = get_db(root)  # auto-build se .index.db ausente ou schema defasado
    try:
        row = db.execute(
            "SELECT value FROM meta WHERE key = ?", (_RETRIEVAL_MTIME_KEY,)
        ).fetchone()
        stored_mtime = float(row[0]) if row and row[0] is not None else 0.0
        docs: dict[str, list[str]] = {}
        for r in db.execute(
            "SELECT path, tokens FROM retrieval_docs ORDER BY path"
        ):
            docs[r["path"]] = r["tokens"].split() if r["tokens"] else []
        return docs, stored_mtime
    finally:
        db.close()


def _rebuild_retrieval_store(root: Path) -> bool:
    """Reconstrói o .index.db IN-PROCESS via build-index.build (temp + rename
    atômico, crash-safe). True se o build rodou; False se falhou (caller cai
    no fallback em memória)."""
    try:
        import importlib.util
        bi_path = Path(__file__).resolve().parent / "build-index.py"
        spec = importlib.util.spec_from_file_location(
            "codebase_ops_build_index_for_cq", bi_path)
        if spec is None or spec.loader is None:
            raise ImportError(f"cannot load {bi_path}")
        mod = importlib.util.module_from_spec(spec)
        spec.loader.exec_module(mod)
        mod.build(root)
        return True
    except Exception as e:
        # TCK-1107/DES-0654: rebuild falhou → fallback em memória → ALTO.
        logger.warning(
            "DEGRADED: rebuild do retrieval store SQLite falhou (%s: %s) — "
            "consulta segue com índice BM25 em memória (sem persistência)",
            type(e).__name__, e)
        return False


def load_or_build_index(
    paths: list[str],
    verbose: bool = False,
    root: Path | None = None,
) -> tuple[BM25Index, bool]:
    """Retorna (índice, usou_store_persistido).

    Lê retrieval_docs do SQLite quando fresco (retrieval_mtime >= max mtime
    do corpus E count == len(paths)); stale → rebuild via build-index;
    falha → BM25 em memória (fail-open, sem persistência)."""
    root = root or _REPO_ROOT
    current_mtime = index_mtime(paths)
    try:
        stored = _load_retrieval_store(root)
    except Exception as e:
        # TCK-1107/DES-0654: store ilegível → tenta rebuild → ALTO.
        logger.warning(
            "DEGRADED: retrieval store SQLite ilegível (%s: %s) — índice será "
            "reconstruído (latência maior nesta consulta)",
            type(e).__name__, e)
        stored = None
    if stored is not None:
        docs, stored_mtime = stored
        if stored_mtime >= current_mtime and len(docs) == len(paths):
            if verbose:
                logger.debug("[store] hit  (%d arquivos)", len(paths))
            return BM25Index(docs), True
    if verbose:
        logger.info("[index] rebuilding store SQLite (%d arquivos) …", len(paths))
    if _rebuild_retrieval_store(root):
        try:
            stored = _load_retrieval_store(root)
        except Exception as e:
            logger.warning(
                "DEGRADED: retrieval store recém-reconstruído ilegível "
                "(%s: %s) — fallback para índice em memória",
                type(e).__name__, e)
            stored = None
        if stored is not None:
            return BM25Index(stored[0]), False
    if verbose:
        logger.info("[index] fallback em memória: building %d arquivos …", len(paths))
    return build_index(paths), False


def _result_cache_key(ticket: str | None, query: str | None, top_k: int, mtime: float) -> str:
    if ticket:
        return f"ticket:{ticket.upper()}|k:{top_k}|m:{mtime:.0f}"
    q = (query or "").strip().lower()[:200]
    return f"query:{q}|k:{top_k}|m:{mtime:.0f}"


def load_result_cache(key: str) -> list[str] | None:
    if not RESULT_CACHE_FILE.exists():
        return None
    try:
        data = json.loads(RESULT_CACHE_FILE.read_text(encoding="utf-8"))
        entry = data.get(key)
        if isinstance(entry, list) and entry:
            return [str(p) for p in entry]
    except (OSError, json.JSONDecodeError, ValueError) as e:
        # TCK-1107/DES-0654: result-cache corrompido → miss silencioso → ALTO.
        logger.warning(
            "DEGRADED: result-cache %s ilegível (%s: %s) — tratado como miss; "
            "consulta será recomputada", RESULT_CACHE_FILE, type(e).__name__, e)
    return None


def save_result_cache(key: str, paths: list[str]) -> None:
    import os as _os
    if (_os.environ.get("PYTEST_CURRENT_TEST")
            and not _os.environ.get("CODEBASE_OPS_ALLOW_META_WRITE")):
        return
    try:
        CACHE_DIR.mkdir(parents=True, exist_ok=True)
        data: dict[str, list[str]] = {}
        if RESULT_CACHE_FILE.exists():
            try:
                data = json.loads(RESULT_CACHE_FILE.read_text(encoding="utf-8"))
            except (json.JSONDecodeError, ValueError) as e:
                # TCK-1107/DES-0654: cache prévio descartado → ALTO.
                logger.warning(
                    "DEGRADED: result-cache %s corrompido (%s: %s) — reiniciado "
                    "vazio; entradas anteriores descartadas",
                    RESULT_CACHE_FILE, type(e).__name__, e)
                data = {}
        data[key] = paths
        # cap size — keep newest 200 entries
        if len(data) > 200:
            for old in list(data.keys())[:-200]:
                data.pop(old, None)
        RESULT_CACHE_FILE.write_text(
            json.dumps(data, ensure_ascii=False), encoding="utf-8")
    except OSError as e:
        # TCK-1107/DES-0654: cache não persistido → ALTO.
        logger.warning(
            "DEGRADED: escrita do result-cache %s falhou (%s: %s) — resultado "
            "desta consulta não será cacheado",
            RESULT_CACHE_FILE, type(e).__name__, e)


# ── ticket query extraction ─────────────────────────────────────────
def _is_shell_command(text: str) -> bool:
    """Heurística para detectar comandos de shell em acceptance criteria."""
    shell_indicators = [
        " >/dev/null", " 2>&1", " | ", "; ", "echo ", "grep ", "rg ",
        "python3 -m pytest", "python3 -m coverage", "bash ", "sh ",
        "git ", "cat ", "head ", "tail ", "wc ", "ls ", "cd ",
        "|| ", "&& ", "test ", "[ ", "] "
    ]
    return any(ind in text for ind in shell_indicators)


def extract_query_from_ticket(ticket_id: str) -> list[str]:
    ticket_path = None
    backlog_dir = _REPO_ROOT / ".archagents" / "15-backlog" / "tickets"
    for root, _dirs, files in os.walk(backlog_dir):
        for f in files:
            if f.endswith(".md") and ticket_id.lower() in f.lower():
                ticket_path = os.path.join(root, f)
                break
        if ticket_path:
            break

    if not ticket_path or not os.path.exists(ticket_path):
        # TCK-0470: reusa scan_files() (já filtra snapshots exportados) em
        # vez de duplicar um glob.glob("...**/*.md") sem exclude.
        for p in scan_files():
            if ticket_id.lower() in os.path.basename(p).lower():
                ticket_path = p
                break

    if not ticket_path or not os.path.exists(ticket_path):
        logger.error("Ticket %s não encontrado.", ticket_id)
        sys.exit(1)

    with open(ticket_path, "r", encoding="utf-8") as f:
        text = f.read()

    meta = parse_frontmatter(text)
    parts: list[str] = []

    title = meta.get("title", "")
    if title and isinstance(title, str):
        parts.append(title)

    body = FRONTMATTER_RE.sub("", text).strip()
    body = re.sub(r"^#+\s.*$", "", body, flags=re.MULTILINE)
    body = re.sub(r"\n{2,}", "\n", body)
    lines = [l.strip() for l in body.splitlines() if l.strip()]
    if lines:
        first_para = " ".join(lines[:10])
        parts.append(first_para)

    acceptance = meta.get("acceptance", [])
    if isinstance(acceptance, list):
        for item in acceptance:
            if isinstance(item, str):
                if not _is_shell_command(item):
                    parts.append(item)
            elif isinstance(item, dict):
                check = item.get("check", "")
                if check and not _is_shell_command(str(check)):
                    parts.append(str(check))

    query_text = " ".join(parts)
    return tokenize(query_text)


# ── CLI ─────────────────────────────────────────────────────────────
def main() -> None:
    parser = argparse.ArgumentParser(description="Query seletiva de contexto BM25")
    parser.add_argument("--ticket", type=str, help="ID do ticket (ex: TCK-0119)")
    parser.add_argument("--query", type=str, help="Query em texto livre")
    parser.add_argument("--top-k", type=int, default=5, help="Número de resultados")
    parser.add_argument("--verbose", action="store_true", help="Modo verbose")
    parser.add_argument(
        "--no-graph", action="store_true",
        help="Disable 1-hop knowledge-graph expansion (TCK-0833)",
    )
    args = parser.parse_args()

    if not args.ticket and not args.query:
        parser.error("Informe --ticket ou --query")

    # TCK-0364 camada 1: concurrency guard — prevent process explosion
    if not _acquire_concurrency_slot():
        logger.warning(
            "max concurrent instances (%d) "
            "reached — skipping to prevent runaway. Set CBOPS_CQ_MAX_CONCURRENT "
            "to override.", CQ_MAX_CONCURRENT
        )
        sys.exit(0)

    t0 = time.perf_counter()

    paths = scan_files()
    if not paths:
        logger.error("Nenhum arquivo .md encontrado em .archagents/")
        sys.exit(1)

    current_mtime = index_mtime(paths)
    cache_key = _result_cache_key(args.ticket, args.query, args.top_k, current_mtime)
    cached_paths = load_result_cache(cache_key)
    if cached_paths:
        if args.verbose:
            logger.debug("[result-cache] hit (%d paths)", len(cached_paths))
        for path in cached_paths:
            print(path)
        return

    idx, from_store = load_or_build_index(paths, verbose=args.verbose)

    if args.ticket:
        query_tokens = extract_query_from_ticket(args.ticket)
        if args.verbose:
            logger.debug("[query] tokens: %s", query_tokens)
    else:
        query_tokens = tokenize(args.query)

    if not query_tokens:
        logger.error("Query vazia após tokenização.")
        sys.exit(1)

    scores = idx.score(query_tokens)
    scores.sort(key=lambda x: x[1], reverse=True)

    # imprime resultados antes de escrever cache (latência percebida)
    top = scores[: args.top_k]
    top_paths = [path for path, _score in top]

    # TCK-0833: hybrid retrieval — BM25 + 1-hop graph expansion (fail-open).
    if not args.no_graph and args.ticket:
        try:
            from lib.db import get_db
            from lib.knowledge_graph import expand_paths
            db = get_db()
            try:
                extra = expand_paths(db, top_paths, ticket_id=args.ticket,
                                     limit=max(3, args.top_k // 2))
            finally:
                db.close()
            for p in extra:
                if p not in top_paths:
                    top_paths.append(p)
            top_paths = top_paths[: args.top_k + max(3, args.top_k // 2)]
        except Exception as exc:
            # TCK-1107/DES-0654: expansão de grafo fail-open (TCK-0833) —
            # antes só logava em --verbose/debug; agora ALTO sempre.
            logger.warning(
                "DEGRADED: expansão de grafo 1-hop falhou (%s: %s) — resultados "
                "seguem BM25-puro (sem enriquecimento knowledge-graph)",
                type(exc).__name__, exc)

    save_result_cache(cache_key, top_paths)
    for path in top_paths:
        print(path)

    t1 = time.perf_counter()
    latency_ms = (t1 - t0) * 1000

    if not from_store and args.verbose:
        # store já foi persistido pelo rebuild (build-index) ou a consulta
        # rodou no fallback em memória (sem persistência — warning DEGRADED).
        logger.debug("[index] store SQLite atualizado (ou fallback em memória).")

    if args.verbose:
        logger.debug("[latency] %.1f ms  (%d arquivos)", latency_ms, len(paths))
        for path, score in top:
            logger.debug("  %.4f  %s", score, path)

    if latency_ms > 500:
        logger.warning("latência %.1fms excede 500ms", latency_ms)


if __name__ == "__main__":
    main()
