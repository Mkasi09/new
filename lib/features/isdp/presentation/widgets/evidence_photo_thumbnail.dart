import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';

import '../../../../app/theme/app_theme.dart';

class EvidencePhotoThumbnail extends StatelessWidget {
  const EvidencePhotoThumbnail({
    super.key,
    required this.photoData,
    required this.complete,
    this.size = 56,
  });

  final String? photoData;
  final bool complete;
  final double size;

  @override
  Widget build(BuildContext context) {
    final color = complete ? AppTheme.success : AppTheme.warning;
    final bytes = _tryDecodePhoto(photoData);

    return Container(
      width: size,
      height: size,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.18)),
      ),
      child: bytes == null
          ? Icon(
              complete
                  ? Icons.check_circle_outline
                  : Icons.image_not_supported_outlined,
              color: color,
            )
          : Image.memory(bytes, fit: BoxFit.cover),
    );
  }
}

class EvidencePhotoViewer extends StatelessWidget {
  const EvidencePhotoViewer({
    super.key,
    required this.photoData,
    required this.complete,
    required this.title,
    this.size = 92,
  });

  final String? photoData;
  final bool complete;
  final String title;
  final double size;

  @override
  Widget build(BuildContext context) {
    final bytes = _tryDecodePhoto(photoData);
    final thumbnail = EvidencePhotoThumbnail(
      photoData: photoData,
      complete: complete,
      size: size,
    );

    if (bytes == null) return thumbnail;

    return InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: () => _openFullScreen(context, bytes),
      child: Stack(
        children: [
          thumbnail,
          Positioned(
            right: 6,
            bottom: 6,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.58),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Icon(
                Icons.fullscreen,
                color: Colors.white,
                size: 18,
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _openFullScreen(BuildContext context, Uint8List bytes) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        fullscreenDialog: true,
        builder: (context) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            foregroundColor: Colors.white,
            title: Text(title),
          ),
          body: SafeArea(
            child: Center(
              child: InteractiveViewer(
                minScale: 0.8,
                maxScale: 5,
                child: Image.memory(bytes, fit: BoxFit.contain),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Uint8List? _tryDecodePhoto(String? photoData) {
  if (photoData == null || photoData.isEmpty) return null;

  try {
    final commaIndex = photoData.indexOf(',');
    final encoded = commaIndex == -1
        ? photoData
        : photoData.substring(commaIndex + 1);
    return base64Decode(encoded);
  } catch (_) {
    return null;
  }
}
