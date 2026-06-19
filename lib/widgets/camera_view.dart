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
          return Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [Color(0xFF03060B), Color(0xFF0A1220), Color(0xFF05070C)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
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
                    stream.status.toUpperCase(),
                    style: const TextStyle(
                      color: Colors.white70,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        }

        return RepaintBoundary(
          child: Image(
            image: MemoryImage(frame),
            gaplessPlayback: true,
            fit: BoxFit.cover,
            filterQuality: FilterQuality.low,
            errorBuilder: (context, _, __) => const SizedBox.expand(),
          ),
        );
      },
    );
  }
}
