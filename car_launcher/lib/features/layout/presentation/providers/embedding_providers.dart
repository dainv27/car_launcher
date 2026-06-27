import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:car_launcher/features/launcher/data/launcher_service.dart';

/// Native embedding capability reported by the device.
class EmbeddingInfo {
  const EmbeddingInfo({
    required this.supported,
    required this.reason,
    required this.apiLevel,
  });

  final bool supported;
  final String reason;
  final int apiLevel;

  factory EmbeddingInfo.fromMap(Map<String, dynamic> map) {
    return EmbeddingInfo(
      supported: map['supported'] as bool? ?? false,
      reason: map['reason'] as String? ?? 'Unknown',
      apiLevel: map['apiLevel'] as int? ?? 0,
    );
  }
}

final embeddingInfoProvider = FutureProvider<EmbeddingInfo>((ref) async {
  final launcher = ref.watch(launcherServiceProvider);
  final info = await launcher.getEmbeddingInfo();
  return EmbeddingInfo.fromMap(info);
});
