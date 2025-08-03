import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;

/// google place API와 통신하여 주변 장소 검색 및 상세정보 표시 관련 함수들
class PlaceFetcher {
  final BuildContext context;
  final String apiKey;
  final List<String> userSavedPlaceIds; // ★ 로그인 사용자 저장된 장소 목록
  final Function({
  required String name,
  required String address,
  required LatLng latLng,
  required String phone,
  required String openingHours,
  required String placeId,
  }) showBottomSheet;

  bool _isLoading = false;

  PlaceFetcher({
    required this.context,
    required this.apiKey,
    required this.userSavedPlaceIds,
    required this.showBottomSheet,
  });

  Future<void> fetchNearbyPlaces(LatLng latLng) async {
    if (_isLoading) return;
    _isLoading = true;

    try {
      final nearbyUrl = Uri.parse(
        'https://maps.googleapis.com/maps/api/place/nearbysearch/json'
            '?location=${latLng.latitude},${latLng.longitude}'
            '&radius=30' // 반경(m)
            '&key=$apiKey',
      );

      final response = await http.get(nearbyUrl);
      final data = jsonDecode(response.body);
      final results = data['results'];

      if (results != null && results.isNotEmpty) {
        _showNearbyList(results, latLng);
      } else {
        _showDialog('근처에 장소가 없습니다.');
      }
    } catch (e) {
      debugPrint('에러 발생: $e');
      _showDialog('오류가 발생했습니다.');
    } finally {
      _isLoading = false;
    }
  }

  Future<void> fetchDetailsAndShow(String placeId, LatLng latLng) async {
    final detailsUrl = Uri.parse(
      'https://maps.googleapis.com/maps/api/place/details/json'
          '?place_id=$placeId'
          '&fields=name,rating,formatted_phone_number,formatted_address,opening_hours'
          '&key=$apiKey',
    );

    final response = await http.get(detailsUrl);
    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      final result = data['result'];

      showBottomSheet(
        name: result['name'] ?? '이름 없음',
        address: result['formatted_address'] ?? '주소 없음',
        latLng: latLng,
        phone: result['formatted_phone_number'] ?? '전화번호 없음',
        openingHours: result['opening_hours']?['weekday_text']?.join('\n') ?? '운영 시간 정보 없음',
        placeId: placeId,
      );
    } else {
      debugPrint('상세정보 실패: ${response.statusCode}');
      _showDialog('세부 정보 불러오기 실패');
    }
  }

  void _showNearbyList(List<dynamic> places, LatLng latLng) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      enableDrag: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (_) => DraggableScrollableSheet( // UX용 Scroller
        expand: false,
        builder: (context, scrollController) {
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: ListView.builder(
              controller: scrollController,
              itemCount: places.length,
              itemBuilder: (context, index) {
                final place = places[index];
                final placeId = place['place_id'] ?? '';
                final name = place['name'] ?? '이름 없음';
                final address = place['vicinity'] ?? '주소 없음';

                final isSaved = userSavedPlaceIds.contains(placeId);

                return ListTile(
                  leading: isSaved
                      ? const Icon(Icons.star, color: Colors.amber)
                      : const Icon(Icons.place, color: Colors.grey),
                  title: Text(name),
                  subtitle: Text(address),
                  onTap: () {
                    Navigator.pop(context);
                    fetchDetailsAndShow(placeId, latLng);
                  }
                );
              },
            ),
          );
        },
      ),
    );
  }

  void _showDialog(String message) {
    showDialog(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('알림'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('확인'),
          )
        ],
      ),
    );
  }
}
