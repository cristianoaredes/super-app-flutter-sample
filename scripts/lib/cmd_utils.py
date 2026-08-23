#!/usr/bin/env python3
"""cmd_utils.py — CmdExecutor com retry, backoff, logging e circuit breaker (GAP-001).

Executor de comandos shell robusto com:
- Retry automático com exponential backoff
- Logging estruturado
- Timeout dinâmico
- Circuit breaker para falhas repetidas
- Métricas de execução

usage:
  from lib.cmd_utils import CmdExecutor

  executor = CmdExecutor(timeout=60, max_retries=2, backoff_factor=1.5)
  result = executor.run("python3 -m pytest", cwd=Path("/project"))

  if result.success:
      print(f"OK: {result.stdout}")
  else:
      print(f"FAIL: {result.stderr}")
"""

from __future__ import annotations

import logging
import subprocess
import time
import warnings
from dataclasses import dataclass
from pathlib import Path
from typing import Optional

# FND-0047: shell command validation — reject injection patterns before execution.
# Import is fail-open: if trust_boundary has bugs, we log a warning and continue.
try:
    from lib.trust_boundary import validate_shell_command, CommandValidationResult
    _HAS_TRUST_BOUNDARY = True
except ImportError as _e:
    logger_init = logging.getLogger(__name__)
    logger_init.warning("FND-0047: could not import trust_boundary: %s — shell validation disabled", _e)
    _HAS_TRUST_BOUNDARY = False

logger = logging.getLogger(__name__)


@dataclass
class CmdResult:
    """Resultado de execução de comando."""
    success: bool
    returncode: int
    stdout: str
    stderr: str
    attempt: int
    total_time_ms: int
    timeout_hit: bool = False


class CircuitBreaker:
    """Circuit breaker para comandos que falham repetidamente."""

    def __init__(self, failure_threshold: int = 3, timeout_seconds: int = 60):
        self.failure_threshold = failure_threshold
        self.timeout_seconds = timeout_seconds
        self.failures = 0
        self.last_failure_time: Optional[float] = None
        self.state = "closed"  # closed, open, half-open

    def record_success(self):
        """Registra sucesso e reseta contador."""
        self.failures = 0
        self.state = "closed"

    def record_failure(self):
        """Registra falha e possibly abre circuit."""
        self.failures += 1
        self.last_failure_time = time.time()

        if self.failures >= self.failure_threshold:
            self.state = "open"
            logger.warning(f"Circuit breaker OPEN após {self.failures} falhas consecutivas")

    def can_execute(self) -> bool:
        """Verifica se comando pode ser executado."""
        if self.state == "closed":
            return True

        if self.state == "open":
            # Tenta entrar em half-open após timeout
            if (time.time() - self.last_failure_time) > self.timeout_seconds:
                self.state = "half-open"
                logger.info("Circuit breaker HALF-OPEN")
                return True
            return False

        if self.state == "half-open":
            return True

        return False


class CmdExecutor:
    """Executor de comandos shell com retry e circuit breaker."""

    def __init__(
        self,
        timeout: int = 60,
        max_retries: int = 2,
        backoff_factor: float = 1.5,
        max_delay: float = 30.0,
        enable_circuit_breaker: bool = False,
        circuit_breaker_threshold: int = 3
    ):
        """
        Inicializa executor.

        Args:
            timeout: Timeout padrão em segundos
            max_retries: Máximo de tentativas de retry
            backoff_factor: Fator de backoff exponencial
            max_delay: Teto máximo de espera entre retries em segundos (TCK-0396)
            enable_circuit_breaker: Habilita circuit breaker
            circuit_breaker_threshold: Limite de falhas para abrir circuit
        """
        self.timeout = timeout
        self.max_retries = max_retries
        self.backoff_factor = backoff_factor
        self.max_delay = max_delay
        self.enable_circuit_breaker = enable_circuit_breaker
        self.circuit_breaker = CircuitBreaker(
            failure_threshold=circuit_breaker_threshold
        ) if enable_circuit_breaker else None

    def run(
        self,
        cmd: str,
        cwd: Optional[Path] = None,
        timeout_override: Optional[int] = None,
        retries_override: Optional[int] = None
    ) -> CmdResult:
        """
        Executa comando com retry automático.

        Args:
            cmd: Comando shell a executar
            cwd: Diretório de trabalho (default: cwd atual)
            timeout_override: Override de timeout para esta execução
            retries_override: Override de max_retries para esta execução

        Returns:
            CmdResult com sucesso, stdout, stderr, etc.
        """
        if self.enable_circuit_breaker and not self.circuit_breaker.can_execute():
            logger.error(f"Circuit breaker OPEN: comando bloqueado: {cmd[:50]}...")
            return CmdResult(
                success=False,
                returncode=-1,
                stdout="",
                stderr="Circuit breaker OPEN: comandos bloqueados temporariamente",
                attempt=0,
                total_time_ms=0
            )

        cwd = cwd or Path.cwd()
        # FUP-D (VER onda-2): mesma forma falsy-zero do TCK-0597, uma linha
        # acima do fix — timeout_override=0 não deve virar o default em silêncio.
        timeout = (timeout_override if timeout_override is not None
                   else self.timeout)
        # TCK-0597: `or` engolia retries_override=0 (falsy) e usava o default —
        # mesma forma do TCK-0578; zero é valor válido ("sem retry, 1 tentativa").
        max_retries = (retries_override if retries_override is not None
                       else self.max_retries)

        # FND-0047: validate command for shell injection patterns.
        # Fail-open: if trust_boundary import failed, log warning but proceed.
        if _HAS_TRUST_BOUNDARY:
            validation = validate_shell_command(cmd)
            if not validation.safe:
                logger.error("FND-0047: command rejected: %s — %.80s", validation.reason, cmd)
                return CmdResult(
                    success=False,
                    returncode=-1,
                    stdout="",
                    stderr=f"FND-0047 shell safety: {validation.reason}",
                    attempt=1,
                    total_time_ms=0
                )
        else:
            validation = None  # type: ignore[assignment]

        last_error = None
        last_stdout = ""  # TCK-0344: preserve stdout of the last failed attempt
        last_returncode = -1  # TCK-0578: rc real da última tentativa (-1 = nada rodou)
        start_time = time.time()

        # TCK-0578: max_retries é "quantas RE-tentativas", não "quantas
        # tentativas" — com 0, range(1, 1) era VAZIO e nenhum comando rodava
        # (toda chamada devolvia rc=-1 'Erro desconhecido'; o pipeline-judge
        # ficou 100% cego por isso). Piso: sempre >= 1 tentativa.
        for attempt in range(1, max(1, max_retries) + 1):
            try:
                logger.debug(f"Executando (tentativa {attempt}/{max_retries}): {cmd[:100]}...")

                # FND-0047: prefer shell=False with parsed argv for simple commands.
                # For commands with shell features (pipes, &&, redirects), wrap in bash -c.
                if validation is not None and validation.needs_shell:
                    proc_args: list[str] | str = ["bash", "-c", cmd]
                    use_shell = False
                elif validation is not None:
                    proc_args = validation.argv
                    use_shell = False
                else:
                    # Fallback when trust_boundary is unavailable (fail-open)
                    proc_args = ["bash", "-c", cmd]
                    use_shell = False

                proc = subprocess.run(
                    proc_args,
                    shell=use_shell,
                    cwd=str(cwd),
                    capture_output=True,
                    text=True,
                    timeout=timeout
                )

                total_time_ms = int((time.time() - start_time) * 1000)

                if proc.returncode == 0:
                    # Sucesso
                    if self.enable_circuit_breaker:
                        self.circuit_breaker.record_success()

                    logger.debug(
                        f"Comando OK (tentativa {attempt}, {total_time_ms}ms): {cmd[:50]}..."
                    )
                    return CmdResult(
                        success=True,
                        returncode=proc.returncode,
                        stdout=proc.stdout or "",
                        stderr=proc.stderr or "",
                        attempt=attempt,
                        total_time_ms=total_time_ms
                    )
                else:
                    # Falha não-timeout
                    last_error = proc.stderr or proc.stdout or "Erro desconhecido"
                    last_stdout = proc.stdout or ""  # TCK-0344: keep JSON-on-stdout from a non-zero exit (e.g. pipeline-verify FAIL)
                    last_returncode = proc.returncode  # TCK-0578
                    logger.warning(
                        f"Comando falhou (tentativa {attempt}, exit={proc.returncode}): "
                        f"{cmd[:50]}..."
                    )

                    # Não retry em erros de sintaxe ou argumentos
                    if self._is_non_retryable_error(proc.stderr or ""):
                        break

                    # TCK-0396: exponential backoff with cap for non-timeout failures
                    if attempt < max_retries:
                        sleep_time = min(
                            self.backoff_factor ** attempt, self.max_delay)
                        logger.info(f"Aguardando {sleep_time:.1f}s antes de retry...")
                        time.sleep(sleep_time)

            except subprocess.TimeoutExpired:
                total_time_ms = int((time.time() - start_time) * 1000)
                last_error = f"Timeout após {timeout}s"
                logger.warning(f"Timeout (tentativa {attempt}): {cmd[:50]}...")

                if attempt < max_retries:
                    sleep_time = min(
                        timeout * self.backoff_factor ** (attempt - 1),
                        self.max_delay,
                    )
                    logger.info(f"Aguardando {sleep_time:.1f}s antes de retry...")
                    time.sleep(sleep_time)
                else:
                    if self.enable_circuit_breaker:
                        self.circuit_breaker.record_failure()

                    return CmdResult(
                        success=False,
                        returncode=-1,
                        stdout="",
                        stderr=last_error,
                        attempt=attempt,
                        total_time_ms=total_time_ms,
                        timeout_hit=True
                    )

            except Exception as e:
                total_time_ms = int((time.time() - start_time) * 1000)
                last_error = str(e)
                logger.error(f"Exceção (tentativa {attempt}): {e}")

        # Todas as tentativas falharam
        total_time_ms = int((time.time() - start_time) * 1000)

        if self.enable_circuit_breaker:
            self.circuit_breaker.record_failure()

        error_msg = last_error
        if not error_msg:
            if max_retries > 1:
                error_msg = "Erro desconhecido após múltiplas tentativas"
            else:
                error_msg = "Erro desconhecido"

        return CmdResult(
            success=False,
            returncode=last_returncode,  # TCK-0578: rc REAL da última tentativa; -1 só se nada rodou
            stdout=last_stdout,  # TCK-0344: a non-zero exit can still carry meaningful stdout
            stderr=error_msg,
            attempt=max_retries,
            total_time_ms=total_time_ms
        )

    def _is_non_retryable_error(self, stderr: str) -> bool:
        """Detecta erros que não devem ser retryados."""
        non_retryable_patterns = [
            "command not found",
            "No such file or directory",
            "syntax error",
            "invalid argument",
            "usage:",
            "error: unrecognized"
        ]

        stderr_lower = stderr.lower()
        for pattern in non_retryable_patterns:
            if pattern in stderr_lower:
                return True

        return False


# Função de compatibilidade para migração fácil de run_cmd()
def run_cmd(
    cmd: str,
    cwd: Optional[Path] = None,
    timeout: int = 60
) -> tuple[int, str, str]:
    """
    Função de compatibilidade para migração de run_cmd().

    Args:
        cmd: Comando shell
        cwd: Diretório de trabalho
        timeout: Timeout em segundos

    Returns:
        (returncode, stdout, stderr)
    """
    executor = CmdExecutor(timeout=timeout, max_retries=0)  # Sem retry para compatibilidade
    result = executor.run(cmd, cwd=cwd)
    return result.returncode, result.stdout, result.stderr


def safe_shell_execute(
    cmd: str,
    cwd: Optional[Path] = None,
    timeout: int = 120
) -> CmdResult:
    """FND-0047: Safe shell command execution wrapper.

    Validates the command through the trust boundary before execution,
    logs the command being run, and executes with timeout and output capture.

    This is the recommended entry point for running acceptance criteria
    commands when shell features (pipes, &&, redirects) may be present.

    Args:
        cmd: Shell command string to execute.
        cwd: Working directory (default: current directory).
        timeout: Timeout in seconds (default: 120).

    Returns:
        CmdResult with success status, output, and timing.

    Safety:
        - Commands containing ; or backticks are REJECTED.
        - Commands with $(...) substitution are REJECTED.
        - Pipes to dangerous commands (curl|bash, etc.) are REJECTED.
        - All other commands run with shell=False.
    """
    logger.info("FND-0047 safe_shell_execute: %.120s", cmd)

    # Validate through trust boundary (fail-open on import errors)
    if _HAS_TRUST_BOUNDARY:
        validation = validate_shell_command(cmd)
        if not validation.safe:
            logger.error("FND-0047: safe_shell_execute rejected: %s", validation.reason)
            return CmdResult(
                success=False,
                returncode=-1,
                stdout="",
                stderr=f"FND-0047 shell safety: {validation.reason}",
                attempt=1,
                total_time_ms=0
            )
    else:
        # FND-0085: fail-open must be LOUD — every call that skips validation
        # because the trust boundary import failed emits a visible warning.
        warnings.warn(
            "FND-0047: trust boundary DEGRADED — lib.trust_boundary import failed; "
            "safe_shell_execute is running WITHOUT shell command validation (fail-open).",
            RuntimeWarning,
            stacklevel=2,
        )

    executor = CmdExecutor(timeout=timeout, max_retries=0)
    return executor.run(cmd, cwd=cwd)