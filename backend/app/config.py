from pydantic_settings import BaseSettings, SettingsConfigDict


class Settings(BaseSettings):
    openai_api_key: str
    postgres_url: str  # postgresql+psycopg2://user:pass@host:port/db
    supabase_url: str
    deepseek_api_key: str = ""  # opcional (legacy; el LLM ahora es OpenAI)

    flow_api_key: str = ""
    flow_secret: str = ""

    llm_model: str = "gpt-4o-mini"
    embedding_model: str = "sentence-transformers/paraphrase-multilingual-MiniLM-L12-v2"
    rag_top_k: int = 6
    collection_name: str = "transacciones"

    @property
    def supabase_jwks_url(self) -> str:
        return f"{self.supabase_url}/auth/v1/.well-known/jwks.json"

    model_config = SettingsConfigDict(env_file=".env", env_file_encoding="utf-8")


settings = Settings()
