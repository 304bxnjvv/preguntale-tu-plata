import io
from datetime import datetime
import pandas as pd
from app.parsers.base_parser import BaseParser
from app.models.schemas import Transaccion


class BancoEstadoParser(BaseParser):
    """
    CSV BancoEstado: Fecha | Glosa | Débito | Crédito | Saldo
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
                debito = self._limpiar_monto(row.get("débito", "0") or "0")
                credito = self._limpiar_monto(row.get("crédito", "0") or "0")

                monto = -debito if debito > 0 else credito
                tipo = "cargo" if debito > 0 else "abono"

                transacciones.append(
                    Transaccion(
                        fecha=fecha,
                        descripcion=row["glosa"].strip(),
                        monto=monto,
                        tipo=tipo,
                        banco="BancoEstado",
                    )
                )
            except Exception:
                continue

        return transacciones
