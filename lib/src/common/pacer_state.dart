// 🌎 Project imports:
import 'package:gnrllybttr_pacer/src/common/enums.dart';

/// Base state information for all pacers.
///
/// Provides common state tracking that all pacers maintain. Specific pacers
/// extend this class to add their own state information.
///
/// This class extends [ChangeNotifier] to enable reactive Flutter UI updates
/// when pacer state changes.
///
/// Example:
/// ```dart
/// class MyPacerState extends PacerState {
///   MyPacerState({
///     super.executionCount = 0,
///     super.status = PacerStatus.idle,
///     this.customMetric = 0,
///   });
///
///   final int customMetric;
/// }
/// ```
abstract class PacerState {
  /// Creates base state for a pacer.
  ///
  /// [executionCount] tracks how many operations have been executed.
  /// [status] indicates the current operational state.
  const PacerState({this.executionCount = 0, this.status = PacerStatus.idle});

  /// Number of operations that have been successfully executed.
  ///
  /// This counter is incremented each time an operation completes
  /// successfully. Failed operations typically don't increment this.
  final int executionCount;

  /// Current operational status of the pacer.
  ///
  /// See [PacerStatus] for possible values and their meanings.
  final PacerStatus status;
}
