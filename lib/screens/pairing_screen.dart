import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';
import '../services/permission_service.dart';
import 'main_screen.dart';

class PairingScreen extends ConsumerStatefulWidget {
  final String userId;

  const PairingScreen({super.key, required this.userId});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final List<ScanResult> _devices = [];
  bool _isScanning = false;
  bool isConnecting = false;
  bool hasFailed = false;
  int retryCount = 0;
  static const int maxRetries = 3;

  // 스캔 지속 시간 (seconds)
  static const Duration SCAN_DURATION = Duration(seconds: 6);

  // SR08 링 관련 UUID 상수
  static const String SERVICE_UUID = "0000ff01-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_WRITE_UUID =
      "0000ff02-0000-1000-8000-00805f9b34fb";
  static const String CHARACTERISTIC_READ_UUID =
      "0000ff10-0000-1000-8000-00805f9b34fb";
  static const String DESCRIPTOR_UUID = "00002902-0000-1000-8000-00805f9b34fb";

  void _showToast(String message) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        duration: const Duration(seconds: 2),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    print('🟢 로그인한 유저: ${widget.userId}');
    // 첫 프레임이 그려진 후에 스캔 시작
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _startScan();
    });
  }

  void _startScan() async {
    if (_isScanning) return;

    // BLE 권한 요청
    final permissionService = PermissionService();
    final hasPermission = await permissionService.requestBlePermissions();
    if (!hasPermission) {
      _showToast('블루투스 권한이 필요합니다. 설정에서 권한을 허용해주세요.');
      return;
    }

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    _showToast('링 검색을 시작합니다...');

    try {
      final bleService = ref.read(bleServiceProvider);
      await bleService.startScan((device) {
        print("ADV Name found: ${device.platformName}");
        if (!_devices.any((d) => d.device.remoteId == device.remoteId)) {
          // 스캔 결과를 직접 처리
          final scanResult = ScanResult(
            device: device,
            advertisementData: AdvertisementData(
              advName: device.platformName,
              txPowerLevel: -1,
              connectable: true,
              manufacturerData: {},
              serviceData: {},
              serviceUuids: [], // 실제 서비스 UUID는 연결 후 확인
              appearance: null,
            ),
            rssi: -50,
            timeStamp: DateTime.now(),
          );

          setState(() {
            _devices.add(scanResult);
          });
          _showToast(
            '링을 발견했습니다: ${device.platformName.isNotEmpty ? device.platformName : device.remoteId.str}',
          );
          // 디바이스를 찾으면 자동으로 연결 시도
          _connectToDevice(device);
        }
      });
      // 일정 시간 후 스캔 종료 표시
      Future.delayed(SCAN_DURATION, () {
        if (mounted) {
          setState(() => _isScanning = false);
          if (_devices.isEmpty) {
            _showToast('링을 찾을 수 없습니다. 다시 시도해주세요.');
          }
        }
      });
    } catch (e) {
      print('Scan failed: $e');
      _showToast('디바이스 검색 중 오류가 발생했습니다.');
      setState(() => _isScanning = false);
    }
  }

  void _connectToDevice(BluetoothDevice device) async {
    if (isConnecting) return;

    setState(() {
      isConnecting = true;
      hasFailed = false;
    });

    _showToast('${device.platformName}에 연결을 시도합니다...');

    final bleService = ref.read(bleServiceProvider);
    try {
      await bleService.connectToDevice(device.remoteId.str);

      if (context.mounted) {
        _showToast('${device.platformName} 연결이 완료되었습니다.');
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainScreen()),
        );
      }
    } catch (e) {
      setState(() {
        isConnecting = false;
        hasFailed = true;
      });

      if (retryCount < maxRetries) {
        retryCount++;
        _showToast('연결 실패. 재시도 중... ($retryCount/$maxRetries)');
        // 2초 후 재연결 시도
        Future.delayed(const Duration(seconds: 2), () {
          _connectToDevice(device);
        });
      } else {
        _showToast('연결에 실패했습니다. 다시 스캔을 시작합니다.');
        retryCount = 0;
        _startScan();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          _TopGradient(),
          const SizedBox(height: 40),
          if (_devices.isEmpty && !_isScanning) ...[
            Stack(
              alignment: Alignment.center,
              clipBehavior: Clip.none,
              children: [
                Image.asset('assets/images/charging_deck.png', height: 200),
                Positioned(
                  bottom: 135,
                  child: Image.asset(
                    'assets/images/arrow_stack.png',
                    height: 110,
                  ),
                ),
              ],
            ),
            Transform.translate(
              offset: const Offset(0, -32),
              child: const Text.rich(
                TextSpan(
                  text: '충전기 ',
                  style: TextStyle(fontFamily: 'Pretendard', fontSize: 20),
                  children: [
                    TextSpan(
                      text: 'DECK',
                      style: TextStyle(
                        fontVariations: [FontVariation('wght', 600)],
                        color: Color(0xFF6B849B),
                      ),
                    ),
                    TextSpan(text: ' 위에 링을 올려주세요'),
                  ],
                ),
              ),
            ),
          ] else if (_isScanning) ...[
            const CircularProgressIndicator(),
            const SizedBox(height: 16),
            const Text('링 검색 중...'),
          ] else ...[
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index].device;
                  return ListTile(
                    title: Text(
                      device.platformName.isEmpty
                          ? 'Unknown Device'
                          : device.platformName,
                    ),
                    subtitle: Text(device.remoteId.str),
                    trailing: ElevatedButton(
                      onPressed: isConnecting
                          ? null
                          : () => _connectToDevice(device),
                      child: Text(isConnecting ? '연결 중...' : '연결'),
                    ),
                  );
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: ElevatedButton(
                onPressed: _isScanning ? null : _startScan,
                child: Text(_isScanning ? '검색 중...' : '다시 검색'),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _TopGradient extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 220,
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFF6DA3C2), Colors.white],
        ),
        borderRadius: BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
        ),
      ),
    );
  }
}
