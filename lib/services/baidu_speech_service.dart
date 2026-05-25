import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;


class BaiduSpeechService {
  final String apiKey;
  final String secretKey;
  String? _accessToken;
  DateTime? _tokenExpireTime;

  BaiduSpeechService({required this.apiKey, required this.secretKey});

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

  Future<String?> recognizeSpeech(String filePath) async {
    final accessToken = await getAccessToken();
    if (accessToken == null) return null;

    final file = File(filePath);
    final bytes = await file.readAsBytes();
    final base64Audio = base64Encode(bytes);

    final response = await http.post(
      Uri.parse('https://vop.baidu.com/server_api'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'format': 'wav',
        'rate': 16000,
        'channel': 1,
        'cuid': 'ledger_app',
        'token': accessToken,
        'speech': base64Audio,
        'len': bytes.length,
      }),
    );

    if (response.statusCode == 200) {
      final data = jsonDecode(response.body);
      if (data['err_no'] == 0 &&
          data['result'] != null &&
          data['result'].isNotEmpty) {
        return data['result'][0];
      }
    }
    return null;
  }
}
