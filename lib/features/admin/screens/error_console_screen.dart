import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../shared/services/error_log_service.dart';
import '../../../shared/services/ai_service.dart';
import '../../../core/theme.dart';
import '../../../core/ai_config.dart';

// ─── Provider ─────────────────────────────────────────────────────────────────

final errorLogProvider = FutureProvider.autoDispose<List<AppErrorEntry>>((ref) async {
  final errors = await ErrorLogService.getErrors();
  await ErrorLogService.markAllRead();
  return errors;
});

// ══════════════════════════════════════════════════════════════════════════════
//  ERROR CONSOLE SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class ErrorConsoleScreen extends ConsumerWidget {
  const ErrorConsoleScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDark   = Theme.of(context).brightness == Brightness.dark;
    final errAsync = ref.watch(errorLogProvider);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Background
        Positioned.fill(child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: isDark
                  ? [const Color(0xFF070711), const Color(0xFF0D0B1E)]
                  : [const Color(0xFFFFF5F5), const Color(0xFFFFEDED)],
            ),
          ),
        )),
        Positioned(top: -40, right: -40,
          child: _Orb(color: AppColors.error, size: 180)),
        Positioned(bottom: 80, left: -30,
          child: _Orb(color: AppColors.warning, size: 130)),

        Column(children: [
          // Header
          ClipRect(
            child: BackdropFilter(
              filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
              child: Container(
                decoration: BoxDecoration(
                  gradient: isDark
                      ? LinearGradient(colors: [AppColors.error.withOpacity(0.20), AppColors.warning.withOpacity(0.10)])
                      : LinearGradient(colors: [AppColors.error.withOpacity(0.10), AppColors.warning.withOpacity(0.06)]),
                  border: Border(bottom: BorderSide(color: AppColors.error.withOpacity(0.20), width: 1)),
                ),
                child: SafeArea(bottom: false, child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 16),
                  child: Row(children: [
                    GestureDetector(
                      onTap: () => Navigator.of(context).pop(),
                      child: Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(isDark ? 0.10 : 0.60),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: AppColors.error.withOpacity(0.3)),
                        ),
                        child: const Icon(Icons.arrow_back_rounded, size: 18, color: AppColors.error),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Text('🐛 Error Console',
                        style: TextStyle(fontSize: 19, fontWeight: FontWeight.w800, letterSpacing: -0.3)),
                      Text('App-wide error monitoring',
                        style: TextStyle(fontSize: 11, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    ])),
                    // Clear all button
                    errAsync.valueOrNull?.isNotEmpty == true
                        ? GestureDetector(
                            onTap: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (_) => AlertDialog(
                                  title: const Text('Clear All Errors?'),
                                  content: const Text('This will delete all recorded errors. Cannot be undone.'),
                                  actions: [
                                    TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
                                    FilledButton(onPressed: () => Navigator.pop(context, true),
                                      style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                                      child: const Text('Clear All')),
                                  ],
                                ),
                              );
                              if (confirm == true) {
                                await ErrorLogService.clearAll();
                                ref.invalidate(errorLogProvider);
                              }
                            },
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                              decoration: BoxDecoration(
                                color: AppColors.error.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(10),
                                border: Border.all(color: AppColors.error.withOpacity(0.3)),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.delete_outline_rounded, size: 14, color: AppColors.error),
                                SizedBox(width: 4),
                                Text('Clear', style: TextStyle(fontSize: 12, color: AppColors.error, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                          )
                        : const SizedBox.shrink(),
                  ]),
                )),
              ),
            ),
          ),

          // Body
          Expanded(child: errAsync.when(
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('Error loading log: $e')),
            data: (errors) {
              if (errors.isEmpty) return _EmptyConsole(isDark: isDark);

              final active   = errors.where((e) => !e.isResolved).toList();
              final resolved = errors.where((e) => e.isResolved).toList();

              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  // Summary row
                  _SummaryRow(errors: errors, isDark: isDark),
                  const SizedBox(height: 16),

                  // Active errors
                  if (active.isNotEmpty) ...[
                    _GroupHeader('Active Errors', active.length, AppColors.error, isDark),
                    const SizedBox(height: 10),
                    ...active.map((e) => _ErrorCard(entry: e, isDark: isDark,
                      onResolved: () => ref.invalidate(errorLogProvider))),
                    const SizedBox(height: 16),
                  ],

                  // Resolved
                  if (resolved.isNotEmpty) ...[
                    _GroupHeader('Resolved', resolved.length, AppColors.success, isDark),
                    const SizedBox(height: 10),
                    ...resolved.map((e) => _ErrorCard(entry: e, isDark: isDark,
                      onResolved: () => ref.invalidate(errorLogProvider))),
                  ],

                  const SizedBox(height: 80),
                ],
              );
            },
          )),
        ]),
      ]),
    );
  }
}

// ── Summary Row ───────────────────────────────────────────────────────────────
class _SummaryRow extends StatelessWidget {
  final List<AppErrorEntry> errors;
  final bool isDark;
  const _SummaryRow({required this.errors, required this.isDark});

  @override
  Widget build(BuildContext context) {
    final total    = errors.length;
    final active   = errors.where((e) => !e.isResolved).length;
    final resolved = errors.where((e) => e.isResolved).length;
    final cats = <String, int>{};
    for (final e in errors) cats[e.category] = (cats[e.category] ?? 0) + 1;

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(colors: [AppColors.error.withOpacity(0.12), AppColors.warning.withOpacity(0.06)])
                : LinearGradient(colors: [Colors.white.withOpacity(0.85), Colors.white.withOpacity(0.65)]),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.error.withOpacity(0.2)),
          ),
          child: Column(children: [
            Row(children: [
              _StatChip('Total', '$total', AppColors.error, isDark),
              const SizedBox(width: 10),
              _StatChip('Active', '$active', AppColors.warning, isDark),
              const SizedBox(width: 10),
              _StatChip('Resolved', '$resolved', AppColors.success, isDark),
            ]),
            if (cats.isNotEmpty) ...[
              const SizedBox(height: 12),
              Wrap(spacing: 8, runSpacing: 6, children: cats.entries.map((e) => Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Text('${e.key}: ${e.value}',
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: AppColors.primary)),
              )).toList()),
            ],
          ]),
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label, value;
  final Color color;
  final bool isDark;
  const _StatChip(this.label, this.value, this.color, this.isDark);

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 10),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 22, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.75))),
    ]),
  ));
}

// ── Error Card ────────────────────────────────────────────────────────────────
class _ErrorCard extends StatefulWidget {
  final AppErrorEntry entry;
  final bool isDark;
  final VoidCallback onResolved;
  const _ErrorCard({required this.entry, required this.isDark, required this.onResolved});

  @override
  State<_ErrorCard> createState() => _ErrorCardState();
}

class _ErrorCardState extends State<_ErrorCard> {
  bool _expanded    = false;
  bool _aiLoading   = false;
  Map<String, String>? _aiAnalysis;

  Color get _catColor {
    switch (widget.entry.category) {
      case 'api':    return AppColors.auroraCyan;
      case 'ui':     return AppColors.auroraViolet;
      case 'data':   return AppColors.warning;
      default:       return AppColors.error;
    }
  }

  IconData get _catIcon {
    switch (widget.entry.category) {
      case 'api':    return Icons.cloud_off_rounded;
      case 'ui':     return Icons.widgets_rounded;
      case 'data':   return Icons.data_object_rounded;
      default:       return Icons.bug_report_rounded;
    }
  }

  Future<void> _analyzeWithAi() async {
    setState(() => _aiLoading = true);
    final result = await AiService.analyzeError(
      widget.entry.message, widget.entry.stackSummary);
    if (mounted) setState(() { _aiAnalysis = result; _aiLoading = false; });
  }

  @override
  Widget build(BuildContext context) {
    final e       = widget.entry;
    final isDark  = widget.isDark;
    final isResolved = e.isResolved;

    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 12, sigmaY: 12),
          child: Container(
            decoration: BoxDecoration(
              gradient: isDark
                  ? LinearGradient(colors: [Colors.white.withOpacity(0.06), Colors.white.withOpacity(0.02)])
                  : LinearGradient(colors: [Colors.white.withOpacity(0.90), Colors.white.withOpacity(0.70)]),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isResolved
                    ? AppColors.success.withOpacity(0.25)
                    : _catColor.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              // Header row
              GestureDetector(
                onTap: () => setState(() => _expanded = !_expanded),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    // Category icon
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(
                        color: (isResolved ? AppColors.success : _catColor).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: (isResolved ? AppColors.success : _catColor).withOpacity(0.25)),
                      ),
                      child: Icon(isResolved ? Icons.check_circle_rounded : _catIcon,
                        size: 16, color: isResolved ? AppColors.success : _catColor),
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Category badge + time
                      Row(children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                            color: _catColor.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(e.category.toUpperCase(),
                            style: TextStyle(fontSize: 9, fontWeight: FontWeight.w800, color: _catColor, letterSpacing: 0.5)),
                        ),
                        const SizedBox(width: 8),
                        Text(e.timeAgo,
                          style: TextStyle(fontSize: 10,
                              color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                        if (isResolved) ...[
                          const SizedBox(width: 6),
                          const Text('✅ Resolved',
                            style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w600)),
                        ],
                      ]),
                      const SizedBox(height: 5),
                      Text(e.message,
                        maxLines: _expanded ? 10 : 2,
                        overflow: _expanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 12, height: 1.4, fontFamily: 'monospace',
                            color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                    ])),
                    Icon(_expanded ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
                      size: 18, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                  ]),
                ),
              ),

              // Expanded: stack + AI analysis + actions
              if (_expanded) ...[
                if (e.stackSummary.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Colors.black.withOpacity(isDark ? 0.3 : 0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(e.stackSummary,
                      style: TextStyle(fontSize: 10, fontFamily: 'monospace', height: 1.5,
                          color: isDark ? Colors.grey[400] : Colors.grey[700])),
                  ),

                // AI Analysis section
                if (_aiAnalysis != null)
                  Container(
                    margin: const EdgeInsets.fromLTRB(14, 0, 14, 10),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.auroraViolet.withOpacity(isDark ? 0.14 : 0.07),
                        AppColors.auroraCyan.withOpacity(isDark ? 0.08 : 0.04),
                      ]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: AppColors.auroraCyan.withOpacity(0.25)),
                    ),
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      const Row(children: [
                        Text('✨', style: TextStyle(fontSize: 14)),
                        SizedBox(width: 6),
                        Text('AI Analysis', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.auroraCyan)),
                      ]),
                      const SizedBox(height: 10),
                      _AiRow('🔍 Cause', _aiAnalysis!['cause'] ?? '', isDark),
                      const SizedBox(height: 8),
                      _AiRow('🔧 Fix', _aiAnalysis!['fix'] ?? '', isDark),
                      if (_aiAnalysis!['affectedArea'] != null) ...[
                        const SizedBox(height: 8),
                        _AiRow('📍 Area', _aiAnalysis!['affectedArea']!, isDark),
                      ],
                    ]),
                  ),

                // Action buttons
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 0, 14, 14),
                  child: Row(children: [
                    // AI Analyze button
                    if (AiConfig.aiEnabled && _aiAnalysis == null)
                      Expanded(child: GestureDetector(
                        onTap: _aiLoading ? null : _analyzeWithAi,
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            gradient: _aiLoading ? null : AppGradients.aurora,
                            color: _aiLoading ? Colors.grey.withOpacity(0.2) : null,
                            borderRadius: BorderRadius.circular(10),
                          ),
                          child: Center(child: _aiLoading
                            ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Row(mainAxisSize: MainAxisSize.min, children: [
                                Text('✨', style: TextStyle(fontSize: 12)),
                                SizedBox(width: 5),
                                Text('Analyse with AI', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: Colors.white)),
                              ])),
                        ),
                      )),

                    if (AiConfig.aiEnabled && _aiAnalysis == null)
                      const SizedBox(width: 8),

                    // Resolve button
                    if (!isResolved)
                      Expanded(child: GestureDetector(
                        onTap: () async {
                          await ErrorLogService.markResolved(e.id);
                          widget.onResolved();
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.12),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: AppColors.success.withOpacity(0.3)),
                          ),
                          child: const Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                            Icon(Icons.check_rounded, size: 13, color: AppColors.success),
                            SizedBox(width: 5),
                            Text('Mark Resolved', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, color: AppColors.success)),
                          ])),
                        ),
                      )),
                  ]),
                ),
              ],
            ]),
          ),
        ),
      ),
    );
  }
}

class _AiRow extends StatelessWidget {
  final String label, value;
  final bool isDark;
  const _AiRow(this.label, this.value, this.isDark);

  @override
  Widget build(BuildContext context) => Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
    SizedBox(width: 72, child: Text(label,
      style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.auroraCyan))),
    const SizedBox(width: 6),
    Expanded(child: Text(value,
      style: TextStyle(fontSize: 11, height: 1.4,
          color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
  ]);
}

// ── Shared widgets ────────────────────────────────────────────────────────────
class _GroupHeader extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final bool isDark;
  const _GroupHeader(this.title, this.count, this.color, this.isDark);

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 3, height: 16, decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(2))),
    const SizedBox(width: 8),
    Text(title, style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: color)),
    const SizedBox(width: 8),
    Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
      child: Text('$count', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: color)),
    ),
  ]);
}

class _EmptyConsole extends StatelessWidget {
  final bool isDark;
  const _EmptyConsole({required this.isDark});

  @override
  Widget build(BuildContext context) => Center(child: Column(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.10),
          shape: BoxShape.circle,
          border: Border.all(color: AppColors.success.withOpacity(0.25)),
        ),
        child: const Icon(Icons.bug_report_outlined, size: 44, color: AppColors.success),
      ),
      const SizedBox(height: 20),
      const Text('🎉 No errors recorded', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
      const SizedBox(height: 8),
      Text('The app is running clean. Any errors\nwill appear here automatically.',
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 13, color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
    ],
  ));
}

class _Orb extends StatelessWidget {
  final Color color;
  final double size;
  const _Orb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color.withOpacity(0.15), Colors.transparent]),
    ),
  );
}
