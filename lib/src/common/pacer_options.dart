/// Base configuration options for all pacers.
///
/// Provides common configuration that all pacers inherit. Specific pacers
/// extend this class to add their own configuration options.
///
/// Example:
/// ```dart
/// class MyPacerOptions extends PacerOptions {
///   MyPacerOptions({
///     super.enabled = true,
///     super.key,
///     this.customSetting = 42,
///   });
///
///   final int customSetting;
/// }
/// ```
abstract class PacerOptions {
  /// Creates base configuration for a pacer.
  ///
  /// [enabled] controls whether the pacer is active.
  /// [key] can be used to identify or group related pacers.
  const PacerOptions({this.enabled = true, this.key});

  /// Whether this pacer is enabled and should process operations.
  ///
  /// When disabled, pacers will ignore execution requests and
  /// typically return default values or throw exceptions.
  final bool enabled;

  /// Optional identifier for this pacer instance.
  ///
  /// Can be used for logging, debugging, or managing multiple
  /// related pacers. Not used internally by the pacers themselves.
  final String? key;
}
