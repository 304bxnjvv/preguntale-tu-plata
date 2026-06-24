from pydantic_settings import BaseSettings


class Settings(BaseSettings):
    deepseek_api_key: str
    gemini_api_key: str
    postgres_url: str  # postgresql+psycopg2://user:pass@host:port/db

    deepseek_model: str = "deepseek-chat"
    gemini_embedding_model: str = "models/text-embedding-004"
    rag_top_k: int = 6
    collection_name: str = "transacciones"

    class Config:
        env_file = ".env"
        env_file_encoding = "utf-8"


settings = Settings()
