"""Sube el backend (esta carpeta) a un Space de Hugging Face con upload_folder.

Uso:
    python scripts/deploy_hf.py <owner/space_id>

Lee HF_TOKEN del entorno o de backend/.env. NUNCA sube .env, tests, .venv ni scripts.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

from huggingface_hub import upload_folder

ROOT = Path(__file__).resolve().parent.parent  # carpeta backend/


def _token() -> str | None:
    t = os.environ.get("HF_TOKEN")
    if t:
        return t
    env = ROOT / ".env"
    if env.exists():
        for line in env.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if line.startswith("HF_TOKEN="):
                return line.partition("=")[2].strip().strip('"').strip("'")
    # Sin HF_TOKEN explícito → None: huggingface_hub usará el token cacheado
    # del `huggingface-cli login` (lo que usó el deploy anterior).
    return None


IGNORE = [
    ".venv/*", "tests/*", "__pycache__/*", "*/__pycache__/*", "*.pyc",
    ".env", ".env.*", "scripts/*", "migrations/*", ".dockerignore", "*.md",
]


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Uso: python scripts/deploy_hf.py <owner/space_id>")
    space = sys.argv[1]
    res = upload_folder(
        folder_path=str(ROOT),
        repo_id=space,
        repo_type="space",
        token=_token(),
        ignore_patterns=IGNORE,
        commit_message="deploy: presupuestos/alertas/categorizacion + forecast/boletas/resumen",
    )
    print("HF upload OK ->", res)
