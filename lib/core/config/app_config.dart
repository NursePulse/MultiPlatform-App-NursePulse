/// Compile-time configuration for the NursePulse app.
///
/// Override the API base URL at build/run time with:
///   --dart-define=API_BASE_URL=http://10.0.2.2:8080/api/v1   (Android emulator -> local backend)
///   --dart-define=API_BASE_URL=http://localhost:8080/api/v1  (web / iOS sim / desktop -> local backend)
class AppConfig {
  AppConfig._();

  static const String appName = 'Care-Labs / NursePulse';

  static const String apiBaseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue:
        'https://backpulsereport-production-7576.up.railway.app/api/v1',
  );
}
