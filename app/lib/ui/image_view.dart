// SPDX-License-Identifier: AGPL-3.0-or-later
// Copyright 2026. Legal name of the copyright holder is not recorded in this repository.

import 'dart:typed_data';

import 'package:flutter/material.dart';

import 'media_io.dart';

class ImageViewerPage extends StatefulWidget {
  const ImageViewerPage({
    super.key,
    required this.bytes,
    required this.allowExport,
  });

  final Uint8List bytes;
  final bool allowExport;

  @override
  State<ImageViewerPage> createState() => _ImageViewerPageState();
}

class _ImageViewerPageState extends State<ImageViewerPage> {
  final _transform = TransformationController();
  Offset _doubleTapAt = Offset.zero;
  String? _notice;

  @override
  void dispose() {
    _transform.dispose();
    super.dispose();
  }

  void _toggleZoom() {
    if (_transform.value.getMaxScaleOnAxis() > 1.05) {
      _transform.value = Matrix4.identity();
      return;
    }
    const next = 2.5;
    final dx = -_doubleTapAt.dx * (next - 1);
    final dy = -_doubleTapAt.dy * (next - 1);
    _transform.value = Matrix4.identity()
      ..translateByDouble(dx, dy, 0, 1)
      ..scaleByDouble(next, next, 1, 1);
  }

  Future<void> _export(Future<void> Function() action) async {
    try {
      await action();
      if (mounted) setState(() => _notice = null);
    } catch (exc) {
      if (mounted) setState(() => _notice = '$exc');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Bild'),
        actions: [
          if (widget.allowExport) ...[
            IconButton(
              tooltip: 'Speichern',
              onPressed: () => _export(() => MediaIo.saveJpeg(widget.bytes)),
              icon: const Icon(Icons.download),
            ),
            IconButton(
              tooltip: 'Teilen',
              onPressed: () => _export(() => MediaIo.shareJpeg(widget.bytes)),
              icon: const Icon(Icons.share),
            ),
          ],
        ],
      ),
      body: Column(
        children: [
          if (!widget.allowExport)
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 8, 16, 0),
              child: Text(
                'Speichern und Teilen sind aus, solange der Sperrbildschirm Inhalte verbirgt.',
                style: TextStyle(color: Colors.white70),
              ),
            ),
          if (_notice != null)
            Padding(
              padding: const EdgeInsets.all(12),
              child: Text(_notice!, style: const TextStyle(color: Colors.white)),
            ),
          Expanded(
            child: GestureDetector(
              onDoubleTapDown: (details) => _doubleTapAt = details.localPosition,
              onDoubleTap: _toggleZoom,
              child: InteractiveViewer(
                transformationController: _transform,
                minScale: 1,
                maxScale: 4,
                child: Center(child: Image.memory(widget.bytes, fit: BoxFit.contain)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
