import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:wheeltrip/map/map_load.dart';        // loadMarkersFromFirestore 함수
import 'package:wheeltrip/map/map_fetch.dart';       // PlaceFetcher 클래스
import 'package:wheeltrip/map/map_bottom_sheet.dart'; // showPlaceBottomSheet 함수

class MapView extends StatefulWidget {
  const MapView({super.key});

  @override
  State<MapView> createState() => _MapViewState();
}

class _MapViewState extends State<MapView> {
  final Completer<GoogleMapController> _controller = Completer();
  Set<Marker> _markers = {};
  late final PlaceFetcher _placeFetcher;

  static const CameraPosition _initialPosition = CameraPosition(
    target: LatLng(35.8880, 128.6106),
    zoom: 15.0,
  );

  final String _apiKey = 'AIzaSyDWq1JmQHucXOFIbETBIaWh1wb3jis5ds8';

  @override
  void initState() {
    super.initState();
    _requestLocationPermission();
    _loadMarkersFromFirestore();
  }

  Future<void> _requestLocationPermission() async {
    var status = await Permission.location.request();

    _placeFetcher = PlaceFetcher(
      context: context,
      apiKey: _apiKey,
      showBottomSheet: ({
        required String name,
        required String address,
        required LatLng latLng,
        required String phone,
        required String openingHours,
      }) {
        showPlaceBottomSheet(
          context: context,
          name: name,
          address: address,
          latLng: latLng,
          phone: phone,
          openingHours: openingHours,
          onSaveComplete: () async {
            await _loadMarkersFromFirestore();
          }
        );
      }, // map_bottom_sheet.dart 함수
    );

    if (!status.isGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('위치 권한이 필요합니다.')),
      );
    }
  }

  Future<void> _loadMarkersFromFirestore() async {
    try {
      final markers = await loadMarkersFromFirestore((data) {
        // Firestore 마커 클릭 시 보여줄 BottomSheet 콜백
        showPlaceBottomSheetForMarker(
          context: context,
          name: data['name'] ?? '이름 없음',
          address: data['address'] ?? '',
          latLng: LatLng(data['latitude'].toDouble(), data['longitude'].toDouble()),
          phone: data['phone'] ?? '',
          openingHours: data['time'] ?? '',
          info: data['info'] ?? '',
          rate: data['rate'] ?? 0,
        );
      });

      setState(() {
        _markers = markers;
      });
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('지도 마커 불러오기 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("휠체어 맵")),
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
