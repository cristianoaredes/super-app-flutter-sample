#!/usr/bin/env python3
"""Pure dependency/readiness kernel (TCK-1347 / DES-0808).

The module has no CLI and performs no writes.  Ticket resolution is exact
across active + archive, and every issue is represented with a stable code so
writers and read-only projections can share one decision.
"""

from __future__ import annotations

from collections import Counter, deque
from dataclasses import dataclass
from pathlib import Path
import re
from typing import Any

from lib.frontmatter import parse_frontmatter, parse_list
from lib.paths import paths


TICKET_ID_RE = re.compile(r"^TCK-[0-9]{4,}$")
SPEC_ID_RE = re.compile(r"^SPC-[0-9]{4,}$")
PLAN_ID_RE = re.compile(r"^PLN-[0-9]{4,}$")
MODULE_NAME_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._-]{0,63}$")
SATISFIED_TICKET_STATUSES = frozenset({"done", "closed"})
PROGRESS_STATUSES = frozenset(
    {"triaged", "designed", "executing", "verifying", "done", "closed"}
)
_SAFE_TOKEN_RE = re.compile(r"^[A-Za-z0-9][A-Za-z0-9._:-]{0,63}$")
MAX_PUBLIC_ISSUES = 32
MAX_PATH_NODES = 12
MAX_FAILURE_BYTES = 8 * 1024
TRUNCATION_CODE = "diagnostic-truncated"
STRUCTURAL_CODES = frozenset({
    "invalid-id", "duplicate", "missing", "ambiguous", "id-mismatch", "self-edge", "cycle",
})


@dataclass(frozen=True)
class DependencyIssue:
    code: str
    node: str
    dependency: str
    status: str | None
    path: tuple[str, ...]


@dataclass(frozen=True)
class DependencyReadiness:
    eligible: bool
    dependencies: tuple[str, ...]
    issues: tuple[DependencyIssue, ...]


@dataclass(frozen=True)
class _TicketNode:
    ticket_id: str
    status: str
    dependencies: tuple[str, ...]


@dataclass
class _PlanEvaluationFrame:
    node: str
    dependencies: tuple[str, ...]
    upstream_dependencies: tuple[str, ...]
    issues: _IssueAccumulator
    next_index: int = 0
    waiting_for: str | None = None


def is_progress_status(status: str) -> bool:
    """Whether ``status`` represents forward construction/progress."""
    return str(status or "").strip() in PROGRESS_STATUSES


def _causal_key(issue: DependencyIssue) -> tuple[object, ...]:
    """Identity of one underlying defect, independent of discovery path."""
    return (
        issue.code,
        issue.node,
        issue.dependency,
        issue.status,
    )


def _issue_key(issue: DependencyIssue) -> tuple[Any, ...]:
    return (
        issue.code,
        issue.node,
        issue.dependency,
        issue.status or "",
        issue.path,
    )


def _bounded_path(path: tuple[str, ...]) -> tuple[str, ...]:
    """Keep both ends of a diagnostic path while making truncation explicit."""
    if len(path) <= MAX_PATH_NODES:
        return path
    return (
        *path[:6],
        TRUNCATION_CODE,
        *path[-5:],
    )


def _append_bounded_path(path: tuple[str, ...], node: str) -> tuple[str, ...]:
    """Append one hop while keeping traversal memory constant."""
    if len(path) < MAX_PATH_NODES:
        return path + (node,)
    return (
        *path[:6],
        TRUNCATION_CODE,
        *path[-4:],
        node,
    )


def _strongly_connected_cycle_issues(
    adjacency: dict[str, tuple[str, ...]],
    *,
    statuses: dict[str, str] | None = None,
) -> list[tuple[tuple[str, ...], DependencyIssue]]:
    """Find cyclic SCCs in O(V+E), returning one stable issue per component.

    Kosaraju's two iterative passes avoid recursion limits. For each cyclic SCC,
    the diagnostic is the shortest deterministic cycle through its smallest
    node; the component tuple lets module consumers mark every member blocked
    without enumerating paths.
    """
    nodes = sorted(
        set(adjacency).union(
            dependency
            for dependencies in adjacency.values()
            for dependency in dependencies
        )
    )
    visited: set[str] = set()
    finish_order: list[str] = []
    for start in nodes:
        if start in visited:
            continue
        visited.add(start)
        stack: list[tuple[str, int]] = [(start, 0)]
        while stack:
            current, index = stack[-1]
            neighbors = adjacency.get(current, ())
            if index < len(neighbors):
                dependency = neighbors[index]
                stack[-1] = (current, index + 1)
                if dependency not in visited:
                    visited.add(dependency)
                    stack.append((dependency, 0))
                continue
            stack.pop()
            finish_order.append(current)

    reverse: dict[str, list[str]] = {node: [] for node in nodes}
    for node, dependencies in adjacency.items():
        for dependency in dependencies:
            reverse.setdefault(dependency, []).append(node)
    for predecessors in reverse.values():
        predecessors.sort()

    assigned: set[str] = set()
    components: list[tuple[str, ...]] = []
    for start in reversed(finish_order):
        if start in assigned:
            continue
        assigned.add(start)
        component: list[str] = []
        stack = [start]
        while stack:
            current = stack.pop()
            component.append(current)
            for predecessor in reversed(reverse.get(current, [])):
                if predecessor not in assigned:
                    assigned.add(predecessor)
                    stack.append(predecessor)
        components.append(tuple(sorted(component)))

    results: list[tuple[tuple[str, ...], DependencyIssue]] = []
    for component in sorted(components):
        if len(component) <= 1:
            continue
        members = set(component)
        start = component[0]

        # Distances to ``start`` are computed on the reversed SCC. They allow
        # reconstructing a shortest path back without enumerating alternatives.
        distance: dict[str, int] = {start: 0}
        queue = deque([start])
        while queue:
            current = queue.popleft()
            for predecessor in reverse.get(current, []):
                if predecessor in members and predecessor not in distance:
                    distance[predecessor] = distance[current] + 1
                    queue.append(predecessor)

        first = min(
            (
                dependency
                for dependency in adjacency.get(start, ())
                if dependency in members and dependency in distance
            ),
            key=lambda dependency: (distance[dependency], dependency),
        )
        cycle_path = [start, first]
        current = first
        while current != start:
            next_distance = distance[current] - 1
            current = min(
                dependency
                for dependency in adjacency.get(current, ())
                if dependency in members
                and distance.get(dependency) == next_distance
            )
            cycle_path.append(current)

        issue = DependencyIssue(
            code="cycle",
            node=cycle_path[-2],
            dependency=start,
            status=(statuses or {}).get(start),
            path=_bounded_path(tuple(cycle_path)),
        )
        results.append((component, issue))
    return results


def _public_issue(issue: DependencyIssue) -> DependencyIssue:
    return DependencyIssue(
        code=issue.code,
        node=issue.node,
        dependency=issue.dependency,
        status=issue.status,
        path=_bounded_path(tuple(str(part) for part in issue.path)),
    )


def _diagnostic_sentinel(owner: str) -> DependencyIssue:
    safe_owner = owner if _SAFE_TOKEN_RE.fullmatch(owner) else "readiness"
    return DependencyIssue(
        code=TRUNCATION_CODE,
        node=safe_owner,
        dependency="issues",
        status="truncated",
        path=(safe_owner, TRUNCATION_CODE),
    )


class _IssueAccumulator:
    """Bounded causal set retaining deterministic representative paths.

    At most ``MAX_PUBLIC_ISSUES`` real causes are retained while traversing.
    Once another causal identity is observed, the final public projection uses
    31 real causes plus one blocking sentinel. Eligibility is based on
    ``saw_issue``, never on how much of the projection was retained.
    """

    def __init__(self, owner: str) -> None:
        self.owner = owner
        self.saw_issue = False
        self.overflow = False
        self._representatives: dict[
            tuple[object, ...],
            tuple[tuple[int, tuple[str, ...]], DependencyIssue],
        ] = {}
        # TCK-0127 (deep-codebase-ops): defeitos ESTRUTURAIS nunca disputam
        # vaga com pendências. Antes, um `self-edge` ("s") perdia a vaga para
        # `pending` ("p") na ordenação lexicográfica e sumia da projeção — e por
        # isso o dor-check tratava a sentinela como estrutural (fail-closed).
        # Com os estruturais retidos à parte, a sentinela passa a significar
        # só "pendências truncadas", e o consumidor pode dizer isso.
        self._structural: dict[
            tuple[object, ...],
            tuple[tuple[int, tuple[str, ...]], DependencyIssue],
        ] = {}

    def add(self, issue: DependencyIssue) -> None:
        self.saw_issue = True
        if issue.code == TRUNCATION_CODE:
            # A downstream consumer is re-projecting an already bounded
            # readiness. Preserve the overflow signal, but regenerate one
            # owner-specific sentinel in the reserved final slot.
            self.overflow = True
            return
        key = _causal_key(issue)
        if issue.code in STRUCTURAL_CODES:
            path = tuple(str(part) for part in issue.path)
            rank = (len(path), path)
            current = self._structural.get(key)
            if current is None or rank < current[0]:
                self._structural[key] = (rank, issue)
            return
        path = tuple(str(part) for part in issue.path)
        rank = (len(path), path)
        current = self._representatives.get(key)
        if current is not None:
            if rank < current[0]:
                self._representatives[key] = (rank, issue)
            return
        if len(self._representatives) < MAX_PUBLIC_ISSUES:
            self._representatives[key] = (rank, issue)
            return

        self.overflow = True
        largest = max(
            self._representatives,
            key=lambda causal: (
                str(causal[0]),
                str(causal[1]),
                str(causal[2]),
                "" if causal[3] is None else str(causal[3]),
            ),
        )
        incoming_sort = (
            str(key[0]),
            str(key[1]),
            str(key[2]),
            "" if key[3] is None else str(key[3]),
        )
        largest_sort = (
            str(largest[0]),
            str(largest[1]),
            str(largest[2]),
            "" if largest[3] is None else str(largest[3]),
        )
        if incoming_sort < largest_sort:
            del self._representatives[largest]
            self._representatives[key] = (rank, issue)

    def extend(self, issues: Any) -> None:
        for issue in issues:
            self.add(issue)

    def project(self) -> tuple[DependencyIssue, ...]:
        structural = sorted(
            (_public_issue(entry[1]) for entry in self._structural.values()),
            key=_issue_key,
        )
        pending = sorted(
            (_public_issue(entry[1]) for entry in self._representatives.values()),
            key=_issue_key,
        )
        # estruturais primeiro (ilimitados até o teto público); pendências
        # preenchem o resto; a sentinela ocupa a última vaga quando transbordou
        overflow = self.overflow or (len(structural) + len(pending) > MAX_PUBLIC_ISSUES)
        cap = MAX_PUBLIC_ISSUES - (1 if overflow else 0)
        projected = (structural + pending)[:cap]
        if overflow:
            projected.append(_diagnostic_sentinel(self.owner))
        return tuple(projected)


def bounded_dependency_issues(
    issues: Any,
    *,
    owner: str,
) -> tuple[DependencyIssue, ...]:
    """Return the public causal projection with DES-0808 cardinality caps."""
    accumulator = _IssueAccumulator(owner)
    accumulator.extend(issues)
    return accumulator.project()


def _safe_token(value: object) -> str:
    """Bound one diagnostic field to the delimiter-safe public grammar."""
    token = str(value)
    return token if _SAFE_TOKEN_RE.fullmatch(token) else "<invalid>"


def format_dependency_issue(issue: DependencyIssue) -> str:
    """Stable, content-free failure shared by writer and handoff."""
    fields = [
        f"dependency-gate:{_safe_token(issue.code)}",
        f"node={_safe_token(issue.node)}",
        f"dependency={_safe_token(issue.dependency)}",
    ]
    if issue.status is not None:
        fields.append(f"status={_safe_token(issue.status)}")
    if issue.path:
        fields.append(f"path={'->'.join(_safe_token(part) for part in issue.path)}")
    return " ".join(fields)


def dependency_failures(readiness: DependencyReadiness) -> list[str]:
    """Format failures without ever constructing more than 8 KiB.

    The byte budget includes the ``"; "`` delimiters used by the writer and
    handoff consumers. Overflow replaces the tail with an explicit blocking
    marker instead of silently dropping diagnostics.
    """
    failures: list[str] = []
    used = 0
    truncated = False
    sentinel = format_dependency_issue(_diagnostic_sentinel("readiness"))
    sentinel_bytes = len(sentinel.encode("utf-8"))
    for issue in readiness.issues:
        failure = format_dependency_issue(issue)
        addition = len(failure.encode("utf-8")) + (2 if failures else 0)
        if used + addition > MAX_FAILURE_BYTES:
            truncated = True
            break
        failures.append(failure)
        used += addition

    if truncated:
        sentinel_addition = sentinel_bytes + (2 if failures else 0)
        while failures and used + sentinel_addition > MAX_FAILURE_BYTES:
            removed = failures.pop()
            used -= len(removed.encode("utf-8"))
            if failures:
                used -= 2
            sentinel_addition = sentinel_bytes + (2 if failures else 0)
        failures.append(sentinel)
    return failures


def dependency_issue_to_dict(issue: DependencyIssue) -> dict[str, object]:
    """Serialize an issue with bounded strings and JSON-native arrays."""
    return {
        "code": _safe_token(issue.code),
        "node": _safe_token(issue.node),
        "dependency": _safe_token(issue.dependency),
        "status": _safe_token(issue.status) if issue.status is not None else None,
        "path": [_safe_token(part) for part in _bounded_path(issue.path)],
    }


def safe_plan_module_name(module: dict[str, Any], index: int) -> str:
    """Return the exact valid module name or a deterministic safe placeholder."""
    raw_name = str(module.get("name") or "").strip()
    return (
        raw_name
        if MODULE_NAME_RE.fullmatch(raw_name)
        else f"invalid-module-{index + 1:04d}"
    )


def _resolve_canonical_artifact_path(
    artifact_id: str,
    *,
    root: str | Path | None,
    id_pattern: re.Pattern[str],
    relative_directories: tuple[Path, ...],
) -> tuple[Path | None, str | None]:
    """Resolve one exact, physical artifact from direct governed children.

    This boundary intentionally does not call ``resolve_artifact`` because that
    compatibility resolver accepts an existing arbitrary path. Readiness
    inputs are IDs, never paths, and identity is confirmed from frontmatter.
    """
    requested = str(artifact_id or "").strip()
    if not id_pattern.fullmatch(requested):
        return None, "invalid-id"
    # A same-named file in CWD is never a valid artifact, but its presence is
    # an ambiguity signal rather than something to silently ignore. This keeps
    # the historical shadow defense without the permissive path pass-through.
    if Path(requested).exists():
        return None, "ambiguous"

    resolved_root = paths(root).root.resolve()
    candidates: list[Path] = []
    for relative_directory in relative_directories:
        directory = resolved_root / relative_directory
        if not directory.is_dir():
            continue
        candidates.extend(
            candidate
            for candidate in sorted(directory.glob(f"{requested}-*.md"))
            if not candidate.stem.endswith("-questions")
        )
    if not candidates:
        return None, "missing"
    if len(candidates) != 1:
        return None, "ambiguous"

    candidate = candidates[0]
    try:
        resolved_candidate = candidate.resolve(strict=True)
    except OSError:
        return None, "ambiguous"
    if (
        candidate.is_symlink()
        or not resolved_candidate.is_file()
        or resolved_candidate != candidate
    ):
        return None, "ambiguous"

    try:
        frontmatter = parse_frontmatter(
            resolved_candidate.read_text(encoding="utf-8")
        )
    except OSError:
        return None, "ambiguous"
    if str(frontmatter.get("id") or "").strip() != requested:
        return None, "id-mismatch"
    return resolved_candidate, None


def resolve_canonical_ticket_path(
    ticket_id: str,
    *,
    root: str | Path | None,
) -> tuple[Path | None, str | None]:
    """Resolve one exact TCK only from physical active/archive stores."""
    return _resolve_canonical_artifact_path(
        ticket_id,
        root=root,
        id_pattern=TICKET_ID_RE,
        relative_directories=(
            Path(".archagents/15-backlog/tickets"),
            Path(".archagents/archive/15-backlog/tickets"),
        ),
    )


def resolve_canonical_spec_path(
    spec_id: str,
    *,
    root: str | Path | None,
) -> tuple[Path | None, str | None]:
    """Resolve one exact SPC from the physical canonical active store."""
    return _resolve_canonical_artifact_path(
        spec_id,
        root=root,
        id_pattern=SPEC_ID_RE,
        relative_directories=(Path(".archagents/12-inception/specs"),),
    )


def resolve_canonical_plan_path(
    plan_id: str,
    *,
    root: str | Path | None,
) -> tuple[Path | None, str | None]:
    """Resolve one exact PLN from the physical canonical active store."""
    return _resolve_canonical_artifact_path(
        plan_id,
        root=root,
        id_pattern=PLAN_ID_RE,
        relative_directories=(Path(".archagents/12-inception/plans"),),
    )


def _read_ticket_node(
    ticket_id: str,
    *,
    root: str | Path | None,
) -> tuple[_TicketNode | None, str | None]:
    """Return ``(node, error_code)`` using the canonical active+archive resolver."""
    path, error = resolve_canonical_ticket_path(ticket_id, root=root)
    if path is None:
        return None, error or "ambiguous"

    try:
        frontmatter = parse_frontmatter(path.read_text(encoding="utf-8"))
    except OSError:
        return None, "ambiguous"
    dependencies = tuple(
        str(value).strip()
        for value in parse_list(frontmatter.get("blocked_by"))
        if str(value).strip()
    )
    return (
        _TicketNode(
            ticket_id=ticket_id,
            status=str(frontmatter.get("status") or "").strip(),
            dependencies=dependencies,
        ),
        None,
    )


def evaluate_ticket_dependencies(
    ticket_id: str,
    *,
    root: str | Path | None,
) -> DependencyReadiness:
    """Evaluate ``blocked_by`` recursively and fail closed on graph defects.

    ``blocks`` is intentionally ignored: ``blocked_by`` is the sole authority.
    The returned direct ``dependencies`` preserve duplicate values (sorted) so
    diagnostics are reproducible; duplicate edges also emit one explicit issue.
    """
    target = str(ticket_id or "").strip()
    issues = _IssueAccumulator(target or "ticket")
    cache: dict[str, tuple[_TicketNode | None, str | None]] = {}

    def read(node_id: str) -> tuple[_TicketNode | None, str | None]:
        if node_id not in cache:
            cache[node_id] = _read_ticket_node(node_id, root=root)
        return cache[node_id]

    if not TICKET_ID_RE.fullmatch(target):
        issue = DependencyIssue(
            code="invalid-id",
            node=target or "<empty>",
            dependency=target or "<empty>",
            status=None,
            path=(target or "<empty>",),
        )
        return DependencyReadiness(False, (), (issue,))

    target_node, target_error = read(target)
    if target_node is None:
        issue = DependencyIssue(
            code=target_error or "missing",
            node=target,
            dependency=target,
            status=None,
            path=(target,),
        )
        return DependencyReadiness(False, (), (issue,))

    nodes: dict[str, _TicketNode] = {target: target_node}
    routes: dict[str, tuple[str, ...]] = {target: (target,)}
    adjacency: dict[str, tuple[str, ...]] = {}
    pending_nodes = deque([target])
    while pending_nodes:
        node_id = pending_nodes.popleft()
        node = nodes[node_id]
        path = routes[node_id]
        counts = Counter(node.dependencies)
        for dependency, count in sorted(counts.items()):
            if count > 1:
                issues.add(
                    DependencyIssue(
                        code="duplicate",
                        node=node.ticket_id,
                        dependency=dependency,
                        status=None,
                        path=path + (dependency,),
                    )
                )

        neighbors: list[str] = []
        for dependency in sorted(counts):
            edge_path = _append_bounded_path(path, dependency)
            if not TICKET_ID_RE.fullmatch(dependency):
                issues.add(
                    DependencyIssue(
                        code="invalid-id",
                        node=node.ticket_id,
                        dependency=dependency,
                        status=None,
                        path=edge_path,
                    )
                )
                continue
            if dependency == node.ticket_id:
                issues.add(
                    DependencyIssue(
                        code="self-edge",
                        node=node.ticket_id,
                        dependency=dependency,
                        status=node.status,
                        path=edge_path,
                    )
                )
                continue

            dependency_node, resolution_error = read(dependency)
            if dependency_node is None:
                issues.add(
                    DependencyIssue(
                        code=resolution_error or "missing",
                        node=node.ticket_id,
                        dependency=dependency,
                        status=None,
                        path=edge_path,
                    )
                )
                continue

            if dependency_node.status not in SATISFIED_TICKET_STATUSES:
                issues.add(
                    DependencyIssue(
                        code="pending",
                        node=node.ticket_id,
                        dependency=dependency,
                        status=dependency_node.status or "<empty>",
                        path=edge_path,
                    )
                )
            neighbors.append(dependency)
            if dependency not in routes:
                # FIFO BFS + sorted edges makes the first route the shortest,
                # then lexicographically first. Each node is processed once.
                routes[dependency] = edge_path
                nodes[dependency] = dependency_node
                pending_nodes.append(dependency)
        adjacency[node_id] = tuple(neighbors)

    statuses = {
        node_id: node.status or "<empty>"
        for node_id, node in nodes.items()
    }
    for _component, cycle_issue in _strongly_connected_cycle_issues(
        adjacency,
        statuses=statuses,
    ):
        issues.add(cycle_issue)

    ordered = issues.project()
    return DependencyReadiness(
        eligible=not issues.saw_issue,
        dependencies=tuple(sorted(target_node.dependencies)),
        issues=ordered,
    )


def evaluate_plan_modules(
    modules: list[dict[str, Any]],
    root: str | Path | None,
) -> dict[str, DependencyReadiness]:
    """Evaluate a PLN module graph without persisting derived readiness.

    Module names are graph nodes and ``blocked_by`` contains module names.
    Duplicate dependency entries remain in ``dependencies`` and are also
    structural issues. A blocker is operationally complete only when its exact
    canonical SPC has at least one linked TCK and every exact active/archive
    TCK is ``done`` or ``closed``.
    """
    normalized: list[tuple[str, str, tuple[str, ...], str]] = []
    for index, module in enumerate(modules):
        raw_name = str(module.get("name") or "").strip()
        safe_name = safe_plan_module_name(module, index)
        dependencies = tuple(
            str(value).strip()
            for value in parse_list(module.get("blocked_by"))
            if str(value).strip()
        )
        spec_id = (
            str(module.get("spec")).strip()
            if isinstance(module.get("spec"), str)
            else ""
        )
        normalized.append((safe_name, raw_name, dependencies, spec_id))

    name_counts = Counter(
        raw_name for _, raw_name, _, _ in normalized if raw_name
    )
    records_by_name: dict[str, list[tuple[str, str, tuple[str, ...], str]]] = {}
    for record in normalized:
        safe_name, raw_name, _, _ = record
        key = raw_name if MODULE_NAME_RE.fullmatch(raw_name) else safe_name
        records_by_name.setdefault(key, []).append(record)

    module_adjacency: dict[str, tuple[str, ...]] = {}
    for node, records in sorted(records_by_name.items()):
        if len(records) != 1:
            continue
        _, raw_name, dependencies, _ = records[0]
        module_adjacency[node] = tuple(
            dependency
            for dependency in sorted(set(dependencies))
            if (
                MODULE_NAME_RE.fullmatch(dependency)
                and dependency != raw_name
                and len(records_by_name.get(dependency, [])) == 1
            )
        )

    cycle_issues_by_node: dict[str, list[DependencyIssue]] = {}
    for component, issue in _strongly_connected_cycle_issues(
        module_adjacency
    ):
        for node in component:
            cycle_issues_by_node.setdefault(node, []).append(issue)

    def local_structural_issues(
        node: str,
        raw_name: str,
        dependencies: tuple[str, ...],
        spec_id: str,
    ) -> tuple[DependencyIssue, ...]:
        issues = _IssueAccumulator(node)
        if not MODULE_NAME_RE.fullmatch(raw_name):
            issues.add(
                DependencyIssue(
                    code="invalid-id",
                    node=node,
                    dependency=raw_name or "<empty>",
                    status=None,
                    path=(node,),
                )
            )
        if raw_name and name_counts[raw_name] > 1:
            issues.add(
                DependencyIssue(
                    code="duplicate",
                    node=node,
                    dependency=raw_name,
                    status=None,
                    path=(node, raw_name),
                )
            )

        dependency_counts = Counter(dependencies)
        for dependency, count in sorted(dependency_counts.items()):
            edge_path = (node, dependency)
            if count > 1:
                issues.add(
                    DependencyIssue(
                        code="duplicate",
                        node=node,
                        dependency=dependency,
                        status=None,
                        path=edge_path,
                    )
                )
            if not MODULE_NAME_RE.fullmatch(dependency):
                issues.add(
                    DependencyIssue(
                        code="invalid-id",
                        node=node,
                        dependency=dependency,
                        status=None,
                        path=edge_path,
                    )
                )
                continue
            if dependency == raw_name:
                issues.add(
                    DependencyIssue(
                        code="self-edge",
                        node=node,
                        dependency=dependency,
                        status=None,
                        path=edge_path,
                    )
                )
                continue
            matches = records_by_name.get(dependency, [])
            if not matches:
                issues.add(
                    DependencyIssue(
                        code="missing",
                        node=node,
                        dependency=dependency,
                        status=None,
                        path=edge_path,
                    )
                )
            elif len(matches) > 1:
                issues.add(
                    DependencyIssue(
                        code="ambiguous",
                        node=node,
                        dependency=dependency,
                        status=None,
                        path=edge_path,
                    )
                )
        if not spec_id:
            issues.add(
                DependencyIssue(
                    code="missing",
                    node=node,
                    dependency="<empty>",
                    status=None,
                    path=(node, "<empty>"),
                )
            )
        elif not SPEC_ID_RE.fullmatch(spec_id):
            issues.add(
                DependencyIssue(
                    code="invalid-id",
                    node=node,
                    dependency=spec_id,
                    status=None,
                    path=(node, spec_id),
                )
            )
        else:
            spec_path, spec_error = resolve_canonical_spec_path(spec_id, root=root)
            if spec_path is None:
                issues.add(
                    DependencyIssue(
                        code=spec_error or "missing",
                        node=node,
                        dependency=spec_id,
                        status=None,
                        path=(node, spec_id),
                    )
                )
        return issues.project()

    def blocker_completion_issues(
        dependent: str,
        blocker: str,
    ) -> tuple[DependencyIssue, ...]:
        matches = records_by_name.get(blocker, [])
        if len(matches) != 1:
            return ()
        _, _, _, spec_id = matches[0]
        prefix = (dependent, blocker)
        if not SPEC_ID_RE.fullmatch(spec_id):
            return (
                DependencyIssue(
                    code="invalid-id",
                    node=blocker,
                    dependency=spec_id or "<empty>",
                    status=None,
                    path=prefix + (spec_id or "<empty>",),
                ),
            )

        spec_path, spec_error = resolve_canonical_spec_path(spec_id, root=root)
        if spec_path is None:
            return (
                DependencyIssue(
                    code=spec_error or "missing",
                    node=blocker,
                    dependency=spec_id,
                    status=None,
                    path=prefix + (spec_id,),
                ),
            )
        try:
            spec = parse_frontmatter(spec_path.read_text(encoding="utf-8"))
        except OSError:
            return (
                DependencyIssue(
                    code="ambiguous",
                    node=blocker,
                    dependency=spec_id,
                    status=None,
                    path=prefix + (spec_id,),
                ),
            )

        linked_tickets = tuple(
            str(value).strip()
            for value in parse_list(spec.get("linked_tickets"))
            if str(value).strip()
        )
        if not linked_tickets:
            return (
                DependencyIssue(
                    code="pending",
                    node=blocker,
                    dependency=spec_id,
                    status="no-linked-tickets",
                    path=prefix + (spec_id,),
                ),
            )

        issues = _IssueAccumulator(dependent)
        ticket_counts = Counter(linked_tickets)
        for ticket_id, count in sorted(ticket_counts.items()):
            ticket_path = prefix + (ticket_id,)
            if count > 1:
                issues.add(
                    DependencyIssue(
                        code="duplicate",
                        node=blocker,
                        dependency=ticket_id,
                        status=None,
                        path=ticket_path,
                    )
                )
            if not TICKET_ID_RE.fullmatch(ticket_id):
                issues.add(
                    DependencyIssue(
                        code="invalid-id",
                        node=blocker,
                        dependency=ticket_id,
                        status=None,
                        path=ticket_path,
                    )
                )
                continue
            ticket_readiness = evaluate_ticket_dependencies(
                ticket_id,
                root=root,
            )
            issues.extend(
                DependencyIssue(
                    code=issue.code,
                    node=issue.node,
                    dependency=issue.dependency,
                    status=issue.status,
                    path=prefix + issue.path,
                )
                for issue in ticket_readiness.issues
            )
            resolved_ticket, ticket_error = resolve_canonical_ticket_path(
                ticket_id,
                root=root,
            )
            if resolved_ticket is None:
                if not ticket_readiness.issues:
                    issues.add(
                        DependencyIssue(
                            code=ticket_error or "missing",
                            node=blocker,
                            dependency=ticket_id,
                            status=None,
                            path=ticket_path,
                        )
                    )
                continue
            try:
                ticket = parse_frontmatter(
                    resolved_ticket.read_text(encoding="utf-8")
                )
            except OSError:
                issues.add(
                    DependencyIssue(
                        code="ambiguous",
                        node=blocker,
                        dependency=ticket_id,
                        status=None,
                        path=ticket_path,
                    )
                )
                continue
            status = str(ticket.get("status") or "").strip()
            if status not in SATISFIED_TICKET_STATUSES:
                issues.add(
                    DependencyIssue(
                        code="pending",
                        node=blocker,
                        dependency=ticket_id,
                        status=status or "<empty>",
                        path=ticket_path,
                    )
                )
        return issues.project()

    local_issues_by_node: dict[str, tuple[DependencyIssue, ...]] = {}
    for safe_name, raw_name, dependencies, spec_id in normalized:
        node = raw_name if MODULE_NAME_RE.fullmatch(raw_name) else safe_name
        if node in local_issues_by_node:
            continue
        issues = list(local_structural_issues(
            node,
            raw_name,
            dependencies,
            spec_id,
        ))
        issues.extend(cycle_issues_by_node.get(node, ()))
        local_issues_by_node[node] = bounded_dependency_issues(
            issues,
            owner=node,
        )

    results: dict[str, DependencyReadiness] = {}
    evaluating: set[str] = set()

    def start_evaluation(node: str) -> _PlanEvaluationFrame | None:
        records = records_by_name.get(node, [])
        if len(records) != 1:
            results[node] = DependencyReadiness(
                eligible=False,
                dependencies=(),
                issues=local_issues_by_node.get(node, ()),
            )
            return None

        _, raw_name, dependencies, _ = records[0]
        issues = _IssueAccumulator(node)
        issues.extend(local_issues_by_node.get(node, ()))
        upstream_dependencies = tuple(
            dependency
            for dependency in sorted(set(dependencies))
            if (
                MODULE_NAME_RE.fullmatch(dependency)
                and dependency != raw_name
                and len(records_by_name.get(dependency, [])) == 1
            )
        )
        return _PlanEvaluationFrame(
            node=node,
            dependencies=dependencies,
            upstream_dependencies=upstream_dependencies,
            issues=issues,
        )

    def extend_upstream(
        frame: _PlanEvaluationFrame,
        dependency: str,
    ) -> None:
        upstream = results[dependency]
        frame.issues.extend(
            DependencyIssue(
                code=issue.code,
                node=issue.node,
                dependency=issue.dependency,
                status=issue.status,
                path=(frame.node,) + issue.path,
            )
            for issue in upstream.issues
        )

    for safe_name, raw_name, _, _ in normalized:
        node = raw_name if MODULE_NAME_RE.fullmatch(raw_name) else safe_name
        if node in results:
            continue
        first_frame = start_evaluation(node)
        if first_frame is None:
            continue

        evaluating.add(node)
        stack = [first_frame]
        while stack:
            frame = stack[-1]
            if frame.waiting_for is not None:
                dependency = frame.waiting_for
                frame.waiting_for = None
                extend_upstream(frame, dependency)
                continue

            if frame.next_index >= len(frame.upstream_dependencies):
                ordered = frame.issues.project()
                results[frame.node] = DependencyReadiness(
                    eligible=not frame.issues.saw_issue,
                    dependencies=tuple(sorted(frame.dependencies)),
                    issues=ordered,
                )
                evaluating.discard(frame.node)
                stack.pop()
                continue

            dependency = frame.upstream_dependencies[frame.next_index]
            frame.next_index += 1
            frame.issues.extend(
                blocker_completion_issues(frame.node, dependency)
            )
            if dependency in evaluating:
                continue
            if dependency in results:
                extend_upstream(frame, dependency)
                continue

            child_frame = start_evaluation(dependency)
            if child_frame is None:
                extend_upstream(frame, dependency)
                continue
            frame.waiting_for = dependency
            evaluating.add(dependency)
            stack.append(child_frame)

    return {node: results[node] for node in sorted(results)}
