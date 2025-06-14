import 'dart:convert';
import 'package:http/http.dart' as http;

class ApiService {
  static const baseUrl = 'https://your-api.com'; // 실제 API 주소로 교체

  static Future<String> login(String id, String password) async {
    final url = Uri.parse('$baseUrl/login');
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'id': id, 'password': password}),
    );

    if (response.statusCode == 200) {
      final json = jsonDecode(response.body);
      return json['token']; // 서버에서 반환되는 JWT 키 이름에 맞게 수정
    } else {
      throw Exception('서버 응답 오류: ${response.statusCode}');
    }
  }
}
