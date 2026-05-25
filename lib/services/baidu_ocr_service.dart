import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;


class BaiduOcrService {
  final String apiKey;
  final String secretKey;
  String? _accessToken;
  DateTime? _tokenExpireTime;

  BaiduOcrService({required this.apiKey, required this.secretKey});

  Future<String?> getAccessToken() async {
    if (_accessToken != null && _tokenExpireTime != null) {
      if (DateTime.now().isBefore(_tokenExpireTime!)) {
        return _accessToken;
      }
    }

    final response = await http.post(
      Uri.parse('https://aip.baidubce.com/oauth/2.0/token'),
      body: {
        'grant_type': 'client_credentials',
        'client_id': apiKey,
        'client_secret': secretKey,
      },
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      _accessToken = data['access_token'];
      final expiresIn = data['expires_in'] as int;
      _tokenExpireTime = DateTime.now().add(Duration(seconds: expiresIn - 60));
      return _accessToken;
    }
    return null;
  }

  Future<String?> recognizeImage(String imagePath) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;

    final file = File(imagePath);
    final bytes = await file.readAsBytes();
    final response = await http.post(
      Uri.parse(
        'https://aip.baidubce.com/rest/2.0/ocr/v1/general_basic'
        '?access_token=$accessToken',
      ),
      headers: {'Content-Type': 'application/x-www-form-urlencoded'},
      body: {'image': base64Encode(bytes)},
    );

    if (response.statusCode != 200) {
      return null;
    }
    final data = jsonDecode(response.body);
    final words = data['words_result'];
    if (words is! List || words.isEmpty) {
      return null;
    }
    return words
        .map((item) {
          if (item is Map && item['words'] != null) {
            return item['words'].toString();
          }
          return '';
        })
        .where((line) => line.trim().isNotEmpty)
        .join('\n');
  }
}
