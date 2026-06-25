"""Aplica archivos de migración .sql a Postgres (Supabase) usando POSTGRES_URL.

Uso:
    python scripts/apply_migrations.py migrations/006_presupuestos_metas.sql migrations/007_categoria_override.sql

Lee POSTGRES_URL del entorno o de backend/.env. Cada archivo se aplica en su
propia transacción (commit al éxito, rollback al error). Las migraciones usan
`create table if not exists` / `add column if not exists`, así que reaplicar es
seguro salvo por las policies RLS (que fallan si ya existen); en ese caso el
error se reporta y el script termina con código != 0.
"""
from __future__ import annotations

import os
import sys
from pathlib import Path

import psycopg2

ROOT = Path(__file__).resolve().parent.parent  # carpeta backend/


def _load_postgres_url() -> str:
    url = os.environ.get("POSTGRES_URL")
    if url:
        return url
    env_path = ROOT / ".env"
    if env_path.exists():
        for line in env_path.read_text(encoding="utf-8").splitlines():
            line = line.strip()
            if not line or line.startswith("#") or "=" not in line:
                continue
            key, _, val = line.partition("=")
            if key.strip() == "POSTGRES_URL":
                return val.strip().strip('"').strip("'")
    raise SystemExit("POSTGRES_URL no encontrado (ni en entorno ni en backend/.env)")


def apply(paths: list[str]) -> None:
    # psycopg2 no entiende el esquema SQLAlchemy "postgresql+psycopg2://"
    url = _load_postgres_url().replace("postgresql+psycopg2://", "postgresql://")
    conn = psycopg2.connect(url)
    try:
        for rel in paths:
            sql_path = (ROOT / rel).resolve()
            if not sql_path.exists():
                raise SystemExit(f"No existe el archivo: {sql_path}")
            sql = sql_path.read_text(encoding="utf-8")
            try:
                with conn.cursor() as cur:
                    cur.execute(sql)
                conn.commit()
                print(f"OK  {rel}")
            except Exception as e:  # noqa: BLE001
                conn.rollback()
                print(f"ERR {rel}: {e}")
                raise SystemExit(1)
    finally:
        conn.close()


if __name__ == "__main__":
    if len(sys.argv) < 2:
        raise SystemExit("Uso: python scripts/apply_migrations.py <archivo.sql> [...]")
    apply(sys.argv[1:])
    print("Migraciones aplicadas.")
