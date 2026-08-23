#!/usr/bin/env python3
"""frontmatter.py — Parser CANÔNICO de frontmatter YAML-simples do codebase-ops (TCK-0041).

Fonte única de semântica para os 5 consumidores (generate-backlog, update-meta,
archive-state, verify-run, capabilities). Antes havia 5 parsers divergentes:
`status: "done"` (quoted) contava como done no CSV mas NÃO nas métricas, na
elegibilidade do archive nem no mirror_on (FND-20260610-35).

Semântica (união dos parsers anteriores — superset):
  - comentários inline quote-aware (`effort: unknown  # XS|S` → "unknown")
  - aspas removidas em escalares ("done" → done)
  - tipos: null/none/~ → None; true/false → bool; int/float; resto str
  - listas inline `[a, b]`, block lists (`- item`), listas de dicts (commits),
    dicts aninhados 1 nível (test_result)
  - fold de string multilinha (continuação indentada vira " "-joined)

TCK-0390: file pooling — _read_text_cached() and parse_frontmatter_file() use
mtime-based caching so scripts that read the same file multiple times in a loop
(e.g. build-index check() vs _populate()) pay the I/O cost only once per process.
"""

from __future__ import annotations

import os
import re
from pathlib import Path
from typing import Any

FRONTMATTER_RE = re.compile(r"^---\s*\n(.*?)\n---\s*\n", re.DOTALL)


# ---------------------------------------------------------------------------
# TCK-0390: file pooling — mtime-based cache for read_text / parse_frontmatter_file.
# Avoids redundant I/O when the same file is read multiple times in one process.
# Cache is process-local (not cross-process) and safe for short-lived CLI runs.
# ---------------------------------------------------------------------------
_file_cache: dict[str, tuple[float, str]] = {}


def _read_text_cached(path: Path) -> str:
    """Read file text with mtime-based caching (TCK-0390).

    Returns cached content if the file's mtime hasn't changed since last read.
    Falls back to plain read_text on any OS error (fail-open).
    """
    key = str(path)
    try:
        mtime = os.path.getmtime(path)
    except OSError:
        return path.read_text(encoding="utf-8")
    cached = _file_cache.get(key)
    if cached is not None and cached[0] == mtime:
        return cached[1]
    text = path.read_text(encoding="utf-8")
    _file_cache[key] = (mtime, text)
    return text


def clear_file_cache() -> None:
    """Clear the process-local file cache (useful for tests)."""
    _file_cache.clear()


def read_json_cached(path: Path) -> Any:
    """Read and parse a JSON file with mtime-based caching (TCK-0390).

    Returns parsed JSON on success. Raises json.JSONDecodeError or OSError
    on failure (caller decides how to handle).
    """
    import json as _json
    text = _read_text_cached(path)
    return _json.loads(text)


def strip_inline_comment(value: str) -> str:
    """Remove comentário inline `# ...` respeitando aspas (quote-aware)."""
    in_single = in_double = False
    escaped = False
    result = []
    for ch in value:
        if escaped:
            result.append(ch)
            escaped = False
            continue
        if ch == "\\":
            result.append(ch)
            escaped = True
            continue
        if ch == '"' and not in_single:
            in_double = not in_double
            result.append(ch)
            continue
        if ch == "'" and not in_double:
            in_single = not in_single
            result.append(ch)
            continue
        if ch == "#" and not in_single and not in_double:
            break
        result.append(ch)
    return "".join(result).rstrip()


def _unescape_double_quoted(s: str) -> str:
    """Inverte o escape de `ticket._format_scalar` para escalares entre aspas
    duplas (TCK-0538).

    `_format_scalar` escapa `\\` -> `\\\\` e depois `"` -> `\\"` antes de
    envolver o valor em aspas duplas. Esta função é a inversa exata: varre a
    string da esquerda para a direita e, a cada `\\`, emite o caractere
    seguinte literalmente (deixa de ser um par de escape).

    Deliberadamente NÃO usa `.replace()` encadeado (ex.: `s.replace("\\\\",
    "\\").replace('\\"', '"')`, em qualquer ordem): essa técnica resolve os
    dois padrões de escape em passes globais separados e independentes, o
    que é uma classe de bug conhecida sempre que um mesmo caractere (aqui,
    `\\`) participa de mais de uma regra de escape — a remoção de um par por
    um `.replace` pode reencadear caracteres vizinhos de forma que o próximo
    `.replace` os interprete incorretamente, e o resultado passa a depender
    da ordem escolhida. Um scanner sequencial de um único passe, posição a
    posição, decide cada caractere olhando só para o que ainda não foi
    consumido — é a inversa formal e inequívoca de `_format_scalar`,
    independente de ordem.
    """
    out: list[str] = []
    i = 0
    n = len(s)
    while i < n:
        ch = s[i]
        if ch == "\\" and i + 1 < n:
            out.append(s[i + 1])
            i += 2
        else:
            out.append(ch)
            i += 1
    return "".join(out)


def parse_scalar(value: str) -> Any:
    """Escalar YAML-simples: comment-strip + aspas + null/bool/num + lista inline."""
    value = strip_inline_comment(value).strip()
    if value == "" or value.lower() in ("null", "none", "~"):
        return None
    if value.startswith("[") and value.endswith("]"):
        inner = value[1:-1].strip()
        if not inner:
            return []
        return [parse_scalar(item.strip()) for item in inner.split(",")]
    if value.startswith('"') and value.endswith('"'):
        # TCK-0538: leitura simétrica à escrita — _format_scalar escapa `\`
        # e `"` ao serializar; sem desfazer aqui, cada ciclo read->write
        # re-escapa e os backslashes dobram a cada transição de ticket.
        return _unescape_double_quoted(value[1:-1])
    if value.startswith("'") and value.endswith("'"):
        # YAML aspas simples: só `''` -> `'` é escape; `\` é literal.
        return value[1:-1].replace("''", "'")
    if value.lower() == "true":
        return True
    if value.lower() == "false":
        return False
    try:
        return float(value) if "." in value else int(value)
    except ValueError:
        pass
    return value


def parse_list(value: Any) -> list[str]:
    """Normaliza um campo de lista para list[str]: aceita list (de parse_frontmatter)
    ou string inline '[A, B]'. None/''/'[]' → []."""
    if value is None:
        return []
    if isinstance(value, list):
        return [str(v) for v in value if v is not None and str(v).strip()]
    s = str(value).strip()
    if not s or s in ("[]", "''", '""'):
        return []
    s = s.strip("[]")
    return [item.strip().strip("'\"") for item in s.split(",") if item.strip()]


def parse_frontmatter(text: str) -> dict[str, Any]:
    """Frontmatter entre `---`: top-level key/value tipados, block lists,
    listas de dicts, dicts aninhados (1 nível), fold de multilinha."""
    match = FRONTMATTER_RE.match(text)
    if not match:
        return {}
    yaml_block = match.group(1)
    data: dict[str, Any] = {}
    current_key: str | None = None
    current_type: str | None = None  # 'list' | 'dict' | 'fold' | None
    # TCK-1931: indent onde vivem as chaves do item de lista corrente
    # (indent do `- ` + 2). Linha mais funda que isso é CONTINUAÇÃO de valor,
    # mesmo que por azar case `chave:` — é como o YAML real desambigua.
    list_key_indent = 0
    lines = yaml_block.splitlines()
    i = 0
    while i < len(lines):
        raw = lines[i]
        line = raw.rstrip()
        i += 1
        if not line or line.strip().startswith("#"):
            continue
        stripped = line.lstrip()
        indent = len(line) - len(stripped)

        # TCK-1931: o ramo de lista vem ANTES do de indent 0 e aceita qualquer
        # indentação. Antes, item com indent zero (o YAML canônico que
        # `yaml.safe_dump` emite) caía no ramo top-level, não casava
        # `(\w+):` e era DESCARTADO — acceptance válido virava `[]`, e o
        # criteria-check lê vazio como "sem acceptance" (waiver, fail-open).
        # Continuação de linha (fold de item longo) virava `current_type=None`,
        # TRUNCANDO o comando e perdendo o `expect`. Uma chave top-level
        # legítima (indent 0, `chave:`, sem `- `) continua encerrando a lista.
        if current_type == "list" and current_key is not None:
            eh_chave_toplevel = (indent == 0 and not stripped.startswith("- ")
                                 and re.match(r"(\w+):\s*(.*)", stripped))
            if not eh_chave_toplevel:
                lst = data.get(current_key)
                if not isinstance(lst, list):
                    data[current_key] = lst = []
                if stripped.startswith("- "):
                    list_key_indent = indent + 2
                    item_text = stripped[2:]
                    item_match = re.match(r"(\w+):\s*(.*)", item_text)
                    if item_match:
                        k, v = item_match.group(1), item_match.group(2).strip()
                        if not lst or not isinstance(lst[-1], dict) or k in lst[-1]:
                            lst.append({})
                        lst[-1][k] = parse_scalar(v)
                    else:
                        lst.append(parse_scalar(item_text))
                    continue
                m = re.match(r"(\w+):\s*(.*)", stripped)
                if (m and lst and isinstance(lst[-1], dict)
                        and indent <= list_key_indent):
                    k, v = m.group(1), m.group(2).strip()
                    lst[-1][k] = parse_scalar(v)
                    continue
                # continuação folded do último valor do último item
                if lst:
                    ultimo = lst[-1]
                    if isinstance(ultimo, dict) and ultimo:
                        uk = next(reversed(ultimo))
                        ultimo[uk] = (str(ultimo[uk]) + " " + stripped).strip()
                    else:
                        lst[-1] = (str(ultimo) + " " + stripped).strip()
                continue

        if indent == 0:
            m = re.match(r"(\w+):\s*(.*)", stripped)
            if not m:
                continue
            key, value = m.group(1), m.group(2).strip()
            current_key = key
            if not value or value.startswith("#"):
                # tipo decidido pela próxima linha útil
                peek = i
                while peek < len(lines):
                    pl = lines[peek].strip()
                    if pl and not pl.startswith("#"):
                        break
                    peek += 1
                if peek < len(lines):
                    nxt = lines[peek].lstrip()
                    if nxt.startswith("- "):
                        data[key] = []
                        current_type = "list"
                    elif re.match(r"(\w+):\s", nxt) and (len(lines[peek]) - len(nxt)) > 0:
                        data[key] = {}
                        current_type = "dict"
                    else:
                        data[key] = ""
                        current_type = None
                else:
                    data[key] = ""
                    current_type = None
                continue
            data[key] = parse_scalar(value)
            current_type = "fold" if isinstance(data[key], str) else None
            continue

        if current_key is None:
            continue

        # (o ramo de lista vive acima, antes do indent-0 — TCK-1931)
        if current_type == "dict":
            m = re.match(r"(\w+):\s*(.*)", stripped)
            if m:
                k, v = m.group(1), m.group(2).strip()
                if not isinstance(data.get(current_key), dict):
                    data[current_key] = {}
                data[current_key][k] = parse_scalar(v)
            else:
                current_type = None
        elif current_type == "fold" and isinstance(data.get(current_key), str):
            # continuação de string multilinha (folded)
            data[current_key] = (data[current_key] + " " + stripped).strip()
    return data


def parse_frontmatter_file(path: Path) -> dict[str, Any]:
    """Lê arquivo e extrai frontmatter YAML. Retorna dict vazio se não houver.

    TCK-0390: uses _read_text_cached for file pooling — repeated calls with the
    same path (and unchanged mtime) return cached content without disk I/O.
    """
    content = _read_text_cached(path)
    return parse_frontmatter(content)
