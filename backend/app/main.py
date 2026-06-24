from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import upload, ask

app = FastAPI(
    title="Pregúntale a tu plata API",
    description="RAG sobre estados de cuenta bancarios chilenos",
    version="0.1.0",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # restringir en producción
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(upload.router, prefix="/api/v1", tags=["upload"])
app.include_router(ask.router, prefix="/api/v1", tags=["ask"])


@app.get("/health")
def health():
    return {"status": "ok"}
