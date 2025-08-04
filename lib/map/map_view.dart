import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wheeltrip/data/const_data.dart'; // user_email 사용
import 'package:wheeltrip/map/map_load.dart'; // loadMarkersFromFirestore 함수
import 'package:wheeltrip/map/map_fetch.dart'; // PlaceFetcher 클래스
import 'package:wheeltrip/feedback/feedback_view.dart'; // 저장된 피드백 보기

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  late PlaceFetcher _placeFetcher;
  final List<Map<String, dynamic>> _userSavedPlaceIds = user_savedPlaces; // ★ 로그인 사용자의 저장된 장소 목록

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.8880, 128.6106),
    zoom: 16.0,
  );

  final String _apiKey =
      'AIzaSyDWq1JmQHucXOFIbETBIaWh1wb3jis5ds8'; // Google Maps API Key

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadMarkers();
  }

  Future<void> _requestLocationPermission() async{
    var status = await Permission.location.request();

    _placeFetcher = PlaceFetcher(
      context: context,
      apiKey: _apiKey,
      userSavedPlaces: _userSavedPlaceIds, // ★ 저장된 장소 목록 전달
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
          googlePlaceId: placeId,
          name: name,
          address: address,
          latLng: latLng,
          phone: phone,
          openingHours: openingHours,
          onMarkerReset: _loadMarkers,
        );
      },
    );

    if (!status.isGranted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('위치 권한이 필요합니다.')));
    }
  }

  Future<void> _loadMarkers() async {
    try {
      final markers = await loadMarkersFromGlobalVariable(
        user_savedPlaces,
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