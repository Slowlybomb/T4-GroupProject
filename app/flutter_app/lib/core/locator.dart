import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/repositories/activity_api_repository.dart';
import '../data/repositories/auth_repository.dart';
import '../data/repositories/dio_activity_api_repository.dart';
import '../data/repositories/feed_repository.dart';
import '../data/repositories/supabase_auth_repository.dart';
import '../data/repositories/user_repository.dart';
import 'config/runtime_config.dart';
import 'network/api_client.dart';
import 'network/auth_token_provider.dart';

class AppDependencies {
  final RuntimeConfig runtimeConfig;
  final SupabaseClient supabaseClient;
  final AuthTokenProvider authTokenProvider;
  final ApiClient apiClient;
  final ActivityApiRepository activityApiRepository;
  final FeedRepository feedRepository;
  final UserRepository userRepository;
  final AuthRepository authRepository;

  const AppDependencies({
    required this.runtimeConfig,
    required this.supabaseClient,
    required this.authTokenProvider,
    required this.apiClient,
    required this.activityApiRepository,
    required this.feedRepository,
    required this.userRepository,
    required this.authRepository,
  });

  factory AppDependencies.create(RuntimeConfig runtimeConfig) {
    // Use live Supabase session state for bearer-token injection.
    final supabaseClient = Supabase.instance.client;
    final authTokenProvider = SupabaseAuthTokenProvider(supabaseClient);
    final apiClient = ApiClient.create(
      config: runtimeConfig,
      authTokenProvider: authTokenProvider,
    );
    final activityApiRepository = DioActivityApiRepository(apiClient.dio);

    return AppDependencies(
      runtimeConfig: runtimeConfig,
      supabaseClient: supabaseClient,
      authTokenProvider: authTokenProvider,
      apiClient: apiClient,
      activityApiRepository: activityApiRepository,
      feedRepository: FeedRepository(
        activityApiRepository: activityApiRepository,
        useLocalFallback: runtimeConfig.useLocalFeedFallback,
      ),
      userRepository: UserRepository(),
      authRepository: SupabaseAuthRepository(supabaseClient),
    );
  }

  Future<void> dispose() async {
    await authTokenProvider.dispose();
  }
}

class Locator {
  static AppDependencies? _dependencies;

  static bool get isInitialized => _dependencies != null;

  static AppDependencies? get maybeDependencies => _dependencies;

  static Future<void> initialize(RuntimeConfig runtimeConfig) async {
    // Idempotent app bootstrap.
    _dependencies ??= AppDependencies.create(runtimeConfig);
  }

  static Future<void> dispose() async {
    final dependencies = _dependencies;
    if (dependencies == null) {
      return;
    }

    await dependencies.dispose();
    _dependencies = null;
  }

  static AppDependencies get dependencies {
    final dependencies = _dependencies;
    if (dependencies == null) {
      throw StateError(
        'Locator is not initialized. Call Locator.initialize first.',
      );
    }
    return dependencies;
  }

  static FeedRepository get feedRepository => dependencies.feedRepository;

  static UserRepository get userRepository => dependencies.userRepository;

  static ActivityApiRepository get activityApiRepository =>
      dependencies.activityApiRepository;

  static AuthRepository get authRepository => dependencies.authRepository;
}
