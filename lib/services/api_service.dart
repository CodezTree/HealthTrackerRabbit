import 'dart:convert';
import 'package:http/http.dart' as http;
import '../utils/token_storage.dart';

class ApiService {
  static const String baseUrl = "https://www.taeanaihealth.or.kr";

  static Future<Map<String, String>> login(
    String userId,
    String password,
  ) async {
    final url = Uri.parse("$baseUrl/users/login");

    print("🟢 로그인 시작: userId=$userId");
    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"user_id": userId, "password": password}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);

      // ✅ 여기에 로그 추가
      print("🟢 로그인 성공: userId=$userId");
      print(
        "📦 accessToken=${data["accessToken"].toString().substring(0, 20)}...",
      );
      print(
        "📦 refreshToken=${data["refreshToken"].toString().substring(0, 20)}...",
      );

      final tokens = {
        "accessToken": data["accessToken"].toString(),
        "refreshToken": data["refreshToken"].toString(),
        "userId": userId, // 직접 넣어주기
      };

      await TokenStorage.saveToken(
        tokens['accessToken']!,
        tokens['refreshToken']!,
      );
      await TokenStorage.saveUserId(tokens['userId']!);

      return tokens;
    } else {
      throw Exception("로그인 실패 (${response.statusCode})");
    }
  }

  static Future<bool> refreshTokenIfAvailable() async {
    final userId = await TokenStorage.getUserId();
    final refreshToken = await TokenStorage.getRefreshToken();

    if (userId == null || refreshToken == null) {
      print("🔁 토큰 갱신 불필요: 저장된 토큰 없음");
      return false;
    }

    final url = Uri.parse("$baseUrl/users/refresh-token");

    final response = await http.post(
      url,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({"user_id": userId, "refreshToken": refreshToken}),
    );

    if (response.statusCode == 200 || response.statusCode == 201) {
      final data = jsonDecode(response.body);
      print("🟢 토큰 갱신 성공");

      await TokenStorage.saveToken(data["accessToken"], data["refreshToken"]);
      return true;
    } else {
      print("🔴 토큰 갱신 실패 (${response.statusCode})");
      return false;
    }
  }
}
