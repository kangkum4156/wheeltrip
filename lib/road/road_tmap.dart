import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

class TmapService {
  static const String appKey = 'kRtZ5HWLsk3y15lSSc1M319ME4uYZBFq3TABTvg2';

  /// Tmap 도보 경로 호출
  static Future<List<LatLng>> getWalkingRoute(LatLng start, LatLng end) async {
    final url = Uri.parse('https://apis.openapi.sk.com/tmap/routes/pedestrian?version=1');
    final headers = {
      'Content-Type': 'application/json',
      'appKey': appKey,
    };

    final body = json.encode({
      'startX': start.longitude.toString(),
      'startY': start.latitude.toString(),
      'endX': end.longitude.toString(),
      'endY': end.latitude.toString(),
      'reqCoordType': 'WGS84GEO',
      'resCoordType': 'WGS84GEO',
      'startName': '출발지',
      'endName': '도착지',
    });

    final response = await http.post(url, headers: headers, body: body);

    if (response.statusCode == 200) {
      final data = json.decode(response.body);
      final features = data['features'] as List;

      List<LatLng> coords = [];

      for (var feature in features) {
        final geometry = feature['geometry'];
        if (geometry['type'] == 'LineString') {
          final coordsList = geometry['coordinates'] as List;
          for (var point in coordsList) {
            coords.add(LatLng(point[1], point[0]));
          }
        }
      }
      return coords;
    } else {
      print('Tmap error: ${response.body}');
      return [];
    }
  }
}
