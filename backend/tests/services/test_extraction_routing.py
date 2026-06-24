import pytest
from app.services import extraction_service as ex


def test_dispatch_pdf(monkeypatch):
    monkeypatch.setattr(ex, "extract_from_pdf", lambda c: ["PDF"])
    assert ex.extract_from_file(b"x", "cartola.PDF") == ["PDF"]


def test_dispatch_csv(monkeypatch):
    monkeypatch.setattr(ex, "extract_from_csv", lambda c: ["CSV"])
    assert ex.extract_from_file(b"x", "cartola.csv") == ["CSV"]


def test_dispatch_imagen(monkeypatch):
    monkeypatch.setattr(ex, "extract_from_image", lambda c, e: ["IMG"])
    assert ex.extract_from_file(b"x", "boleta.jpg") == ["IMG"]


def test_dispatch_no_soportado():
    with pytest.raises(ValueError):
        ex.extract_from_file(b"x", "archivo.txt")


def test_extract_from_csv_decodifica(monkeypatch):
    captured = {}
    monkeypatch.setattr(ex, "extract_from_text", lambda t: captured.setdefault("t", t) or [])
    ex.extract_from_csv("fecha;glosa\n01/06;café".encode("latin-1"))
    assert "café" in captured["t"]
