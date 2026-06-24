import pytest
from app.services.upload_limit import check_limit, log_upload, UploadLimitError, LIMITE_MENSUAL


def test_log_y_check_bajo_limite(session):
    for i in range(LIMITE_MENSUAL - 1):
        log_upload(session, "u1", f"f{i}.pdf", 3)
    check_limit(session, "u1")  # 19 < 20 → no lanza


def test_check_corta_en_el_limite(session):
    for i in range(LIMITE_MENSUAL):
        log_upload(session, "u1", f"f{i}.pdf", 1)
    with pytest.raises(UploadLimitError):
        check_limit(session, "u1")


def test_limite_es_por_usuario(session):
    for i in range(LIMITE_MENSUAL):
        log_upload(session, "u1", f"f{i}.pdf", 1)
    check_limit(session, "u2")  # otro usuario, sin subidas → no lanza
