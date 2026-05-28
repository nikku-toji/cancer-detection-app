import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:io';
import '../../data/models/detection_result.dart';
import '../../data/repositories/detection_repository.dart';

enum ScanState { idle, loading, success, error }

class ScanNotifier extends StateNotifier<ScanViewModel> {
  final DetectionRepository _repository;

  ScanNotifier(this._repository) : super(ScanViewModel.initial());

  Future<void> analyze({
    required String cancerType,
    required File imageFile,
  }) async {
    state = state.copyWith(scanState: ScanState.loading);

    try {
      final result = await _repository.analyze(
        cancerType: cancerType,
        imageFile: imageFile,
      );
      state = state.copyWith(
        scanState: ScanState.success,
        result: result,
      );
    } catch (e) {
      state = state.copyWith(
        scanState: ScanState.error,
        errorMessage: e.toString(),
      );
    }
  }

  void reset() => state = ScanViewModel.initial();
}

class ScanViewModel {
  final ScanState scanState;
  final DetectionResult? result;
  final String? errorMessage;

  const ScanViewModel({
    required this.scanState,
    this.result,
    this.errorMessage,
  });

  factory ScanViewModel.initial() =>
      const ScanViewModel(scanState: ScanState.idle);

  ScanViewModel copyWith({
    ScanState? scanState,
    DetectionResult? result,
    String? errorMessage,
  }) =>
      ScanViewModel(
        scanState: scanState ?? this.scanState,
        result: result ?? this.result,
        errorMessage: errorMessage ?? this.errorMessage,
      );
}

final scanProvider =
    StateNotifierProvider<ScanNotifier, ScanViewModel>((ref) {
  final repo = ref.read(detectionRepositoryProvider);
  return ScanNotifier(repo);
});
