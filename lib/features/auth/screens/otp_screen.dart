import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../../shared/widgets/app_card.dart';

class OTPScreen extends ConsumerStatefulWidget {
  final String email;
  const OTPScreen({super.key, required this.email});
  @override
  ConsumerState<OTPScreen> createState() => _OTPScreenState();
}

class _OTPScreenState extends ConsumerState<OTPScreen> with SingleTickerProviderStateMixin {
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());
  final List<FocusNode>             _focusNodes  = List.generate(6, (_) => FocusNode());
  bool _isLoading     = false;
  int  _resendSeconds = 60;
  Timer? _timer;
  late AnimationController _animCtrl;
  late Animation<double>   _fadeAnim;
  late Animation<Offset>   _slideAnim;

  @override
  void initState() {
    super.initState();
    _startTimer();
    WidgetsBinding.instance.addPostFrameCallback((_) => _focusNodes[0].requestFocus());
    _animCtrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 700));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.06), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _timer?.cancel();
    _animCtrl.dispose();
    for (final c in _controllers) c.dispose();
    for (final f in _focusNodes)  f.dispose();
    super.dispose();
  }

  void _startTimer() {
    setState(() => _resendSeconds = 60);
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_resendSeconds == 0) { t.cancel(); return; }
      setState(() => _resendSeconds--);
    });
  }

  String get _otp => _controllers.map((c) => c.text).join();

  Future<void> _verify() async {
    if (_otp.length < 6) return;
    setState(() => _isLoading = true);
    try {
      await ref.read(authStateProvider.notifier).verifyOTP(widget.email, _otp);
    } catch (e) {
      if (mounted) {
        String message = 'Invalid or expired OTP. Please try again.';
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.sendTimeout ||
              e.type == DioExceptionType.receiveTimeout) {
            message = '🔌 Backend server is not running.\nPlease start the server and try again.';
          } else if (e.response?.data?['message'] != null) {
            message = e.response!.data['message'];
          }
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message), backgroundColor: AppColors.error, duration: const Duration(seconds: 4)));
        for (final c in _controllers) c.clear();
        _focusNodes[0].requestFocus();
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resend() async {
    if (_resendSeconds > 0) return;
    try {
      await ref.read(authStateProvider.notifier).sendOTP(widget.email);
      _startTimer();
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('OTP resent successfully!'), backgroundColor: AppColors.success));
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: LayoutBuilder(builder: (context, constraints) {
        return constraints.maxWidth >= 800 ? _buildWide() : _buildNarrow();
      }),
    );
  }

  Widget _buildWide() {
    return Row(children: [
      Expanded(
        flex: 5,
        child: Container(
          decoration: const BoxDecoration(gradient: AppGradients.hero),
          child: Stack(children: [
            const Positioned(top: -80,   right: -80, child: _Circle(size: 280, opacity: 0.12)),
            const Positioned(bottom: -60, left: -60, child: _Circle(size: 220, opacity: 0.10)),
            Center(child: Padding(
              padding: const EdgeInsets.all(56),
              child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                Container(width: 80, height: 80,
                  decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)),
                  child: const Icon(Icons.lock_rounded, color: Colors.white, size: 40)),
                const SizedBox(height: 24),
                const Text('Verify your identity',
                  style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.5)),
                const SizedBox(height: 12),
                Text('Enter the 6-digit code sent to your email.\nCodes expire in 10 minutes.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 14, height: 1.6)),
              ]),
            )),
          ]),
        ),
      ),
      Expanded(
        flex: 4,
        child: Center(child: SingleChildScrollView(
          padding: const EdgeInsets.all(48),
          child: ConstrainedBox(constraints: const BoxConstraints(maxWidth: 420),
            child: FadeTransition(opacity: _fadeAnim,
              child: SlideTransition(position: _slideAnim, child: _buildOTPContent()))),
        )),
      ),
    ]);
  }

  Widget _buildNarrow() {
    return Stack(children: [
      Positioned.fill(child: Container(decoration: const BoxDecoration(gradient: AppGradients.hero))),
      const Positioned(top: -40, right: -40, child: _Circle(size: 180, opacity: 0.14)),
      SafeArea(child: Column(children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          child: Row(children: [
            IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
              onPressed: () => context.go('/login')),
          ]),
        ),
        const SizedBox(height: 8),
        Container(width: 64, height: 64,
          decoration: BoxDecoration(color: Colors.white.withOpacity(0.18), borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withOpacity(0.3), width: 1.5)),
          child: const Icon(Icons.lock_rounded, color: Colors.white, size: 30)),
        const SizedBox(height: 14),
        const Text('Verify OTP', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
        const SizedBox(height: 4),
        Text('Code sent to your email', style: TextStyle(color: Colors.white.withOpacity(0.72), fontSize: 13)),
        const SizedBox(height: 28),
        Expanded(child: Container(
          decoration: const BoxDecoration(color: AppColors.background, borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
          child: FadeTransition(opacity: _fadeAnim,
            child: SlideTransition(position: _slideAnim,
              child: SingleChildScrollView(padding: const EdgeInsets.all(28), child: _buildOTPContent(showBackButton: false)))),
        )),
      ])),
    ]);
  }

  Widget _buildOTPContent({bool showBackButton = true}) {
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      if (showBackButton) ...[
        IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded, size: 20),
          onPressed: () => context.go('/login'),
          style: IconButton.styleFrom(foregroundColor: AppColors.textPrimary)),
        const SizedBox(height: 8),
        const Text('Enter OTP', style: TextStyle(fontSize: 26, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5)),
        const SizedBox(height: 6),
        const Text('Enter the 6-digit code sent to your email', style: TextStyle(fontSize: 14, color: AppColors.textSecondary)),
        const SizedBox(height: 24),
      ],

      // Email info chip
      Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.06),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.2), width: 1.2),
        ),
        child: Row(children: [
          Container(padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(gradient: AppGradients.primary, borderRadius: BorderRadius.circular(8)),
            child: const Icon(Icons.mark_email_read_rounded, color: Colors.white, size: 14)),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('OTP sent to', style: TextStyle(fontSize: 11, color: AppColors.textSecondary, fontWeight: FontWeight.w500)),
            Text(widget.email, style: const TextStyle(fontSize: 13, color: AppColors.textPrimary, fontWeight: FontWeight.w700), overflow: TextOverflow.ellipsis),
          ])),
          Container(padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.12), borderRadius: BorderRadius.circular(8)),
            child: const Text('10 min', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w700))),
        ]),
      ),

      const SizedBox(height: 28),
      const Text('6-Digit Code', style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
      const SizedBox(height: 14),

      // OTP boxes
      Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: List.generate(6, (i) => _OTPBox(
          controller: _controllers[i],
          focusNode: _focusNodes[i],
          filled: _controllers[i].text.isNotEmpty,
          onChanged: (v) {
            if (v.isNotEmpty && i < 5) _focusNodes[i + 1].requestFocus();
            if (v.isEmpty   && i > 0) _focusNodes[i - 1].requestFocus();
            setState(() {});
            if (_otp.length == 6) _verify();
          },
        )),
      ),

      const SizedBox(height: 32),
      GradientButton(
        label: 'Verify & Login',
        onPressed: (_isLoading || _otp.length < 6) ? null : _verify,
        isLoading: _isLoading,
        icon: Icons.verified_rounded,
      ),
      const SizedBox(height: 24),

      // Resend
      Center(
        child: _resendSeconds > 0
            ? Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                const Icon(Icons.timer_outlined, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text('Resend in ', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                Text('${_resendSeconds}s', style: const TextStyle(color: AppColors.primary, fontSize: 13, fontWeight: FontWeight.w700)),
              ])
            : GestureDetector(
                onTap: _resend,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                  decoration: BoxDecoration(border: Border.all(color: AppColors.primary, width: 1.5), borderRadius: BorderRadius.circular(12)),
                  child: const Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.refresh_rounded, size: 16, color: AppColors.primary),
                    SizedBox(width: 6),
                    Text('Resend OTP', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 13)),
                  ]),
                ),
              ),
      ),
    ]);
  }
}

class _OTPBox extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final bool filled;
  const _OTPBox({required this.controller, required this.focusNode, required this.onChanged, required this.filled});

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      width: 48, height: 56,
      decoration: BoxDecoration(
        gradient: filled ? AppGradients.primary : null,
        color: filled ? null : AppColors.surfaceVariant,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: filled ? AppColors.primary : AppColors.border, width: filled ? 2 : 1.5),
        boxShadow: filled ? AppShadows.glow(AppColors.primary, intensity: 0.2) : [],
      ),
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        textAlign: TextAlign.center,
        keyboardType: TextInputType.number,
        maxLength: 1,
        onChanged: onChanged,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800,
          color: filled ? Colors.white : AppColors.textPrimary),
        decoration: const InputDecoration(
          counterText: '', border: InputBorder.none, enabledBorder: InputBorder.none,
          focusedBorder: InputBorder.none, fillColor: Colors.transparent, filled: false, contentPadding: EdgeInsets.zero),
      ),
    );
  }
}

class _Circle extends StatelessWidget {
  final double size; final double opacity;
  const _Circle({required this.size, required this.opacity});
  @override
  Widget build(BuildContext context) => Container(width: size, height: size,
    decoration: BoxDecoration(shape: BoxShape.circle, color: Colors.white.withOpacity(opacity)));
}
