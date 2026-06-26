from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from app.api.routes import upload, ask, insights, presupuestos
from app.api.routes.demo import router as demo_router
from app.api.routes.account import router as account_router
from app.api.routes.subscription import router as subscription_router
from app.api.routes.categorias import router as categorias_router

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

app.include_router(upload.router, prefix="/api/v1", tags=["transactions"])
app.include_router(ask.router, prefix="/api/v1", tags=["ask"])
app.include_router(insights.router, prefix="/api/v1", tags=["insights"])
app.include_router(presupuestos.router, prefix="/api/v1", tags=["presupuestos"])
app.include_router(categorias_router, prefix="/api/v1", tags=["categorias"])
app.include_router(demo_router, prefix="/api/v1")
app.include_router(account_router, prefix="/api/v1")
app.include_router(subscription_router, prefix="/api/v1")


@app.get("/health")
def health():
    return {"status": "ok"}
