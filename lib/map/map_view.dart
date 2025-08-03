import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:wheeltrip/data/const_data.dart'; // user_email 사용
import 'package:wheeltrip/map/map_load.dart'; // loadMarkersFromFirestore 함수
import 'package:wheeltrip/map/map_fetch.dart'; // PlaceFetcher 클래스
import 'package:wheeltrip/map/feedback_view.dart'; // 저장된 피드백 보기

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  late PlaceFetcher _placeFetcher;

  List<String> _userSavedPlaceIds = []; // ★ 로그인 사용자의 저장된 장소 목록

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.8880, 128.6106),
    zoom: 16.0,
  );

  final String _apiKey =
      'AIzaSyDWq1JmQHucXOFIbETBIaWh1wb3jis5ds8'; // Google Maps API Key

  @override
  void initState() {
    super.initState();
    _loadUserSavedPlaces().then((_) {
      _requestLocationPermission();
      _loadMarkersFromFirestore();
    });
  }

  /// Firestore에서 로그인된 사용자의 saved_places 불러오기
  Future<void> _loadUserSavedPlaces() async {
    try {
      final snapshot =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user_email) // const_data.dart의 로그인 사용자 email
              .collection('saved_places')
              .get();

      setState(() {
        _userSavedPlaceIds = snapshot.docs.map((doc) => doc.id).toList();
      });
    } catch (e) {
      debugPrint("저장된 장소 불러오기 실패: $e");
    }
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();

    _placeFetcher = PlaceFetcher(
      context: context,
      apiKey: _apiKey,
      userSavedPlaceIds: _userSavedPlaceIds, // ★ 저장된 장소 목록 전달
      showBottomSheet: ({
        required String name,
        required String address,
        required LatLng latLng,
        required String phone,
        required String openingHours,
        required String placeId,
      }) {
        showFeedbackViewSheet(
          context: context,
          placeId: placeId,
          name: name,
          address: address,
          latLng: latLng,
          phone: phone,
          openingHours: openingHours,
        );
      },
    );

    if (!status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다.')));
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    try {
      final markers = await loadMarkersFromFirestore(
        (LatLng tapped) { /// 마커 클릭
          _placeFetcher.fetchNearbyPlaces(tapped);
        },
      );
      setState(() {
        _markers = markers;
      });
    } catch (e) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('지도 마커 불러오기 실패: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        mapType: MapType.normal,
        initialCameraPosition: _initialPosition,
        myLocationEnabled: true,
        myLocationButtonEnabled: true,
        markers: _markers,
        onMapCreated: (controller) => _controller.complete(controller),
        onTap: (LatLng tapped) {
          _placeFetcher.fetchNearbyPlaces(tapped);
        },
      ),
    );
  }
}
