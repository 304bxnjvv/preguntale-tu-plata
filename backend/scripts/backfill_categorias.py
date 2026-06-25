"""
backfill_categorias.py
======================
Script standalone para categorizar transacciones que tienen categoria NULL o vacía.

Estrategia (dos pasos):
  1. Aplicar reglas deterministas (categorizar_por_reglas) — sin LLM, sin costo.
  2. Para las que quedan sin categoría, hacer UNA llamada LLM batch sobre las
     descripciones únicas y luego normalizar el resultado.

USO:
    python scripts/backfill_categorias.py

NO corre automáticamente. El usuario lo ejecuta manualmente.
"""

import os
import sys
from pathlib import Path

# Añadir el directorio raíz del proyecto al PYTHONPATH
ROOT = Path(__file__).resolve().parent.parent
sys.path.insert(0, str(ROOT))

# Cargar .env antes de importar la app
from dotenv import load_dotenv
load_dotenv(ROOT / ".env")

from sqlalchemy import create_engine, text
from sqlalchemy.orm import sessionmaker
from pydantic import BaseModel
from langchain_openai import ChatOpenAI

from app.services.categorias import (
    CATEGORIAS,
    categorizar_por_reglas,
    normalizar,
)


# ---------------------------------------------------------------------------
# Conexión DB
# ---------------------------------------------------------------------------

def _get_engine():
    raw_url = os.environ["POSTGRES_URL"]
    # Asegurar que use psycopg2
    url = raw_url.replace("postgresql://", "postgresql+psycopg2://")
    if "+psycopg2" not in url:
        url = url.replace("postgresql://", "postgresql+psycopg2://")
    return create_engine(url)


# ---------------------------------------------------------------------------
# Batch LLM para descripciones sin regla
# ---------------------------------------------------------------------------

class ItemCategorizado(BaseModel):
    descripcion: str
    categoria: str


class BatchCategorizacion(BaseModel):
    items: list[ItemCategorizado]


def _categorizar_con_llm(descripciones: list[str]) -> dict[str, str]:
    """
    Llama al LLM una sola vez para categorizar todas las descripciones únicas.
    Devuelve dict {descripcion: categoria_normalizada}.
    """
    if not descripciones:
        return {}

    api_key = os.environ.get("OPENAI_API_KEY", "")
    llm = ChatOpenAI(
        model="gpt-4o-mini",
        api_key=api_key,
        temperature=0,
    ).with_structured_output(BatchCategorizacion)

    cats_str = ", ".join(f'"{c}"' for c in CATEGORIAS)
    prompt = (
        f"Clasifica cada descripción de transacción bancaria chilena en UNA de estas categorías: {cats_str}.\n"
        "Si no sabes, usa \"Otros\".\n"
        "Devuelve EXACTAMENTE un objeto JSON con campo 'items', lista de objetos con 'descripcion' y 'categoria'.\n\n"
        "Descripciones a clasificar:\n"
        + "\n".join(f"- {d}" for d in descripciones)
    )

    result: BatchCategorizacion = llm.invoke(prompt)

    out: dict[str, str] = {}
    for item in result.items:
        cat = normalizar(item.categoria) or "Otros"
        out[item.descripcion] = cat
    return out


# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

def main():
    engine = _get_engine()
    Session = sessionmaker(bind=engine)
    session = Session()

    try:
        # Fetch transactions sin categoría
        rows = session.execute(
            text("SELECT id, descripcion FROM transactions WHERE categoria IS NULL OR categoria = ''")
        ).fetchall()

        if not rows:
            print("No hay transacciones sin categoría. Nada que hacer.")
            return

        print(f"Transacciones sin categoría: {len(rows)}")

        # Paso 1: reglas deterministas
        actualizadas_reglas = 0
        sin_regla: list[tuple[str, str]] = []  # (id, descripcion)

        for row in rows:
            txn_id, descripcion = row[0], row[1]
            cat = categorizar_por_reglas(descripcion or "")
            if cat:
                session.execute(
                    text("UPDATE transactions SET categoria = :cat WHERE id = :id"),
                    {"cat": cat, "id": txn_id},
                )
                actualizadas_reglas += 1
            else:
                sin_regla.append((txn_id, descripcion or ""))

        session.commit()
        print(f"  Actualizadas por reglas: {actualizadas_reglas}")

        # Paso 2: LLM batch para las que quedaron sin categoría
        actualizadas_llm = 0
        if sin_regla:
            desc_unicas = list({d for _, d in sin_regla})
            print(f"  Enviando al LLM {len(desc_unicas)} descripciones únicas...")

            mapa = _categorizar_con_llm(desc_unicas)

            for txn_id, descripcion in sin_regla:
                cat = mapa.get(descripcion) or "Otros"
                session.execute(
                    text("UPDATE transactions SET categoria = :cat WHERE id = :id"),
                    {"cat": cat, "id": txn_id},
                )
                actualizadas_llm += 1

            session.commit()
            print(f"  Actualizadas por LLM: {actualizadas_llm}")

        # Resumen por categoría
        total = actualizadas_reglas + actualizadas_llm
        print(f"\nTotal actualizadas: {total}")

        conteo = session.execute(
            text(
                "SELECT categoria, COUNT(*) as n FROM transactions "
                "WHERE categoria IS NOT NULL GROUP BY categoria ORDER BY n DESC"
            )
        ).fetchall()

        print("\nConteo por categoría:")
        for cat, n in conteo:
            print(f"  {cat}: {n}")

    finally:
        session.close()


if __name__ == "__main__":
    main()
