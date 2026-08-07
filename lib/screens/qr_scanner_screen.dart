import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

import '../models/person.dart';
import '../services/remote_people_service.dart';
import '../utils/person_link.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handling = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    FirebaseAnalytics.instance.logEvent(name: 'qr_scan_started');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _onDetect(BarcodeCapture capture) async {
    if (_handling) return;
    final raw = capture.barcodes.firstOrNull?.rawValue;
    if (raw == null) return;
    _handling = true;
    await _controller.stop();

    try {
      Person? person;
      final publicId = tryParsePublicIdFromRaw(raw);
      if (publicId != null) {
        person = await RemotePeopleService.findPublicPersonByPublicId(
          publicId,
        ).timeout(const Duration(seconds: 12));
      }
      person ??= tryParsePersonFromRaw(raw);
      if (person == null) throw const FormatException();
      await FirebaseAnalytics.instance.logEvent(name: 'qr_scan_success');
      if (mounted) Navigator.pop(context, person);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _error = 'QR-код не содержит профиль «Настрой»';
        _handling = false;
      });
      await _controller.start();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: CupertinoNavigationBar(
        backgroundColor: Colors.black.withValues(alpha: 0.72),
        middle: const Text(
          'Сканировать QR',
          style: TextStyle(color: Colors.white),
        ),
        leading: CupertinoButton(
          padding: EdgeInsets.zero,
          onPressed: () => Navigator.pop(context),
          child: const Icon(CupertinoIcons.xmark, color: Colors.white),
        ),
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(controller: _controller, onDetect: _onDetect),
          Center(
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.white, width: 3),
                borderRadius: BorderRadius.circular(28),
              ),
            ),
          ),
          Positioned(
            left: 24,
            right: 24,
            bottom: 48,
            child: Text(
              _error ?? 'Наведи камеру на QR-код профиля',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: _error == null ? Colors.white : Colors.redAccent,
                fontSize: 16,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
