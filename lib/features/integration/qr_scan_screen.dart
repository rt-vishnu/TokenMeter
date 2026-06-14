import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

/// Full-screen camera scanner for the pairing QR. Pops with the decoded
/// string (the pairing URL) when a barcode is detected, or null if cancelled.
class QrScanScreen extends StatefulWidget {
  const QrScanScreen({super.key});

  @override
  State<QrScanScreen> createState() => _QrScanScreenState();
}

class _QrScanScreenState extends State<QrScanScreen> {
  // On a laptop/web the usable camera is the front-facing webcam; on a phone
  // the back camera is what you point at another device's QR.
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
          MobileScanner(controller: _controller, onDetect: _onDetect),
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
