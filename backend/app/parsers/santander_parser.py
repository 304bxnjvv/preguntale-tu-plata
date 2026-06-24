import io
from datetime import datetime
import pandas as pd
from app.parsers.base_parser import BaseParser
from app.models.schemas import Transaccion


class SantanderParser(BaseParser):
    """
    CSV Santander Chile: Fecha | Descripción | Monto | Saldo
    Encoding: utf-8, separador: ,
    Monto negativo = cargo, positivo = abono
    """

    def parse(self, content: bytes) -> list[Transaccion]:
        df = pd.read_csv(
            io.BytesIO(content),
            sep=",",
            encoding="utf-8",
            dtype=str,
        )
        df.columns = [c.strip().lower() for c in df.columns]

        transacciones = []
        for _, row in df.iterrows():
            try:
                fecha = datetime.strptime(row["fecha"].strip(), "%d/%m/%Y").date()
                monto = self._limpiar_monto(row["monto"])
                tipo = "cargo" if monto < 0 else "abono"

                transacciones.append(
                    Transaccion(
                        fecha=fecha,
                        descripcion=row["descripción"].strip(),
                        monto=monto,
                        tipo=tipo,
                        banco="Santander",
                    )
                )
            except Exception:
                continue

        return transacciones
