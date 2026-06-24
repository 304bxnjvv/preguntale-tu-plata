/// Valores públicos por diseño: el anon key de Supabase es para clientes; la
/// seguridad real está en RLS + la validación de JWT del backend.
class Config {
  static const String supabaseUrl = 'https://bwjupdnnwgosivknpsoy.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3anVwZG5ud2dvc2l2a25wc295Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzMDQ2NzYsImV4cCI6MjA5Nzg4MDY3Nn0.GNiFL1gwE9utpgEhr7GBEdUYYG_QVPZfbGd9aw77MB8';

  /// Backend desplegado en Hugging Face Spaces. Para desarrollo local contra el
  /// backend en localhost, cambiar a 'http://localhost:8000/api/v1'.
  static const String backendBaseUrl =
      'https://304bxnjvv-preguntale-tu-plata-api.hf.space/api/v1';
}
