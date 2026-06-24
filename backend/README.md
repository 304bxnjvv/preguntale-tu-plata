---
title: Preguntale Tu Plata API
emoji: 💰
colorFrom: green
colorTo: blue
sdk: docker
app_port: 7860
pinned: false
---

# Pregúntale a tu plata — Backend API

Backend FastAPI (RAG sobre transacciones bancarias chilenas) del proyecto
[preguntale-tu-plata](https://github.com/304bxnjvv/preguntale-tu-plata).

Stack: FastAPI · Supabase (Postgres + pgvector + Auth JWKS/ES256) · fastembed (ONNX) · DeepSeek.

## Secrets requeridos (Settings → Secrets del Space)
- `DEEPSEEK_API_KEY`
- `SUPABASE_URL`
- `POSTGRES_URL`

## Endpoints
- `GET /health`
- `POST /api/v1/transactions/upload-csv?banco=`
- `GET /api/v1/transactions`
- `GET /api/v1/transactions/summary`
- `POST /api/v1/chat/ask`
