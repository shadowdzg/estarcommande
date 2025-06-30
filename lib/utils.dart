// TODO Implement this library.
import 'dart:convert';

Map<String, dynamic> decodeJwtPayload(String token) {
  final parts = token.split('.');
  if (parts.length != 3) {
    throw Exception('Invalid JWT');
  }
  final payload = base64Url.normalize(parts[1]);
  final payloadMap = json.decode(utf8.decode(base64Url.decode(payload)));
  if (payloadMap is! Map<String, dynamic>) {
    throw Exception('Invalid payload');
  }
  return payloadMap;
}
