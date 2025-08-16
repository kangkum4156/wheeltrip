// lib/profile/profile_marker.dart
import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class ProfileMarkerCache {
  ProfileMarkerCache({
    this.defaultAssetPath = 'asset/img/default_profile.png',
    this.borderColor = const Color(0xFF1976D2), // 파란 테두리
    this.borderWidth = 6.0,
    this.defaultSize = 96,
  });

  final String defaultAssetPath;
  final Color borderColor;
  final double borderWidth;
  final int defaultSize;

  final _Semaphore _semaphore = _Semaphore(3);

  final Map<String, String?> _profileUrlCache = {};
  final Map<String, BitmapDescriptor> _markerCache = {};
  Uint8List? _defaultAssetBytes;

  Future<void> warmProfileUrls(Set<String> emails) async {
    for (final e in emails) {
      final email = e.toLowerCase();
      if (_profileUrlCache.containsKey(email)) continue;
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(email)
            .get();
        final data = doc.data();
        _profileUrlCache[email] = (data != null &&
            data['profileImageUrl'] is String &&
            (data['profileImageUrl'] as String).trim().isNotEmpty)
            ? data['profileImageUrl'] as String
            : null;
      } catch (_) {
        _profileUrlCache[email] = null;
      }
    }
  }

  Future<BitmapDescriptor> markerFor(String email, {int? size}) async {
    final s = size ?? defaultSize;
    final emailKey = email.toLowerCase();
    final cacheKey =
        '$emailKey@$s@${borderColor.value}@${borderWidth.toStringAsFixed(2)}';

    final hit = _markerCache[cacheKey];
    if (hit != null) return hit;

    String? url = _profileUrlCache[emailKey];
    if (url == null && !_profileUrlCache.containsKey(emailKey)) {
      try {
        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(emailKey)
            .get();
        final data = doc.data();
        url = (data != null && data['profileImageUrl'] is String)
            ? (data['profileImageUrl'] as String)
            : null;
        _profileUrlCache[emailKey] = url;
      } catch (_) {
        _profileUrlCache[emailKey] = null;
      }
    }

    return _semaphore.withPermit(() async {
      Uint8List? imgBytes = await _downloadBytes(url);
      final isDefault = (imgBytes == null); // 기본 이미지 여부
      imgBytes ??= await _loadDefaultAssetBytes();

      final bmp = await _buildCircularAvatarBytes(
        size: s,
        borderColor: borderColor,
        borderWidth: isDefault ? 0.0 : borderWidth, // 기본 이미지면 테두리 없음
        imageBytes: imgBytes,
      );

      final bd = (bmp != null && bmp.isNotEmpty)
          ? BitmapDescriptor.fromBytes(bmp)
          : BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueAzure);

      _markerCache[cacheKey] = bd;
      return bd;
    });
  }

  Future<Uint8List?> _downloadBytes(String? url) async {
    if (url == null || url.isEmpty) return null;
    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode == 200 && resp.bodyBytes.isNotEmpty) {
        return resp.bodyBytes;
      }
    } catch (_) {}
    return null;
  }

  Future<Uint8List> _loadDefaultAssetBytes() async {
    if (_defaultAssetBytes != null) return _defaultAssetBytes!;
    try {
      final bd = await rootBundle.load(defaultAssetPath);
      _defaultAssetBytes = bd.buffer.asUint8List();
      return _defaultAssetBytes!;
    } catch (_) {
      return Uint8List(0);
    }
  }

  Future<Uint8List?> _buildCircularAvatarBytes({
    required int size,
    required Color borderColor,
    required double borderWidth,
    required Uint8List imageBytes,
  }) async {
    try {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: size,
        targetHeight: size,
      );
      final fi = await codec.getNextFrame();
      final ui.Image image = fi.image;

      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final center = Offset(size / 2, size / 2);
      final radius = size / 2.0;

      canvas.drawRect(
        Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
        Paint()..color = Colors.transparent,
      );

      // 테두리: 기본 이미지일 때는 borderWidth=0이라 자동 skip
      if (borderWidth > 0) {
        final borderPaint = Paint()
          ..isAntiAlias = true
          ..style = PaintingStyle.stroke
          ..strokeWidth = borderWidth
          ..color = borderColor;
        final innerR = radius - borderWidth / 2;
        canvas.drawCircle(center, innerR, borderPaint);
      }

      final innerR = radius - (borderWidth > 0 ? borderWidth / 2 : 0);
      final contentRect = Rect.fromCircle(center: center, radius: innerR - 0.01);
      final clipPath = Path()..addOval(contentRect);
      canvas.clipPath(clipPath);

      final srcRect =
      Rect.fromLTWH(0, 0, image.width.toDouble(), image.height.toDouble());
      final dstRect = contentRect;
      final paint = Paint()
        ..isAntiAlias = true
        ..filterQuality = FilterQuality.high;
      canvas.drawImageRect(image, srcRect, dstRect, paint);

      final picture = recorder.endRecording();
      final uiImage = await picture.toImage(size, size);
      final byteData = await uiImage.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) return null;
      return byteData.buffer.asUint8List();
    } catch (_) {
      return null;
    }
  }
}

class _Semaphore {
  int _permits;
  final List<Completer<void>> _waiters = [];
  _Semaphore(this._permits);

  Future<T> withPermit<T>(Future<T> Function() action) async {
    if (_permits > 0) {
      _permits--;
    } else {
      final c = Completer<void>();
      _waiters.add(c);
      await c.future;
    }
    try {
      return await action();
    } finally {
      if (_waiters.isNotEmpty) {
        _waiters.removeAt(0).complete();
      } else {
        _permits++;
      }
    }
  }
}
