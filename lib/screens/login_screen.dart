import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:rabbithole_health_tracker_new/screens/pairing_screen.dart';
import '../services/api_service.dart';
import '../utils/token_storage.dart';
import 'main_screen.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _idController = TextEditingController();
  final _pwController = TextEditingController();
  bool _isLoading = false;
  String? _error;
  bool _checkingToken = true;

  @override
  void initState() {
    super.initState();
    _autoLogin();
  }

  Future<void> _autoLogin() async {
    final success = await ApiService.refreshTokenIfAvailable();
    if (success && mounted) {
      final userId = await TokenStorage.getUserId();
      if (userId != null) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => PairingScreen(userId: userId)),
        );
        return;
      }
    }
    // If no auto‑login, show the login form
    setState(() => _checkingToken = false);
  }

  Future<void> _login() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    final id = _idController.text.trim();
    final pw = _pwController.text.trim();

    try {
      final tokens = await ApiService.login(id, pw);

      if (context.mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => PairingScreen(userId: tokens['userId']!),
          ),
        );
      }
    } catch (e) {
      setState(() {
        _error = '로그인 실패: ${e.toString()}';
      });
      print(_error);
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_checkingToken) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final size = MediaQuery.of(context).size;

    return Scaffold(
      backgroundColor: Colors.white,
      body: Column(
        children: [
          // 상단 곡선 배경 + 로고
          SizedBox(
            height: size.height * 0.4,
            child: Stack(
              children: [
                ClipPath(
                  clipper: TopWaveClipper(),
                  child: Container(
                    decoration: const BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0xFFE1EAF2), Color(0xFF88A8C1)],
                      ),
                    ),
                    height: double.infinity,
                    width: double.infinity,
                  ),
                ),
                Positioned(
                  left: 150,
                  top: 48,
                  child: Image.asset(
                    'assets/images/logo_taean.png',
                    width: 240,
                  ),
                ),
                Positioned(
                  left: -20,
                  top: 20,
                  child: Image.asset(
                    'assets/images/logo_taean_globe.png',
                    width: 170,
                  ),
                ),
              ],
            ),
          ),

          // 입력 폼
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                IconTextField(
                  controller: _idController,
                  icon: Icons.person_outline,
                  label: "아이디",
                  hintText: "USERNAME",
                ),
                const SizedBox(height: 16),
                IconTextField(
                  controller: _pwController,
                  icon: Icons.lock_outline,
                  label: "패스워드",
                  hintText: "PASSWORD",
                  obscure: true,
                ),
                const SizedBox(height: 32),

                // 로그인 버튼
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF88A8C1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(6),
                      ),
                    ),
                    onPressed: _isLoading ? null : _login,
                    child: _isLoading
                        ? const CircularProgressIndicator(color: Colors.white)
                        : const Text(
                            "로그인",
                            style: TextStyle(
                              fontFamily: 'Pretendard',
                              fontVariations: [FontVariation('wght', 600)],
                              fontSize: 18,
                              color: Colors.white,
                            ),
                          ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// 커스텀 텍스트필드
class IconTextField extends StatelessWidget {
  final IconData icon;
  final String label;
  final String hintText;
  final bool obscure;
  final TextEditingController controller;

  const IconTextField({
    super.key,
    required this.icon,
    required this.label,
    required this.hintText,
    required this.controller,
    this.obscure = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Icon(icon, color: Colors.grey),
            const SizedBox(width: 8),
            Text(
              label,
              style: const TextStyle(
                fontFamily: 'Pretendard',
                fontSize: 16,
                fontVariations: [FontVariation('wght', 400)],
                color: Colors.grey,
              ),
            ),
          ],
        ),
        TextField(
          controller: controller,
          obscureText: obscure,
          style: const TextStyle(
            fontFamily: 'Pretendard',
            fontVariations: [FontVariation('wght', 400)],
            fontSize: 18,
          ),
          decoration: InputDecoration(
            hintText: hintText,
            hintStyle: const TextStyle(
              fontFamily: 'Pretendard',
              fontVariations: [FontVariation('wght', 400)],
              fontSize: 18,
              color: Colors.grey,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(vertical: 12),
            enabledBorder: const UnderlineInputBorder(
              borderSide: BorderSide(color: Colors.grey),
            ),
          ),
        ),
      ],
    );
  }
}

// 상단 곡선 클리퍼
class TopWaveClipper extends CustomClipper<Path> {
  @override
  Path getClip(Size size) {
    Path path = Path();
    path.lineTo(0, size.height * 0.75);

    // 파도 곡선 (두 번 출렁이는 형태)
    path.cubicTo(
      size.width * 0.25,
      size.height * 0.25, // 첫 웨이브의 제어점 1
      size.width * 0.5,
      size.height * 0.95, // 첫 웨이브의 제어점 2
      size.width,
      size.height * 0.85, // 첫 웨이브의 끝점
    );

    path.lineTo(size.width, 0);
    path.close();
    return path;
  }

  @override
  bool shouldReclip(CustomClipper<Path> oldClipper) => false;
}
