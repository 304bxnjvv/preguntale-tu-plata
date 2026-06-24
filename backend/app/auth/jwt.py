import jwt
from jwt import PyJWKClient
from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials
from app.config import settings


def decode_user_id(token: str, key, algorithms: list[str]) -> str:
    """Valida un JWT de Supabase y devuelve el user_id (claim 'sub')."""
    payload = jwt.decode(
        token,
        key,
        algorithms=algorithms,
        audience="authenticated",
    )
    user_id = payload.get("sub")
    if not user_id:
        raise ValueError("Token sin claim 'sub'")
    return user_id


_bearer = HTTPBearer()
# PyJWKClient es lazy: no llama a la red hasta el primer get_signing_key_from_jwt.
_jwks_client = PyJWKClient(settings.supabase_jwks_url)


def get_current_user(
    creds: HTTPAuthorizationCredentials = Depends(_bearer),
) -> str:
    try:
        signing_key = _jwks_client.get_signing_key_from_jwt(creds.credentials)
        return decode_user_id(creds.credentials, signing_key.key, ["ES256"])
    except Exception:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Token inválido o expirado",
        )
