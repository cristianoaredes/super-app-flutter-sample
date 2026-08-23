import datetime
import json
import logging
import os


class _JsonFormatter(logging.Formatter):
    """JSON log formatter: one valid JSON object per line.

    Output schema: {"ts": "<ISO-8601>", "level": "<LEVEL>", "name": "<logger>", "msg": "<message>"}

    Fail-open: if serialization fails, falls back to the default string representation.
    """

    def format(self, record: logging.LogRecord) -> str:
        try:
            log_entry = {
                "ts": datetime.datetime.fromtimestamp(
                    record.created, tz=datetime.timezone.utc
                ).isoformat(),
                "level": record.levelname,
                "name": record.name,
                "msg": record.getMessage(),
            }
            if record.exc_info and record.exc_info[1] is not None:
                log_entry["exc"] = self.formatException(record.exc_info)
            return json.dumps(log_entry, ensure_ascii=False, default=str)
        except Exception:
            # Fail-open: fall back to default human-readable format
            return (
                f"{datetime.datetime.fromtimestamp(record.created, tz=datetime.timezone.utc).isoformat()} "
                f"{record.levelname} {record.name}: {record.getMessage()}"
            )


_HUMAN_FORMAT = "%(asctime)s %(levelname)-8s %(name)s: %(message)s"
_HUMAN_DATEFMT = "%H:%M:%S"


def setup_logging(
    level: int | None = None,
    *,
    name: str | None = None,
    log_format: str | None = None,
) -> logging.Logger:
    """Configure logging with OPS_LOG_LEVEL / OPS_LOG_FORMAT env var support.

    Priority (level):  explicit level > OPS_LOG_LEVEL env > INFO default.
    Priority (format): explicit log_format > OPS_LOG_FORMAT env > human-readable default.

    Supported formats:
      - "human" (default): timestamp + level + name + message
      - "json": one JSON object per line (fail-open -- falls back to human on error)
    """
    if level is None:
        env_level = os.environ.get("OPS_LOG_LEVEL", "INFO").upper()
        level = getattr(logging, env_level, logging.INFO)

    fmt = log_format or os.environ.get("OPS_LOG_FORMAT", "human").lower()

    if fmt == "json":
        # Remove existing handlers to avoid duplication when force=True
        root = logging.getLogger()
        for h in root.handlers[:]:
            root.removeHandler(h)
        handler = logging.StreamHandler()
        handler.setFormatter(_JsonFormatter())
        root.addHandler(handler)
        root.setLevel(level)
    else:
        logging.basicConfig(
            level=level,
            format=_HUMAN_FORMAT,
            datefmt=_HUMAN_DATEFMT,
            force=True,
        )

    logger = logging.getLogger(name or "codebase-ops")
    logger.setLevel(level)
    return logger
