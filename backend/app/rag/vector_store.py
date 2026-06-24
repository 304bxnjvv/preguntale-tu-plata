from langchain_community.vectorstores import PGVector
from langchain_community.embeddings import HuggingFaceEmbeddings
from app.config import settings


def get_embeddings():
    return HuggingFaceEmbeddings(
        model_name=settings.embedding_model,
        model_kwargs={"device": "cpu"},
        encode_kwargs={"normalize_embeddings": True},
    )


def get_vector_store() -> PGVector:
    return PGVector(
        connection_string=settings.postgres_url,
        embedding_function=get_embeddings(),
        collection_name=settings.collection_name,
    )
