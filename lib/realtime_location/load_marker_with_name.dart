import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
// import 'package:permission_handler/permission_handler.dart'; // // 사용하지 않으면 제거해도 됨
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

class RealTimeMapController extends StatefulWidget {
  final Set<Marker> initialMarkers;
  final void Function(GoogleMapController)? onMapCreated;
  final void Function(LatLng)? onTap;

  const RealTimeMapController({
    super.key,
    required this.initialMarkers,
    this.onMapCreated,
    this.onTap,
  });

  @override
  State<RealTimeMapController> createState() => _RealTimeMapControllerState();
}

class _RealTimeMapControllerState extends State<RealTimeMapController> {
  final Completer<GoogleMapController> _controller = Completer();
  late final DatabaseReference _locationRef;
  StreamSubscription<DatabaseEvent>? _locationSub;

  Set<Marker> _realtimeMarkers = {};
  Set<String> _allowedEmails = {};

  // 이메일 -> 프로필URL 캐시
  final Map<String, String?> _profileUrlCache = {};
  // 이메일 -> BitmapDescriptor(커스텀 원형 마커) 캐시
  final Map<String, BitmapDescriptor> _markerCache = {};
  // 기본 아바타 마커 캐시
  BitmapDescriptor? _defaultAvatarMarker;

  @override
  void initState() {
    super.initState();
    _locationRef = FirebaseDatabase.instance.ref("real_location");
    _initAndSubscribe();
  }

  Future<void> _initAndSubscribe() async {
    final user = FirebaseAuth.instance.currentUser;
    final myEmail = user?.email;
    if (myEmail == null || myEmail.isEmpty) return;

    try {
      // // 나를 counter_email 배열에 가지고 있는 상대만 표시
      final q = await FirebaseFirestore.instance
          .collection('users')
          .where('counter_email', arrayContains: myEmail)
          .get();

      _allowedEmails = q.docs.map((d) => d.id.toLowerCase()).toSet();
      _allowedEmails.remove(myEmail.toLowerCase());

      // // 상대 프로필 URL 미리 캐시
      await _primeProfileUrls(_allowedEmails);

      await _locationSub?.cancel();
      _locationSub = _locationRef.onValue.listen(_onLocationEvent);
    } catch (e) {
      debugPrint('Failed to load allowed emails: $e');
      setState(() {
        _allowedEmails = {};
        _realtimeMarkers = {};
      });
    }
  }

  Future<void> _primeProfileUrls(Set<String> emails) async {
    if (emails.isEmpty) return;
    for (final email in emails) {
      if (_profileUrlCache.containsKey(email)) continue; // // 이미 있음
      try {
        final doc =
        await FirebaseFirestore.instance.collection('users').doc(email).get();
        final data = doc.data();
        _profileUrlCache[email] =
        (data != null && data['profileImageUrl'] is String)
            ? (data['profileImageUrl'] as String)
            : null;
      } catch (_) {
        _profileUrlCache[email] = null;
      }
    }
  }

  // // 기본 아바타(사진 없음용) 생성
  Future<BitmapDescriptor> _defaultAvatar({int size = 112}) async {
    if (_defaultAvatarMarker != null) return _defaultAvatarMarker!;
    final marker = await _buildCircularAvatar(
      size: size,
      borderColor: Colors.blueAccent,
      imageBytes: null, // // 내부에서 기본 실루엣 그리기
    );
    _defaultAvatarMarker = marker;
    return marker;
  }

  // // 프로필 URL 기반 원형 마커 생성(파란 테두리)
  Future<BitmapDescriptor> _markerFromProfile(String email, {int size = 112}) async {
    if (_markerCache.containsKey(email)) return _markerCache[email]!;

    String? url = _profileUrlCache[email];
    if (url == null && !_profileUrlCache.containsKey(email)) {
      try {
        final doc =
        await FirebaseFirestore.instance.collection('users').doc(email).get();
        final data = doc.data();
        url = (data != null && data['profileImageUrl'] is String)
            ? (data['profileImageUrl'] as String)
            : null;
        _profileUrlCache[email] = url;
      } catch (_) {
        _profileUrlCache[email] = null;
      }
    }

    // // URL 없으면 기본 아바타
    if (url == null || url.isEmpty) {
      final fallback = await _defaultAvatar(size: size);
      _markerCache[email] = fallback;
      return fallback;
    }

    try {
      final resp = await http.get(Uri.parse(url));
      if (resp.statusCode != 200) {
        final fallback = await _defaultAvatar(size: size);
        _markerCache[email] = fallback;
        return fallback;
      }
      final bytes = resp.bodyBytes;

      final bitmap = await _buildCircularAvatar(
        size: size,
        borderColor: Colors.blueAccent, // // 파란 테두리
        imageBytes: bytes,
      );
      _markerCache[email] = bitmap;
      return bitmap;
    } catch (e) {
      debugPrint('profile marker build failed: $e');
      final fallback = await _defaultAvatar(size: size);
      _markerCache[email] = fallback;
      return fallback;
    }
  }

  // // 원형 아바타 그리기: 파란 테두리 + 이미지(없으면 기본 실루엣)
  Future<BitmapDescriptor> _buildCircularAvatar({
    required int size,
    required Color borderColor,
    Uint8List? imageBytes,
  }) async {
    final borderWidth = (size * 0.06).clamp(4.0, 8.0); // // 4~8px 사이
    final radius = size / 2.0;

    // // 이미지 디코딩(있다면)
    ui.Image? image;
    if (imageBytes != null) {
      final codec = await ui.instantiateImageCodec(
        imageBytes,
        targetWidth: size,
        targetHeight: size,
      );
      final fi = await codec.getNextFrame();
      image = fi.image;
    }

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    final center = Offset(radius, radius);
    final fullRect = Rect.fromCircle(center: center, radius: radius);

    // // 안쪽 원 반지름(테두리 안쪽)
    final innerRadius = radius - borderWidth / 2;

    // // 배경 투명
    final bg = Paint()..color = Colors.transparent;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()), bg);

    // // 테두리(파랑)
    final borderPaint = Paint()
      ..color = borderColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = borderWidth
      ..isAntiAlias = true;
    canvas.drawCircle(center, innerRadius, borderPaint);

    // // 이미지/실루엣 영역 클리핑
    final contentRect = fullRect.deflate(borderWidth);
    final clipPath = Path()..addOval(contentRect);
    canvas.clipPath(clipPath);

    if (image != null) {
      // // 이미지 그리기
      final paint = Paint()
        ..isAntiAlias = true
        ..shader = ImageShader(
          image,
          TileMode.clamp,
          TileMode.clamp,
          Matrix4.identity().storage,
        );
      canvas.drawRect(contentRect, paint);
    } else {
      // // 기본 실루엣 그리기
      final bgPaint = Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFFE6E9EF); // // 밝은 회색 배경
      canvas.drawRect(contentRect, bgPaint);

      final iconPaint = Paint()
        ..isAntiAlias = true
        ..color = const Color(0xFF6B7280); // // 짙은 회색 실루엣

      final w = contentRect.width;
      final h = contentRect.height;
      final cx = contentRect.center.dx;
      final cy = contentRect.center.dy;

      // // 머리(원)
      final headR = w * 0.20;
      final headCenter = Offset(cx, cy - h * 0.15);
      canvas.drawCircle(headCenter, headR, iconPaint);

      // // 어깨/몸통(라운드 사각)
      final bodyWidth = w * 0.56;
      final bodyHeight = h * 0.38;
      final bodyRect = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(cx, cy + h * 0.12),
          width: bodyWidth,
          height: bodyHeight,
        ),
        Radius.circular(w * 0.18),
      );
      canvas.drawRRect(bodyRect, iconPaint);
    }

    final picture = recorder.endRecording();
    final uiImage = await picture.toImage(size, size);
    final pngBytes = await uiImage.toByteData(format: ui.ImageByteFormat.png);

    return BitmapDescriptor.fromBytes(Uint8List.view(pngBytes!.buffer));
  }

  void _onLocationEvent(DatabaseEvent event) async {
    final snap = event.snapshot;
    if (!snap.exists || snap.value is! Map) {
      if (mounted) setState(() => _realtimeMarkers = {});
      return;
    }

    final map = Map<String, dynamic>.from(snap.value as Map);
    final next = <Marker>{};

    final futures = <Future<Marker?>>[];

    for (final entry in map.entries) {
      final v = entry.value;
      if (v is! Map) continue;

      final userData = Map<String, dynamic>.from(v);
      final email = (userData['email'] as String?)?.toLowerCase();
      final lat = (userData['latitude'] as num?)?.toDouble();
      final lng = (userData['longitude'] as num?)?.toDouble();
      final name = (userData['name'] as String?) ?? '이름 없음';

      if (email == null || !_allowedEmails.contains(email)) continue;
      if (lat == null || lng == null) continue;

      futures.add(() async {
        final icon = await _markerFromProfile(email, size: 112);
        return Marker(
          markerId: MarkerId('rt_$email'),
          position: LatLng(lat, lng),
          icon: icon,
          // // 이메일은 표시하지 않음(이름만)
          infoWindow: InfoWindow(title: name),
          anchor: const Offset(0.5, 0.5), // // 중앙 정렬
        );
      }());
    }

    final built = await Future.wait(futures);
    for (final m in built) {
      if (m != null) next.add(m);
    }

    if (mounted) {
      setState(() => _realtimeMarkers = next);
    }
  }

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final combined = <Marker>{...widget.initialMarkers, ..._realtimeMarkers};
    return GoogleMap(
      initialCameraPosition: const CameraPosition(
        target: LatLng(35.8880, 128.6106),
        zoom: 16,
      ),
      markers: combined,
      onMapCreated: (controller) {
        _controller.complete(controller);
        widget.onMapCreated?.call(controller);
      },
      onTap: widget.onTap,
      myLocationEnabled: true,
      myLocationButtonEnabled: true,
    );
  }
}
