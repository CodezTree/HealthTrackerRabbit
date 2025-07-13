import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:fluttertoast/fluttertoast.dart';
import 'package:flutter/material.dart';
import '../utils/token_storage.dart';

class ApiService {
  static const String baseUrl = "https://www.taeanaihealth.or.kr";

  static Future<Map<String, String>> login(
    String userId,
    String password,
  ) async {
    final url = Uri.parse("$baseUrl/users/login");

    print("🟢 로그인 시작: userId=$userId");
    try {
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
    } catch (e) {
      print("🔴 로그인 네트워크 오류: $e");
      Fluttertoast.showToast(
        msg: "연결에 실패했습니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      throw Exception("로그인 네트워크 오류");
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

    try {
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
    } catch (e) {
      print("🔴 토큰 갱신 네트워크 오류: $e");
      Fluttertoast.showToast(
        msg: "연결에 실패했습니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return false;
    }
  }

  /// 30분간 수집된 건강 데이터를 새로운 JSON 형태로 전송 (최대 3회 재시도)
  static Future<bool> sendHealthData({
    required int heartRate,
    required int spo2,
    required int stepCount,
    double? bodyTemperature,
    int? systolicBP,
    int? diastolicBP,
    int? bloodSugar,
    int? battery,
    int? chargingState,
    double? sleepHours,
    int? sportsTime,
    int? screenStatus,
    String? timestamp,
  }) async {
    const int maxRetries = 3;
    int attempt = 0;

    while (attempt < maxRetries) {
      attempt++;
      print("🟡 건강 데이터 전송 시도 $attempt/$maxRetries");

      try {
        String? accessToken = await TokenStorage.getAccessToken();
        final userId = await TokenStorage.getUserId();

        if (accessToken == null || userId == null) {
          print("🔴 액세스 토큰 또는 사용자 ID가 없음");
          return false;
        }

        final url = Uri.parse("$baseUrl/users/data");

        // 새로운 JSON 형태로 데이터 구성
        final healthData = {
          "user_id": userId,
          "heart_rate": heartRate,
          "spo2": spo2,
          "step_count": stepCount,
          "body_temperature": bodyTemperature ?? 36.5,
          "blood_pressure": {
            "systolic": systolicBP ?? 120,
            "diastolic": diastolicBP ?? 80,
          },
          "blood_sugar": bloodSugar ?? 98,
          "battery": battery ?? 100,
          "charging_state": chargingState ?? 0,
          "sleep_hours": sleepHours ?? 0.0,
          "sports_time": sportsTime ?? 0,
          "screen_status": screenStatus ?? 0,
          "timestamp": timestamp ?? DateTime.now().toUtc().toIso8601String(),
        };

        print("🟡 전송할 데이터: ${jsonEncode(healthData)}");

        final response = await http.post(
          url,
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $accessToken',
          },
          body: jsonEncode(healthData),
        );

        if (response.statusCode == 200 || response.statusCode == 201) {
          print("🟢 건강 데이터 전송 성공 (시도 $attempt/$maxRetries)");
          return true;
        } else if (response.statusCode == 401) {
          // 토큰 만료 - 리프레시 시도 (재시도 횟수에 포함되지 않음)
          print("🔄 토큰 만료, 리프레시 시도");
          if (await refreshTokenIfAvailable()) {
            print("🟢 토큰 리프레시 성공, 재시도");
            // 토큰 리프레시 성공 시 현재 시도를 다시 실행 (attempt 감소)
            attempt--;
            continue;
          } else {
            print("🔴 토큰 리프레시 실패");
            return false;
          }
        } else {
          print("🔴 건강 데이터 전송 실패 (${response.statusCode}): ${response.body}");

          // 서버 오류(5xx) 또는 일시적 오류인 경우에만 재시도
          if (response.statusCode >= 500 || response.statusCode == 429) {
            if (attempt < maxRetries) {
              print("🔄 서버 오류로 인한 재시도 대기 중... (${attempt + 1}/$maxRetries)");
              await Future.delayed(Duration(seconds: attempt * 2)); // 지수 백오프
              continue;
            }
          }
          return false;
        }
      } catch (e) {
        print("🔴 건강 데이터 전송 오류 (시도 $attempt/$maxRetries): $e");

        // 네트워크 오류 시 토스트 메시지 표시
        if (attempt == 1) {
          Fluttertoast.showToast(
            msg: "연결에 실패했습니다",
            toastLength: Toast.LENGTH_SHORT,
            gravity: ToastGravity.BOTTOM,
            timeInSecForIosWeb: 1,
            backgroundColor: Colors.red,
            textColor: Colors.white,
            fontSize: 16.0,
          );
        }

        if (attempt < maxRetries) {
          print("🔄 네트워크 오류로 인한 재시도 대기 중... (${attempt + 1}/$maxRetries)");
          await Future.delayed(
            Duration(seconds: attempt * 2),
          ); // 지수 백오프 (2초, 4초, 6초)
          continue;
        }
        return false;
      }
    }

    print("🔴 모든 재시도 실패 - 건강 데이터 전송 최종 실패");
    Fluttertoast.showToast(
      msg: "연결에 실패했습니다",
      toastLength: Toast.LENGTH_SHORT,
      gravity: ToastGravity.BOTTOM,
      timeInSecForIosWeb: 1,
      backgroundColor: Colors.red,
      textColor: Colors.white,
      fontSize: 16.0,
    );
    return false;
  }

  /// 테스트용 샘플 데이터 전송
  static Future<bool> sendTestHealthData() async {
    print("🧪 테스트 건강 데이터 전송 시작");

    return await sendHealthData(
      heartRate: 78,
      spo2: 97,
      stepCount: 1234,
      bodyTemperature: 36.5,
      systolicBP: 120,
      diastolicBP: 80,
      bloodSugar: 98,
      battery: 85,
      chargingState: 1,
      sleepHours: 7.7,
      sportsTime: 1800,
      screenStatus: 1,
      timestamp: DateTime.now().toUtc().toIso8601String(),
    );
  }

  /// 주기적 백그라운드 데이터 전송
  static Future<bool> sendBackgroundHealthData() async {
    try {
      // 로컬 DB에서 최신 데이터 가져오기
      // 이 부분은 로컬 DB 서비스와 연결해야 함
      print("🟡 백그라운드 건강 데이터 전송 시작");

      // TODO: 로컬 DB에서 전송되지 않은 데이터들을 가져와서 순차적으로 전송
      // 현재는 기본값으로 테스트

      return true;
    } catch (e) {
      print("🔴 백그라운드 건강 데이터 전송 오류: $e");
      Fluttertoast.showToast(
        msg: "연결에 실패했습니다",
        toastLength: Toast.LENGTH_SHORT,
        gravity: ToastGravity.BOTTOM,
        timeInSecForIosWeb: 1,
        backgroundColor: Colors.red,
        textColor: Colors.white,
        fontSize: 16.0,
      );
      return false;
    }
  }
}
