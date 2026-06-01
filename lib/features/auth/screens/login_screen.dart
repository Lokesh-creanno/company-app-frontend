import 'dart:ui';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';
import '../../../core/theme.dart';
import '../../../core/theme_provider.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/creanno_logo.dart';
import '../../../shared/widgets/aurora_background.dart';

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});
  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _emailCtrl = TextEditingController();
  final _formKey   = GlobalKey<FormState>();
  bool _isLoading  = false;
  late AnimationController _animCtrl;
  late Animation<double> _fadeAnim;
  late Animation<Offset> _slideAnim;

  @override
  void initState() {
    super.initState();
    _animCtrl = AnimationController(
        vsync: this, duration: const Duration(milliseconds: 1000));
    _fadeAnim  = CurvedAnimation(parent: _animCtrl, curve: Curves.easeOut);
    _slideAnim = Tween<Offset>(begin: const Offset(0, 0.10), end: Offset.zero)
        .animate(CurvedAnimation(parent: _animCtrl, curve: Curves.easeOutCubic));
    _animCtrl.forward();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _animCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      await ref.read(authStateProvider.notifier).sendOTP(_emailCtrl.text.trim());
      if (mounted) context.push('/otp', extra: _emailCtrl.text.trim());
    } catch (e) {
      if (mounted) {
        String message;
        if (e is DioException) {
          if (e.type == DioExceptionType.connectionTimeout ||
              e.type == DioExceptionType.receiveTimeout ||
              e.type == DioExceptionType.connectionError ||
              e.type == DioExceptionType.sendTimeout) {
            message =
                '🔌 Backend server is not running.\nPlease start the server first, then try again.';
          } else if (e.response?.statusCode == 404) {
            message = 'Email not found. Use your registered company email.';
          } else if (e.response?.statusCode != null) {
            message =
                e.response?.data?['message'] ?? 'Server error. Please try again.';
          } else {
            message =
                '🔌 Cannot reach server. Make sure the backend is running on port 5000.';
          }
        } else {
          message = 'Something went wrong. Please try again.';
        }
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(message),
          backgroundColor: AppColors.error,
          duration: const Duration(seconds: 6),
        ));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          // ── Animated aurora background ────────────────────────────────────
          const Positioned.fill(child: AuroraBackground(intensity: 1.0)),

          // ── Theme toggle (top-right) ──────────────────────────────────────
          SafeArea(
            child: Align(
              alignment: Alignment.topRight,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: _ThemeTogglePill(),
              ),
            ),
          ),

          // ── Login content ─────────────────────────────────────────────────
          SafeArea(
            child: LayoutBuilder(builder: (context, constraints) {
              final isWide = constraints.maxWidth >= 800;
              return isWide
                  ? _buildWideLayout()
                  : _buildNarrowLayout();
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildWideLayout() {
    return Row(
      children: [
        // Left brand panel
        Expanded(flex: 5, child: _buildBrandPanel()),
        // Right glass form
        Expanded(
          flex: 4,
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(48),
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: FadeTransition(
                  opacity: _fadeAnim,
                  child: SlideTransition(
                    position: _slideAnim,
                    child: _buildGlassForm(),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildNarrowLayout() {
    return Column(
      children: [
        // Top: brand header
        _buildMobileHeader(),
        // Bottom: glass form panel
        Expanded(
          child: FadeTransition(
            opacity: _fadeAnim,
            child: SlideTransition(
              position: _slideAnim,
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: _buildGlassForm(),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildMobileHeader() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 32, 24, 24),
      child: Column(children: [
        const CreannoLogoLight(size: 64),
        const SizedBox(height: 12),
        ShaderMask(
          shaderCallback: (b) => AppGradients.aurora.createShader(b),
          child: const Text(
            'CREANNO',
            style: TextStyle(
                color: Colors.white,
                fontSize: 28,
                fontWeight: FontWeight.w800,
                letterSpacing: 2),
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Your workspace, anywhere',
          style: TextStyle(
              color: Theme.of(context).brightness == Brightness.dark
                  ? Colors.white.withOpacity(0.65)
                  : AppColors.lightTextSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w500),
        ),
      ]),
    );
  }

  Widget _buildBrandPanel() {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Padding(
      padding: const EdgeInsets.all(56),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Spacer(flex: 2),
          const CreannoLogoWide(width: 220),
          const SizedBox(height: 20),
          // Gradient heading
          ShaderMask(
            shaderCallback: (b) => AppGradients.aurora.createShader(b),
            child: const Text(
              'CREANNO',
              style: TextStyle(
                color: Colors.white,
                fontSize: 42,
                fontWeight: FontWeight.w800,
                letterSpacing: 3,
                height: 1.1,
              ),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            'Your all-in-one enterprise workspace.\nManage attendance, tasks, documents\nand reimbursements — from one place.',
            style: TextStyle(
              color: isDark
                  ? AppColors.darkTextSecondary
                  : AppColors.lightTextSecondary,
              fontSize: 15,
              height: 1.75,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 40),
          Wrap(spacing: 10, runSpacing: 10, children: const [
            _FeaturePill(icon: Icons.access_time_rounded,  label: 'Attendance'),
            _FeaturePill(icon: Icons.task_alt_rounded,     label: 'Tasks'),
            _FeaturePill(icon: Icons.receipt_rounded,      label: 'Reimbursements'),
            _FeaturePill(icon: Icons.folder_zip_rounded,   label: 'Documents'),
            _FeaturePill(icon: Icons.people_rounded,       label: 'Team'),
          ]),
          const Spacer(flex: 3),
        ],
      ),
    );
  }

  Widget _buildGlassForm() {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ClipRRect(
      borderRadius: BorderRadius.circular(28),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 24, sigmaY: 24),
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.08),
                      Colors.white.withOpacity(0.04),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : LinearGradient(
                    colors: [
                      Colors.white.withOpacity(0.88),
                      Colors.white.withOpacity(0.65),
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isDark
                  ? Colors.white.withOpacity(0.12)
                  : Colors.white.withOpacity(0.75),
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                  color: AppColors.auroraViolet.withOpacity(0.22),
                  blurRadius: 48,
                  offset: const Offset(0, 16)),
              BoxShadow(
                  color: Colors.black.withOpacity(isDark ? 0.35 : 0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4)),
            ],
          ),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Heading with gradient
                ShaderMask(
                  shaderCallback: (b) => AppGradients.aurora.createShader(b),
                  child: Text(
                    'Welcome back 👋',
                    style: TextStyle(
                      fontSize: Responsive.isDesktop(context) ? 26 : 22,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Sign in with your company email to continue',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondaryOf(context),
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 32),

                // Email label
                Text(
                  'Work Email',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
                const SizedBox(height: 8),

                // Email field
                TextFormField(
                  controller: _emailCtrl,
                  keyboardType: TextInputType.emailAddress,
                  autocorrect: false,
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _sendOTP(),
                  style: TextStyle(color: AppColors.textPrimaryOf(context)),
                  decoration: InputDecoration(
                    hintText: 'you@company.com',
                    prefixIcon: Container(
                      margin: const EdgeInsets.all(10),
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          borderRadius: BorderRadius.circular(10)),
                      child: const Icon(Icons.email_rounded,
                          color: Colors.white, size: 16),
                    ),
                  ),
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'Please enter your email';
                    if (!RegExp(r'^[\w.-]+@[\w.-]+\.\w{2,}$').hasMatch(v))
                      return 'Enter a valid email';
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Send OTP button
                GradientButton(
                  label: 'Send OTP',
                  onPressed: _isLoading ? null : _sendOTP,
                  isLoading: _isLoading,
                  icon: Icons.send_rounded,
                ),
                const SizedBox(height: 24),

                // Info banner
                InfoBanner(
                  message:
                      'A one-time password will be sent to your registered email. No password required.',
                  icon: Icons.shield_rounded,
                  color: AppColors.primary,
                ),
                const SizedBox(height: 28),

                // Footer
                Center(
                  child: Text(
                    'Secure · Encrypted · CREANNO-only access',
                    style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textTertiaryOf(context),
                        letterSpacing: 0.3),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Theme Toggle Pill ────────────────────────────────────────────────────────
class _ThemeTogglePill extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mode = ref.watch(themeModeProvider);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return GestureDetector(
      onTap: () => ref.read(themeModeProvider.notifier).cycle(),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(30),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(colors: [
                      Colors.black.withOpacity(0.45),
                      Colors.black.withOpacity(0.25),
                    ])
                  : LinearGradient(colors: [
                      Colors.white.withOpacity(0.80),
                      Colors.white.withOpacity(0.55),
                    ]),
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: isDark
                    ? Colors.white.withOpacity(0.15)
                    : AppColors.lightBorder.withOpacity(0.7),
                width: 1,
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(mode.icon,
                    size: 15,
                    color: isDark ? AppColors.primaryLight : AppColors.primary),
                const SizedBox(width: 6),
                Text(
                  mode.label,
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: isDark ? AppColors.primaryLight : AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ─── Feature Pill ─────────────────────────────────────────────────────────────
class _FeaturePill extends StatelessWidget {
  final IconData icon;
  final String label;
  const _FeaturePill({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return ClipRRect(
      borderRadius: BorderRadius.circular(30),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(isDark ? 0.10 : 0.55),
            borderRadius: BorderRadius.circular(30),
            border: Border.all(
                color: Colors.white.withOpacity(isDark ? 0.18 : 0.7), width: 1),
          ),
          child: Row(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon,
                color: isDark ? Colors.white : AppColors.primary, size: 14),
            const SizedBox(width: 6),
            Text(label,
                style: TextStyle(
                    color: isDark ? Colors.white : AppColors.lightTextPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600)),
          ]),
        ),
      ),
    );
  }
}
