class AuthConfig {
  // Keep this in sync with:
  // 1) AndroidManifest VIEW intent-filter
  // 2) Supabase Authentication -> Additional Redirect URLs
  static const String callbackScheme = 'com.example.flutter_app';
  static const String callbackHost = 'login-callback';
  static const String callbackUrl = '$callbackScheme://$callbackHost';
}
