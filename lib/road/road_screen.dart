import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:wheeltrip/road/road_save_load.dart';
import 'package:wheeltrip/data/const_data.dart';
import 'package:wheeltrip/road/road_tmap.dart';
import 'package:wheeltrip/road/road_new.dart';
import 'package:wheeltrip/road/road_feedback_add.dart';
import 'package:wheeltrip/road/road_feedback_edit.dart';
import 'package:wheeltrip/road/road_feedback_delete.dart';

class RoadScreen extends StatefulWidget {
  const RoadScreen({super.key});

  @override
  RoadScreenState createState() => RoadScreenState();
}

class RoadScreenState extends State<RoadScreen> {
  GoogleMapController? _mapController;
  LatLng? startPoint;
  LatLng? endPoint;

  Set<Circle> circles = {};
  Set<Polyline> polylines = {};

  List<Map<String, dynamic>> loadedRoutes = [];

  @override
  void initState() {
    super.initState();
    _loadAndDisplayRoutes();
  }

  Future<void> _loadAndDisplayRoutes() async {
    loadedRoutes = await RoadFirestoreService.loadRoutes();

    Set<Polyline> loadedPolylines = {};

    for (var route in loadedRoutes) {
      loadedPolylines.add(
        Polyline(
          polylineId: PolylineId(route['id']),
          points: route['points'],
          width: 7,
          color: RoadFirestoreService.getPolylineColor(route['avgRate']),
          consumeTapEvents: true,
          onTap:
              () => _onPolylineTap(
                route['id'],
                route['points'],
                route['avgRate'],
              ),
        ),
      );
    }

    setState(() {
      polylines = loadedPolylines;
    });
  }

  Future<void> _onPolylineTap(
    String routeId,
    List<LatLng> coords,
    double avgRate,
  ) async {
    int myRate = await RoadFirestoreService.getUserRateForRoute(
      userEmail: user_email,
      routeId: routeId,
    );

    List<String>? myFeatures = await RoadFirestoreService.getUserFeatures(
      userEmail: user_email,
      routeId: routeId,
    );

    bool feedbackExists = await RoadFirestoreService.checkUserFeedbackExists(
      userEmail: user_email,
      routeId: routeId,
    );

    List<Map<String, dynamic>> allFeedbacks =
        await RoadFirestoreService.loadFeedbacks(routeId);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.7,
          minChildSize: 0.5,
          maxChildSize: 0.95,
          builder: (context, scrollController) {
            final screen = MediaQuery.of(context).size;
            final listHeight = screen.height * 0.35; // 피드백 리스트 고정 높이

            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom + 16,
                top: 16,
                left: 16,
                right: 16,
              ),
              child: ListView(
                controller: scrollController,
                children: [
                  /// 📌 평균 평점
                  Text("평균 평점: ${avgRate.toStringAsFixed(1)}"),

                  const SizedBox(height: 8),

                  /// 📌 평가 버튼 구간 — 직접 구현
                  if (feedbackExists) ...[
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        ElevatedButton(
                          child: const Text('수정하기'),
                          onPressed: () {
                            Navigator.pop(context);
                            showEditFeedbackBottomSheet(
                              context: context,
                              initialRate: myRate,
                              initialFeatures: myFeatures,
                              onFeedbackUpdated: (updatedRate, updatedFeatures) async {
                                await updateRoadFeedback(routeId, updatedRate, updatedFeatures);
                                _loadAndDisplayRoutes();
                              },
                            );
                          },
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton(
                          child: const Text('삭제하기'),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: Colors.red,
                          ),
                          onPressed: () async {
                            Navigator.pop(context);
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (context) => AlertDialog(
                                content: const Text('내 피드백을 삭제할까요?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, false),
                                    child: const Text('취소'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(context, true),
                                    child: const Text('삭제'),
                                  ),
                                ],
                              ),
                            );

                            if (confirmed == true) {
                              await deleteRoadFeedback(routeId);
                              _loadAndDisplayRoutes();
                            }
                          },
                        ),
                      ],
                    ),
                  ] else ...[
                    ElevatedButton(
                      child: const Text('경로 평가하기'),
                      onPressed: () {
                        Navigator.pop(context);
                        showAddRoadFeedbackBottomSheet(
                          routeId: routeId,
                          context: context,
                          onRouteSaved: (routeId, rate, features) async {
                            await addRoadFeedback(routeId, rate, features);
                            _loadAndDisplayRoutes();
                          },
                        );

                      },
                    ),
                  ],

                  const SizedBox(height: 10),
                  const Text(
                    '📋 등록된 피드백',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                  const SizedBox(height: 8),

                  /// 📌 피드백 리스트 고정 영역
                  SizedBox(
                    height: listHeight,
                    child: ListView.builder(
                      itemCount: allFeedbacks.length,
                      itemBuilder: (context, index) {
                        final fb = allFeedbacks[index];
                        return Card(
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          child: ListTile(
                            title: Text(
                              "${fb['userName']} (${fb['userEmail']})",
                            ),
                            subtitle: Text(
                              "별점: ${fb['rate']} - 특성: ${fb['features'].join(', ')}",
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  Future<void> _saveNewRoute(
    List<LatLng> coords,
    int rate,
    List<String> feature,
  ) async {
    final result = await RoadFirestoreService.saveNewRoute(
      userEmail: user_email,
      coords: coords,
      rate: rate,
      features: feature,
    );

    setState(() {
      polylines.add(
        Polyline(
          polylineId: PolylineId(result['id']),
          points: coords,
          width: 7,
          color: RoadFirestoreService.getPolylineColor(result['avgRate']),
          consumeTapEvents: true,
          onTap: () => _onPolylineTap(result['id'], coords, result['avgRate']),
        ),
      );

      startPoint = null;
      endPoint = null;
      circles.clear();
    });
  }

  Future<void> _getRouteAndSave() async {
    // onMapTap 후 새 경로 생성
    if (startPoint == null || endPoint == null) return;

    final coords = await TmapService.getWalkingRoute(startPoint!, endPoint!);
    if (coords.isEmpty) return;

    final tempPolyline = Polyline(
      polylineId: PolylineId('temp'),
      points: coords,
      width: 8,
      color: Colors.blueAccent.withAlpha((255 * 0.7).round()),
    );

    setState(() {
      polylines.add(tempPolyline);
    });

    if (_mapController != null) {
      final lat = (startPoint!.latitude + endPoint!.latitude) / 2;
      final lng = (startPoint!.longitude + endPoint!.longitude) / 2;
      await _mapController!.animateCamera(
        CameraUpdate.newCameraPosition(
          CameraPosition(target: LatLng(lat, lng), zoom: 17),
        ),
      );
    }

    bool? saved = await showNewBottomSheet(
      context: context,
      coords: coords,
      onRouteSaved: (coords, rate, features) async {
        await _saveNewRoute(coords, rate, features);
      },
    );

    if (saved != true) {
      setState(() {
        polylines.removeWhere((p) => p.polylineId.value == 'temp');
        startPoint = null;
        endPoint = null;
        circles.clear();
      });
    }
  }

  void _onMapTap(LatLng pos) {
    final adjustedPos = LatLng(pos.latitude + 0.00001, pos.longitude - 0.00001);

    setState(() {
      if (startPoint == null) {
        startPoint = adjustedPos;
        circles.add(
          Circle(
            circleId: CircleId('start'),
            center: adjustedPos,
            radius: 5,
            fillColor: Colors.green.withAlpha((255 * 0.8).round()),
            strokeColor: Colors.green,
            strokeWidth: 1,
          ),
        );
      } else if (endPoint == null) {
        endPoint = adjustedPos;
        circles.add(
          Circle(
            circleId: CircleId('end'),
            center: adjustedPos,
            radius: 5,
            fillColor: Colors.red.withAlpha((255 * 0.8).round()),
            strokeColor: Colors.red,
            strokeWidth: 1,
          ),
        );
        _getRouteAndSave();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: GoogleMap(
        onMapCreated: (controller) => _mapController = controller,
        myLocationEnabled: true, // 내 위치 표시
        myLocationButtonEnabled: true, // 내 위치로 돌아가는 버튼 표시
        onTap: _onMapTap,
        circles: circles,
        polylines: polylines,
        initialCameraPosition: CameraPosition(
          target: LatLng(35.8880, 128.6106),
          zoom: 17,
        ),
      ),
    );
  }
}
