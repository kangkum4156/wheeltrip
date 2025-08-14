import 'dart:typed_data';

class PendingPhoto {
  final Uint8List bytes; // 압축된 JPG 바이트
  final String localId;  // 썸네일 key용 (timestamp 등)
  PendingPhoto({required this.bytes, required this.localId});
}
