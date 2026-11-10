// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:async';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../link_code.dart';

/// Camera scan of a parent-link QR. Typing the code stays available when the
/// camera is missing or the picture is not a code. `camera` and `zxing2` are
/// BSD-licensed. This screen does not use a paid scanner.
class LinkScanPage extends StatefulWidget {
  const LinkScanPage({super.key, this.useCamera = true, this.debugPixels});

  final bool useCamera;

  /// When set, the page decodes this picture instead of opening a camera.
  final ({int width, int height, Int32List argb})? debugPixels;

  @override
  State<LinkScanPage> createState() => _LinkScanPageState();
}

class _LinkScanPageState extends State<LinkScanPage> {
  CameraController? _camera;
  var _busy = false;
  String? _problem;

  @override
  void initState() {
    super.initState();
    final pixels = widget.debugPixels;
    if (pixels != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        final text = decodeQrPixels(width: pixels.width, height: pixels.height, argb: pixels.argb);
        Navigator.pop(context, text);
      });
      return;
    }
    if (widget.useCamera) unawaited(_openCamera());
  }

  Future<void> _openCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        if (mounted) setState(() => _problem = 'Keine Kamera. Der Code kann abgetippt werden.');
        return;
      }
      final controller = CameraController(cameras.first, ResolutionPreset.medium, enableAudio: false);
      await controller.initialize();
      await controller.startImageStream(_onFrame);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() => _camera = controller);
    } catch (_) {
      if (mounted) setState(() => _problem = 'Die Kamera lässt sich nicht öffnen. Der Code kann abgetippt werden.');
    }
  }

  Future<void> _onFrame(CameraImage image) async {
    if (_busy || !mounted) return;
    _busy = true;
    try {
      final plane = image.planes.first;
      final argb = yPlaneToArgb(
        plane.bytes,
        width: image.width,
        height: image.height,
        rowStride: plane.bytesPerRow,
      );
      final text = decodeQrPixels(width: image.width, height: image.height, argb: argb);
      if (text != null && mounted) Navigator.pop(context, text);
    } catch (_) {
      // The next frame can still be a code.
    } finally {
      _busy = false;
    }
  }

  @override
  void dispose() {
    final camera = _camera;
    _camera = null;
    unawaited(camera?.dispose() ?? Future<void>.value());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final camera = _camera;
    return Scaffold(
      appBar: AppBar(title: const Text('Code scannen')),
      body: Column(
        children: [
          Expanded(
            child: camera != null && camera.value.isInitialized
                ? CameraPreview(camera)
                : Center(child: Text(_problem ?? 'Kamera wird geöffnet.')),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Wenn die Kamera nichts erkennt, den Code abtippen. Der Scan beweist keine Sorgeberechtigung.'),
                const SizedBox(height: 8),
                OutlinedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Abtippen'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
