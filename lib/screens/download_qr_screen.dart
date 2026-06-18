import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../core/env.dart';

class DownloadQrScreen extends StatelessWidget {
  const DownloadQrScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Descargar la app')),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(40),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                'Escaneá este QR',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: cs.onSurface),
              ),
              const SizedBox(height: 8),
              Text(
                'para descargar la app',
                style: TextStyle(fontSize: 16, color: cs.onSurfaceVariant),
              ),
              const SizedBox(height: 40),
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(24),
                  boxShadow: [BoxShadow(color: cs.shadow.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8))],
                ),
                child: QrImageView(
                  data: Env.downloadUrl,
                  size: 260,
                  backgroundColor: Colors.white,
                ),
              ),
              const SizedBox(height: 32),
              Text(
                Env.downloadUrl,
                style: TextStyle(fontSize: 11, color: cs.onSurfaceVariant),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
