import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class SavePlace extends StatelessWidget {
  final double latitude;
  final double longitude;
  final String info;
  final int rate;
  final String name;
  final String phone;
  final String time;
  final String address;
  final Function(Marker) onSaveComplete;

  const SavePlace({
    Key? key,
    required this.latitude,
    required this.longitude,
    required this.info,
    required this.rate,
    required this.name,
    required this.phone,
    required this.time,
    required this.address,
    required this.onSaveComplete,
  }) : super(key: key);

  Future<void> savePlace(BuildContext context) async {
    try {
      final docRef = await FirebaseFirestore.instance.collection('places').add({
        'latitude': latitude,
        'longitude': longitude,
        'info': info,
        'rate': rate,
        'name': name,
        'phone': phone,
        'time': time,
        'address': address,
      });

      final marker = Marker(
        markerId: MarkerId(docRef.id),
        position: LatLng(latitude, longitude),
        infoWindow: InfoWindow(
          title: name,
          snippet: '$info\n감정: ${rate + 1}/5\n전화번호: $phone',
        ),
      );

      onSaveComplete(marker);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('장소가 저장되었습니다.')),
      );
      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('저장 실패: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return ElevatedButton.icon(
      icon: const Icon(Icons.bookmark_add),
      label: const Text('지도에 저장'),
      onPressed: () => savePlace(context),
    );
  }
}
