from langchain_community.vectorstores import PGVector
from langchain_google_genai import GoogleGenerativeAIEmbeddings
from app.config import settings


def get_embeddings():
    return GoogleGenerativeAIEmbeddings(
        model=settings.gemini_embedding_model,
        google_api_key=settings.gemini_api_key,
    )


def get_vector_store() -> PGVector:
    return PGVector(
        connection_string=settings.postgres_url,
        embedding_function=get_embeddings(),
        collection_name=settings.collection_name,
    )
