import jwt
import pytest
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives import serialization
from app.auth.jwt import decode_user_id


def _keypair():
    priv = ec.generate_private_key(ec.SECP256R1())
    priv_pem = priv.private_bytes(
        serialization.Encoding.PEM,
        serialization.PrivateFormat.PKCS8,
        serialization.NoEncryption(),
    )
    pub_pem = priv.public_key().public_bytes(
        serialization.Encoding.PEM,
        serialization.PublicFormat.SubjectPublicKeyInfo,
    )
    return priv_pem, pub_pem


def test_decode_valid_token_returns_user_id():
    priv, pub = _keypair()
    token = jwt.encode(
        {"sub": "user-abc", "aud": "authenticated"}, priv, algorithm="ES256"
    )
    assert decode_user_id(token, pub, ["ES256"]) == "user-abc"


def test_decode_token_without_sub_raises():
    priv, pub = _keypair()
    token = jwt.encode({"aud": "authenticated"}, priv, algorithm="ES256")
    with pytest.raises(ValueError):
        decode_user_id(token, pub, ["ES256"])


def test_decode_token_with_wrong_key_raises():
    priv1, _ = _keypair()
    _, pub2 = _keypair()
    token = jwt.encode(
        {"sub": "user-abc", "aud": "authenticated"}, priv1, algorithm="ES256"
    )
    with pytest.raises(jwt.InvalidTokenError):
        decode_user_id(token, pub2, ["ES256"])
