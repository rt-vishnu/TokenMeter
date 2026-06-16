import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:url_launcher/url_launcher.dart';

/// Full-screen camera scanner for the pairing QR. Pops with the decoded
/// string (the pairing URL) when a barcode is detected, or null if cancelled.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  final MobileScannerController _controller = MobileScannerController(
    facing: kIsWeb ? CameraFacing.front : CameraFacing.back,
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled) return;
    String? raw;
    for (final barcode in capture.barcodes) {
      final value = barcode.rawValue;
      if (value != null && value.isNotEmpty) {
        raw = value;
        break;
      }
    }
    if (raw == null) return;
    _handled = true;
    Navigator.of(context).pop(raw);
  }

  Widget _buildError(
      BuildContext context, MobileScannerException error, Widget? child) {
    final bool permissionDenied =
        error.errorCode == MobileScannerErrorCode.permissionDenied;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              permissionDenied ? Icons.no_photography : Icons.camera_alt,
              size: 64,
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
            const SizedBox(height: 16),
            Text(
              permissionDenied
                  ? 'Camera permission denied'
                  : 'Camera unavailable',
              style: Theme.of(context).textTheme.titleMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              permissionDenied
                  ? 'Grant camera access in Settings so the app can scan the QR code.'
                  : 'Could not open the camera. Please try again.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            if (permissionDenied)
              FilledButton.icon(
                onPressed: () => launchUrl(Uri.parse('app-settings:')),
                icon: const Icon(Icons.settings),
                label: const Text('Open app settings'),
              )
            else
              FilledButton.icon(
                onPressed: () async {
                  await _controller.stop();
                  await _controller.start();
                },
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan pairing QR'),
        actions: [
          IconButton(
            icon: const Icon(Icons.cameraswitch),
            tooltip: 'Switch camera',
            onPressed: () => _controller.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
            errorBuilder: _buildError,
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: Container(
              width: double.infinity,
              color: Colors.black54,
              padding: const EdgeInsets.all(16),
              child: const Text(
                'Point at the QR on the device running the API server '
                '(Connect screen). Wrong camera? Tap the switch icon above.',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
