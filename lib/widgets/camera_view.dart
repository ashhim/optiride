import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../services/stream_service.dart';

class CameraView extends StatelessWidget {
  const CameraView({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<StreamService>(
      builder: (context, stream, _) {
        final frame = stream.frame;
        if (frame == null) {
          return _CameraPlaceholder(status: stream.status.toUpperCase());
        }

        return SizedBox.expand(
          child: RepaintBoundary(
            child: Image(
              image: MemoryImage(frame),
              gaplessPlayback: true,
              fit: BoxFit.cover,
              alignment: Alignment.center,
              filterQuality: FilterQuality.low,
              errorBuilder:
                  (context, _, __) => const _CameraPlaceholder(
                    status: 'STREAM ERROR',
                  ),
            ),
          ),
        );
      },
    );
  }
}

class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          colors: [Color(0xFF03060B), Color(0xFF0A1220), Color(0xFF05070C)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
      ),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
          decoration: BoxDecoration(
            color: const Color(0xB009111D),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: const Color(0x2236E6C5)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 48,
                height: 48,
                child: CircularProgressIndicator(strokeWidth: 2.2),
              ),
              const SizedBox(height: 14),
              Text(
                status,
                style: const TextStyle(
                  color: Colors.white70,
                  letterSpacing: 1.2,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
