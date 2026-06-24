/// Valores públicos por diseño: el anon key de Supabase es para clientes; la
/// seguridad real está en RLS + la validación de JWT del backend.
class Config {
  static const String supabaseUrl = 'https://bwjupdnnwgosivknpsoy.supabase.co';
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImJ3anVwZG5ud2dvc2l2a25wc295Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3ODIzMDQ2NzYsImV4cCI6MjA5Nzg4MDY3Nn0.GNiFL1gwE9utpgEhr7GBEdUYYG_QVPZfbGd9aw77MB8';

  /// En web (demo) el backend corre en localhost. En mobile real habría que usar
  /// la IP de la máquina o un backend desplegado (fuera de scope).
  static const String backendBaseUrl = 'http://localhost:8000/api/v1';
}
