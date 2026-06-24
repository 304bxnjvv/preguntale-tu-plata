# 💬 Pregúntale a tu plata

> *"¿En qué gasté más este mes?"* — Chat en lenguaje natural sobre tus propios estados de cuenta bancarios chilenos.

[![CI](https://github.com/304bxnjvv/preguntale-tu-plata/actions/workflows/ci.yml/badge.svg)](https://github.com/304bxnjvv/preguntale-tu-plata/actions)
![Java](https://img.shields.io/badge/Java-17-orange)
![Spring Boot](https://img.shields.io/badge/Spring%20Boot-4.1-green)
![Spring AI](https://img.shields.io/badge/Spring%20AI-2.0-brightgreen)
![Flutter](https://img.shields.io/badge/Flutter-3.x-blue)

Sube tu estado de cuenta (CSV de BCI, Santander o BancoEstado) y hazle preguntas en español:

- *"¿Cuánto gasté en delivery en mayo?"*
- *"¿Cuándo fue mi último pago del dividendo?"*
- *"¿Puedo ahorrar $100.000 este mes?"*
- *"¿En qué categoría gasto más?"*

El sistema responde citando transacciones reales — sin inventar.

---

## 🏗️ Arquitectura

```
Flutter App (iOS / Android / Web)
        ↕ REST + JWT
Spring Boot 4 API  ──▶  Parser CSV (BCI/Santander/BancoEstado)
        ↕                       ↓
Spring AI 2.0            Transacciones + metadata
        ↕                  {fecha, monto, desc, categoría}
Gemini Embeddings                ↓
        ↕                   pgvector (Supabase)
DeepSeek LLM  ◀──  similarity search (top-K)
        ↓
Respuesta en español + citas de transacciones reales
```

## 🛠️ Stack

| Capa | Tecnología |
|------|-----------|
| Mobile / Web | Flutter 3 (Dart) |
| Backend API | Java 17, Spring Boot 4.1, Maven |
| AI / RAG | Spring AI 2.0, DeepSeek (LLM), Google Gemini (embeddings) |
| Vector store | pgvector (Supabase) |
| Auth | Spring Security, JWT |
| DB | PostgreSQL (Supabase) |
| CI | GitHub Actions |

## 📁 Estructura

```
preguntale-tu-plata/
├── backend/          # Spring Boot API
├── frontend/         # Flutter app
└── docs/             # Arquitectura y decisiones
```

## 🚀 Inicio rápido (backend)

```bash
cd backend
cp .env.example .env
# edita .env con tus keys
./run.ps1             # Windows
mvn spring-boot:run   # cualquier SO
```

## 🏦 Bancos soportados

- [x] BCI (CSV)
- [x] Santander Chile (CSV)
- [x] BancoEstado (CSV)
- [ ] Más bancos — PRs bienvenidos

---

> Proyecto de portafolio — Flutter + Spring Boot + IA (RAG). Autor: [Benjamín Rodríguez](https://linkedin.com/in/brodriguezq)
