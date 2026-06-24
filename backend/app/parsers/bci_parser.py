import io
from datetime import datetime
import pandas as pd
from app.parsers.base_parser import BaseParser
from app.models.schemas import Transaccion


class BciParser(BaseParser):
    """
    CSV BCI: Fecha | Descripción | Cargo | Abono | Saldo
    Encoding: latin-1, separador: ;
    """

    def parse(self, content: bytes) -> list[Transaccion]:
        df = pd.read_csv(
            io.BytesIO(content),
            sep=";",
            encoding="latin-1",
            dtype=str,
        )
        df.columns = [c.strip().lower() for c in df.columns]

        transacciones = []
        for _, row in df.iterrows():
            try:
                fecha = datetime.strptime(row["fecha"].strip(), "%d/%m/%Y").date()
                cargo = self._limpiar_monto(row.get("cargo", "0") or "0")
                abono = self._limpiar_monto(row.get("abono", "0") or "0")

                monto = -cargo if cargo > 0 else abono
                tipo = "cargo" if cargo > 0 else "abono"

                transacciones.append(
                    Transaccion(
                        fecha=fecha,
                        descripcion=row["descripción"].strip(),
                        monto=monto,
                        tipo=tipo,
                        banco="BCI",
                    )
                )
            except Exception:
                continue

        return transacciones
