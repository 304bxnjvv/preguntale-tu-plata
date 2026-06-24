from abc import ABC, abstractmethod
import pandas as pd
from app.models.schemas import Transaccion


class BaseParser(ABC):
    @abstractmethod
    def parse(self, content: bytes) -> list[Transaccion]:
        pass

    def _limpiar_monto(self, valor: str) -> float:
        """Limpia formato chileno: '$1.234.567' → 1234567.0"""
        return float(
            str(valor)
            .replace("$", "")
            .replace(".", "")
            .replace(",", ".")
            .strip()
            or "0"
        )
