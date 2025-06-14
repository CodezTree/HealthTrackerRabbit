import 'package:flutter/material.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/ble_provider.dart';
import 'main_screen.dart';

class PairingScreen extends ConsumerStatefulWidget {
  const PairingScreen({super.key});

  @override
  ConsumerState<PairingScreen> createState() => _PairingScreenState();
}

class _PairingScreenState extends ConsumerState<PairingScreen> {
  final List<ScanResult> _devices = [];
  bool _isScanning = false;
  bool isConnecting = false;
  bool hasFailed = false;

  @override
  void initState() {
    super.initState();
    _startScan(); // 화면이 시작되면 자동으로 스캔 시작
  }

  void _startScan() async {
    if (_isScanning) return;

    setState(() {
      _isScanning = true;
      _devices.clear();
    });

    try {
      final bleService = ref.read(bleServiceProvider);
      await bleService.startScan((device) {
        if (!_devices.any((d) => d.device.remoteId == device.remoteId)) {
          setState(() {
            _devices.add(ScanResult(
              device: device,
              advertisementData: AdvertisementData(
                advName: device.platformName,
                txPowerLevel: -1,
                connectable: true,
                manufacturerData: {},
                serviceData: {},
                serviceUuids: [],
                appearance: null,
              ),
              rssi: -50,
              timeStamp: DateTime.now(),
            ));
          });
        }
      });
    } catch (e) {
      print('Scan failed: $e');
    }

    setState(() => _isScanning = false);
  }

  void _connectToDevice(BluetoothDevice device) async {
    setState(() {
      isConnecting = true;
      hasFailed = false;
    });

    final bleService = ref.read(bleServiceProvider);
    try {
      await bleService.connectToDevice(device.remoteId.str);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 성공: ${device.platformName}')),
        );

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
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('연결 실패: ${e.toString()}')),
        );
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
            const Text('기기 검색 중...'),
          ] else ...[
            Expanded(
              child: ListView.builder(
                itemCount: _devices.length,
                itemBuilder: (context, index) {
                  final device = _devices[index].device;
                  return ListTile(
                    title: Text(device.platformName.isEmpty
                        ? 'Unknown Device'
                        : device.platformName),
                    subtitle: Text(device.remoteId.str),
                    trailing: ElevatedButton(
                      onPressed:
                          isConnecting ? null : () => _connectToDevice(device),
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
