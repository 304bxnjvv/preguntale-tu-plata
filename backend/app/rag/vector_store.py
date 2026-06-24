from langchain_community.vectorstores import PGVector
from langchain_community.embeddings import FastEmbedEmbeddings
from app.config import settings


def get_embeddings():
    # fastembed (ONNX) en vez de torch/sentence-transformers: mismo modelo
    # multilingüe (384-dim), mucho menos RAM → deployable en host chico.
    return FastEmbedEmbeddings(model_name=settings.embedding_model)


def get_vector_store() -> PGVector:
    return PGVector(
        connection_string=settings.postgres_url,
        embedding_function=get_embeddings(),
        collection_name=settings.collection_name,
    )
