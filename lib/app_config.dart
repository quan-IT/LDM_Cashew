/// Public client configuration. Supply the publishable key at build time with
/// --dart-define; never embed a service-role key in the app.
class AppConfig {
  static const String supabaseUrl =
      String.fromEnvironment(
        'SUPABASE_URL',
        defaultValue: 'https://qoxrtnbyxdbpsnrcxwjn.supabase.co',
      );
  static const String supabasePublishableKey =
      String.fromEnvironment(
        'SUPABASE_PUBLISHABLE_KEY',
        defaultValue: 'sb_publishable_0UC7KhokNpkbL-n7ywdcqQ_x8hNbSa-',
      );

  static bool get isSupabaseConfigured =>
      supabaseUrl.startsWith('https://') &&
      supabasePublishableKey.isNotEmpty &&
      !supabaseUrl.contains('YOUR_PROJECT') &&
      !supabasePublishableKey.contains('YOUR_');

  // ─── Tên bảng Supabase ───
  static const String tableUsers = 'users';
  static const String tableDocuments = 'documents';
  static const String tablePermissions = 'document_permissions';

  static const String storageDocumentsPath = 'documents';
}