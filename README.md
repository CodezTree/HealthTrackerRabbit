# RabbitHole Health Tracker

30분 주기로 스마트 링에서 건강 데이터를 자동 수집하고 API로 전송하는 Flutter 앱입니다.

## 🎯 주요 기능

### 📊 백그라운드 건강 모니터링

- **30분 주기 자동 데이터 수집**: SR08 링에서 심박수, 혈중산소, 걸음수 자동 수집
- **자동 재연결**: 링 연결이 끊어진 경우 최대 5회 자동 재연결 시도
- **실시간 API 전송**: 수집된 데이터를 즉시 서버로 전송 (최대 3회 재시도)
- **로컬 백업**: 전송 실패 시 SQLite에 안전하게 저장 후 다음 기회에 재전송

### 🔄 API 데이터 형태

백그라운드에서 수집된 건강 데이터는 다음과 같은 JSON 형태로 전송됩니다:

```json
{
  "user_id": "사용자ID",
  "heart_rate": 78,
  "spo2": 97,
  "step_count": 1234,
  "body_temperature": 36.5,
  "blood_pressure": {
    "systolic": 120,
    "diastolic": 80
  },
  "blood_sugar": 98,
  "battery": 85,
  "charging_state": 1,
  "sleep_hours": 7.7,
  "sports_time": 1800,
  "screen_status": 1,
  "timestamp": "2025-01-17T10:00:00Z"
}
```

### 📡 API 엔드포인트

- **URL**: `{baseURL}/users/data`
- **Method**: POST
- **Headers**:
  - `Content-Type: application/json`
  - `Authorization: Bearer {accessToken}`

### 🔧 재시도 로직

- **최대 재시도 횟수**: 3회
- **재시도 조건**:
  - 네트워크 오류
  - 서버 오류 (5xx)
  - 요청 제한 오류 (429)
- **백오프 전략**: 지수적 증가 (2초, 4초, 6초)
- **토큰 갱신**: 401 오류 시 자동 리프레시 토큰으로 갱신

## 🏗 시스템 아키텍처

```
SR08 Ring Device
      ↓
SR08HealthService (30분 타이머)
      ↓
GET10/GET14/GET23 순차 실행
      ↓
MainApplication (데이터 수신)
      ↓
BackgroundHealthProvider (데이터 처리)
      ↓
LocalDbService (로컬 저장) + ApiService (서버 전송)
      ↓
Server API ({baseURL}/users/data)
```

## 🚀 사용 방법

### 1. 백그라운드 서비스 시작

```dart
await platform.invokeMethod('startBackgroundService');
```

### 2. 즉시 데이터 수집 (테스트용)

```dart
await platform.invokeMethod('requestBackgroundHealthData');
```

### 3. 테스트 데이터 전송

```dart
await ApiService.sendTestHealthData();
```

## 📱 지원 플랫폼

- ✅ Android
- ❌ iOS (향후 지원 예정)

## 🔐 보안 기능

- JWT 액세스 토큰 자동 관리
- 리프레시 토큰을 통한 자동 토큰 갱신
- 로컬 데이터 암호화 저장

## 📋 데이터 필드 설명

| 필드             | 타입   | 설명                             | 기본값                       |
| ---------------- | ------ | -------------------------------- | ---------------------------- |
| user_id          | String | 사용자 고유 식별자               | 로그인된 사용자 ID           |
| heart_rate       | int    | 심박수 (BPM)                     | 링에서 측정된 값             |
| spo2             | int    | 혈중산소농도 (%)                 | 링에서 측정된 값             |
| step_count       | int    | 걸음수                           | 링에서 측정된 값             |
| body_temperature | double | 체온 (°C)                        | 36.5 (기본값)                |
| blood_pressure   | Object | 혈압                             | systolic: 120, diastolic: 80 |
| blood_sugar      | int    | 혈당 (mg/dL)                     | 98 (기본값)                  |
| battery          | int    | 배터리 잔량 (%)                  | 링에서 측정된 값             |
| charging_state   | int    | 충전 상태 (0: 미충전, 1: 충전중) | 0 (기본값)                   |
| sleep_hours      | double | 수면 시간 (시간)                 | 0.0 (기본값)                 |
| sports_time      | int    | 운동 시간 (초)                   | 0 (기본값)                   |
| screen_status    | int    | 화면 상태                        | 0 (기본값)                   |
| timestamp        | String | 측정 시각 (ISO 8601 UTC)         | 측정 당시 시각               |

---

🏥 **Taean AI Health Center** - 스마트 헬스케어 솔루션
