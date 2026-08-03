import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/ai_scheduler_service.dart';
import '../../../core/theme.dart';
import '../../../core/ai_config.dart';

// ── Providers for AI Command Center ──────────────────────────────────────────

final _aiTeamProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final resp = await api.get('/employees');
  return resp.data['data'] as List;
});

final _aiTasksProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  try {
    final resp = await api.get('/tasks/assigned');
    return resp.data['data'] as List;
  } catch (_) {
    return [];
  }
});

final _aiOverviewProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  try {
    final resp = await api.get('/dashboard/admin');
    return resp.data['data'] as Map<String, dynamic>;
  } catch (_) {
    return {};
  }
});

// ══════════════════════════════════════════════════════════════════════════════
//  AI COMMAND CENTER SCREEN
// ══════════════════════════════════════════════════════════════════════════════

class AiCommandCenterScreen extends ConsumerStatefulWidget {
  const AiCommandCenterScreen({super.key});

  @override
  ConsumerState<AiCommandCenterScreen> createState() =>
      _AiCommandCenterScreenState();
}

class _AiCommandCenterScreenState extends ConsumerState<AiCommandCenterScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabCtrl;

  static const _tabs = [
    (icon: Icons.auto_awesome_rounded,   label: 'Auto-Assign'),
    (icon: Icons.calendar_today_rounded, label: 'Daily Planner'),
    (icon: Icons.notifications_active_rounded, label: 'Smart Alerts'),
  ];

  @override
  void initState() {
    super.initState();
    _tabCtrl = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(children: [
        // Aurora background
        Positioned.fill(
          child: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: isDark
                    ? [const Color(0xFF070711), const Color(0xFF0D0B1E)]
                    : [const Color(0xFFF5F3FF), const Color(0xFFEDE9FE)],
              ),
            ),
          ),
        ),
        // Orbs
        Positioned(top: -60, left: -60, child: _AuroraOrb(color: AppColors.auroraViolet, size: 220)),
        Positioned(bottom: 100, right: -40, child: _AuroraOrb(color: AppColors.auroraCyan, size: 160)),
        Positioned(top: 200, right: 30, child: _AuroraOrb(color: AppColors.auroraPink.withOpacity(0.4), size: 100)),

        // Content
        Column(children: [
          _buildHeader(isDark),
          Expanded(
            child: TabBarView(
              controller: _tabCtrl,
              children: const [
                _AutoAssignTab(),
                _DailyPlannerTab(),
                _SmartAlertsTab(),
              ],
            ),
          ),
        ]),
      ]),
    );
  }

  Widget _buildHeader(bool isDark) {
    return ClipRect(
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 20, sigmaY: 20),
        child: Container(
          decoration: BoxDecoration(
            gradient: isDark
                ? LinearGradient(colors: [
                    AppColors.auroraViolet.withOpacity(0.25),
                    AppColors.auroraIndigo.withOpacity(0.15),
                  ])
                : LinearGradient(colors: [
                    AppColors.auroraViolet.withOpacity(0.12),
                    AppColors.auroraCyan.withOpacity(0.08),
                  ]),
            border: Border(
              bottom: BorderSide(
                color: AppColors.auroraCyan.withOpacity(0.25),
                width: 1,
              ),
            ),
          ),
          child: SafeArea(
            bottom: false,
            child: Column(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
                child: Row(children: [
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () => Navigator.of(context).pop(),
                      borderRadius: BorderRadius.circular(10),
                      child: Semantics(
                        button: true,
                        label: 'Back',
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(isDark ? 0.10 : 0.60),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                              color: AppColors.auroraCyan.withOpacity(0.3),
                            ),
                          ),
                          child: Icon(Icons.arrow_back_rounded,
                              size: 18,
                              color: isDark ? AppColors.primaryLight : AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      ShaderMask(
                        shaderCallback: (b) => AppGradients.aurora.createShader(b),
                        child: const Text('✨ AI Command Center',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                            letterSpacing: -0.3,
                          )),
                      ),
                      Text(
                        AiConfig.isReady
                            ? 'Powered by Gemini 1.5 Flash'
                            : '⚠️  Add API key in ai_config.dart to activate',
                        style: TextStyle(
                          fontSize: 11,
                          color: AiConfig.isReady
                              ? AppColors.auroraCyan
                              : AppColors.warning,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ]),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [
                        AppColors.auroraViolet.withOpacity(0.7),
                        AppColors.auroraCyan.withOpacity(0.6),
                      ]),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: const Text('ADMIN',
                      style: TextStyle(
                        fontSize: 10, fontWeight: FontWeight.w800,
                        color: Colors.white, letterSpacing: 1,
                      )),
                  ),
                ]),
              ),
              const SizedBox(height: 10),
              TabBar(
                controller: _tabCtrl,
                isScrollable: true,
                tabAlignment: TabAlignment.start,
                padding: const EdgeInsets.symmetric(horizontal: 16),
                indicatorColor: AppColors.auroraCyan,
                indicatorWeight: 2.5,
                labelColor: AppColors.auroraCyan,
                unselectedLabelColor: isDark
                    ? AppColors.darkTextSecondary
                    : AppColors.lightTextSecondary,
                labelStyle:
                    const TextStyle(fontWeight: FontWeight.w700, fontSize: 12),
                dividerColor: Colors.transparent,
                tabs: _tabs.map((t) => Tab(
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.icon, size: 15),
                    const SizedBox(width: 6),
                    Text(t.label),
                  ]),
                )).toList(),
              ),
              const SizedBox(height: 4),
            ]),
          ),
        ),
      ),
    );
  }
}

// ── Shimmer skeleton box (reused across all three tabs) ─────────────────────
class _ShimmerBox extends StatefulWidget {
  final double width;
  final double height;
  final double radius;
  const _ShimmerBox({required this.width, required this.height, this.radius = 8});
  @override
  State<_ShimmerBox> createState() => _ShimmerBoxState();
}

class _ShimmerBoxState extends State<_ShimmerBox>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;
  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200))
      ..repeat(reverse: true);
  }
  @override
  void dispose() { _ctrl.dispose(); super.dispose(); }
  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = isDark ? Colors.white.withOpacity(0.05) : Colors.black.withOpacity(0.05);
    final hi   = isDark ? Colors.white.withOpacity(0.12) : Colors.black.withOpacity(0.10);
    return AnimatedBuilder(
      animation: _ctrl,
      builder: (_, __) => Container(
        width: widget.width, height: widget.height,
        decoration: BoxDecoration(
          color: Color.lerp(base, hi, _ctrl.value),
          borderRadius: BorderRadius.circular(widget.radius),
        ),
      ),
    );
  }
}

// ── Fade+slide-up stagger for list reveal ───────────────────────────────────
class _FadeSlideIn extends StatelessWidget {
  final int index;
  final Widget child;
  const _FadeSlideIn({required this.index, required this.child});
  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Duration(milliseconds: 300 + (index * 60)),
      curve: Curves.easeOutCubic,
      builder: (_, v, ch) => Opacity(
        opacity: v,
        child: Transform.translate(offset: Offset(0, (1 - v) * 12), child: ch),
      ),
      child: child,
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 1 — AI TASK AUTO-ASSIGNMENT
// ══════════════════════════════════════════════════════════════════════════════

class _AutoAssignTab extends ConsumerStatefulWidget {
  const _AutoAssignTab();

  @override
  ConsumerState<_AutoAssignTab> createState() => _AutoAssignTabState();
}

class _AutoAssignTabState extends ConsumerState<_AutoAssignTab> {
  final _taskCtrl = TextEditingController();
  String _taskType = 'task';
  String _priority = 'medium';
  DateTime? _deadline;
  bool _loading = false;
  List<AiAssignment> _results = [];
  String? _assignedTo;
  String? _error;
  bool _noTeam = false;

  static const _types = [
    ('task', 'Task', Icons.task_alt_rounded),
    ('meeting', 'Meeting', Icons.video_call_rounded),
    ('content', 'Content', Icons.article_rounded),
    ('milestone', 'Milestone', Icons.flag_rounded),
    ('project', 'Project', Icons.folder_rounded),
  ];

  static const _priorities = [
    ('low', 'Low', AppColors.success),
    ('medium', 'Medium', AppColors.primary),
    ('high', 'High', AppColors.warning),
    ('urgent', 'Urgent', AppColors.error),
  ];

  @override
  void dispose() {
    _taskCtrl.dispose();
    super.dispose();
  }

  Future<void> _findBestAssignee() async {
    if (_taskCtrl.text.trim().isEmpty) return;
    setState(() { _loading = true; _results = []; _error = null; _assignedTo = null; _noTeam = false; });

    final teamAsync = ref.read(_aiTeamProvider);
    final team = teamAsync.valueOrNull ?? [];

    if (team.isEmpty) {
      setState(() { _loading = false; _noTeam = true; });
      return;
    }

    // Add mock task count hint (in real scenario, we'd fetch from tasks API)
    final teamWithCount = team.map((m) {
      final map = Map<String, dynamic>.from(m as Map);
      map['_taskCount'] = (map['_taskCount'] as int?) ?? 0;
      return map;
    }).toList();

    final results = await AiSchedulerService.suggestAssignment(
      taskTitle: _taskCtrl.text.trim(),
      taskType: _taskType,
      priority: _priority,
      deadline: _deadline != null ? DateFormat('d MMM yyyy').format(_deadline!) : null,
      teamMembers: teamWithCount,
    );

    if (mounted) {
      setState(() {
        _results = results;
        _loading = false;
        if (results.isEmpty) _error = 'No suggestions. Check your API key.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Task Input Card ──────────────────────────────────────────────────
        _GlassCard(
          isDark: isDark,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CardHeader(
              icon: Icons.auto_awesome_rounded,
              title: 'Describe the Task',
              subtitle: 'AI will find the best person for it',
              color: AppColors.auroraViolet,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _taskCtrl,
              maxLines: 2,
              decoration: InputDecoration(
                hintText: 'e.g. "Create Instagram reels for Diwali campaign" or "Client presentation for TechBridge"',
                hintStyle: TextStyle(fontSize: 12,
                    color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.auroraViolet, width: 1.5),
                ),
                contentPadding: const EdgeInsets.all(12),
                filled: true,
                fillColor: isDark ? Colors.black.withOpacity(0.2) : Colors.white.withOpacity(0.7),
              ),
            ),
            const SizedBox(height: 14),

            // Type selector
            _SectionLabel('Task Type', isDark),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: _types.map((t) {
              final sel = _taskType == t.$1;
              return GestureDetector(
                onTap: () => setState(() => _taskType = t.$1),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                  decoration: BoxDecoration(
                    gradient: sel ? AppGradients.aurora : null,
                    color: sel ? null : (isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.65)),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: sel ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.12) : AppColors.lightBorder),
                    ),
                    boxShadow: sel ? AppGlass.violetGlow(intensity: 0.25) : null,
                  ),
                  child: Row(mainAxisSize: MainAxisSize.min, children: [
                    Icon(t.$3, size: 13, color: sel ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(width: 5),
                    Text(t.$2, style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
                  ]),
                ),
              );
            }).toList()),
            const SizedBox(height: 14),

            // Priority + Deadline row
            Row(children: [
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                _SectionLabel('Priority', isDark),
                const SizedBox(height: 8),
                Wrap(spacing: 6, runSpacing: 6, children: _priorities.map((p) {
                  final sel = _priority == p.$1;
                  return GestureDetector(
                    onTap: () => setState(() => _priority = p.$1),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                      decoration: BoxDecoration(
                        color: sel ? p.$3.withOpacity(0.2) : Colors.transparent,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: sel ? p.$3 : (isDark ? Colors.white.withOpacity(0.12) : AppColors.lightBorder)),
                      ),
                      child: Text(p.$2, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: sel ? p.$3 : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary))),
                    ),
                  );
                }).toList()),
              ])),
              const SizedBox(width: 14),
              GestureDetector(
                onTap: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: DateTime.now().add(const Duration(days: 3)),
                    firstDate: DateTime.now(),
                    lastDate: DateTime.now().add(const Duration(days: 365)),
                  );
                  if (d != null) setState(() => _deadline = d);
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                  decoration: BoxDecoration(
                    color: _deadline != null
                        ? AppColors.auroraViolet.withOpacity(0.12)
                        : (isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.7)),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _deadline != null
                          ? AppColors.auroraViolet.withOpacity(0.4)
                          : (isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder),
                    ),
                  ),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(Icons.event_rounded, size: 18, color: _deadline != null ? AppColors.auroraViolet : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: 4),
                    Text(
                      _deadline != null ? DateFormat('d MMM').format(_deadline!) : 'Deadline',
                      style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600,
                          color: _deadline != null ? AppColors.auroraViolet : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    ),
                  ]),
                ),
              ),
            ]),
            const SizedBox(height: 16),

            // Find button
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                onTap: _loading ? null : _findBestAssignee,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _loading ? null : AppGradients.aurora,
                    color: _loading ? Colors.grey.withOpacity(0.3) : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _loading ? null : AppGlass.violetGlow(intensity: 0.4),
                  ),
                  child: Center(child: _loading
                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('AI is analysing team...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ])
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                        SizedBox(width: 8),
                        Text('🎯  Find Best Team Member', style: TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      ])),
                ),
                ),
              ),
            ),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.error.withOpacity(0.25)),
            ),
            child: Row(children: [
              const Icon(Icons.error_outline, color: AppColors.error, size: 16),
              const SizedBox(width: 8),
              Expanded(child: Text(_error!, style: const TextStyle(fontSize: 12, color: AppColors.error))),
            ]),
          ),
        ],

        if (_noTeam) ...[
          const SizedBox(height: 16),
          const _NoTeamEmptyState(),
        ],

        // ── Ghost skeletons while loading ────────────────────────────────────
        if (_loading) ...[
          const SizedBox(height: 16),
          _GlassCard(
            isDark: isDark,
            child: Column(children: List.generate(3, (_) => Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(children: [
                const _ShimmerBox(width: 38, height: 38, radius: 19),
                const SizedBox(width: 10),
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: const [
                  _ShimmerBox(width: 120, height: 14),
                  SizedBox(height: 6),
                  _ShimmerBox(width: 80, height: 10),
                ]),
                const Spacer(),
                const _ShimmerBox(width: 50, height: 22),
              ]),
            ))),
          ),
        ],

        // ── Results ──────────────────────────────────────────────────────────
        if (_results.isNotEmpty) ...[
          const SizedBox(height: 16),
          _GlassCard(
            isDark: isDark,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CardHeader(
                icon: Icons.people_rounded,
                title: 'AI Recommendations',
                subtitle: '${_results.length} team members ranked by suitability',
                color: AppColors.auroraCyan,
              ),
              const SizedBox(height: 14),
              ..._results.asMap().entries.map((entry) {
                final i = entry.key;
                final r = entry.value;
                final isTop = i == 0;
                final isAssigned = _assignedTo == r.memberId;
                final availColor = r.availability == 'Available'
                    ? AppColors.success
                    : r.availability == 'Moderate'
                        ? AppColors.warning
                        : AppColors.error;

                return _FadeSlideIn(index: i, child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    gradient: isTop
                        ? LinearGradient(colors: [
                            AppColors.auroraViolet.withOpacity(isDark ? 0.15 : 0.08),
                            AppColors.auroraCyan.withOpacity(isDark ? 0.08 : 0.04),
                          ])
                        : null,
                    color: isTop ? null : (isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.6)),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: isTop
                          ? AppColors.auroraViolet.withOpacity(0.35)
                          : (isDark ? Colors.white.withOpacity(0.08) : AppColors.lightBorder.withOpacity(0.6)),
                      width: isTop ? 1.5 : 1,
                    ),
                  ),
                  child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Row(children: [
                      // Rank badge
                      Container(
                        width: 30, height: 30,
                        decoration: BoxDecoration(
                          gradient: isTop ? AppGradients.aurora : null,
                          color: isTop ? null : (isDark ? Colors.white.withOpacity(0.08) : Colors.grey.withOpacity(0.12)),
                          shape: BoxShape.circle,
                        ),
                        child: Center(child: Text('${i + 1}',
                          style: TextStyle(fontSize: 13, fontWeight: FontWeight.w900,
                              color: isTop ? Colors.white : (isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)))),
                      ),
                      const SizedBox(width: 10),
                      // Avatar
                      Container(
                        width: 38, height: 38,
                        decoration: BoxDecoration(
                          gradient: AppGradients.primary,
                          shape: BoxShape.circle,
                          boxShadow: isTop ? AppGlass.violetGlow(intensity: 0.25) : null,
                        ),
                        child: Center(child: Text(
                          r.memberName.isNotEmpty ? r.memberName[0].toUpperCase() : '?',
                          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15),
                        )),
                      ),
                      const SizedBox(width: 10),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Text(r.memberName,
                            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700,
                                color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                          if (isTop) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                              decoration: BoxDecoration(
                                gradient: AppGradients.aurora,
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Text('Best Match', style: TextStyle(fontSize: 9, color: Colors.white, fontWeight: FontWeight.w800)),
                            ),
                          ],
                        ]),
                        Text(r.role.toUpperCase(),
                          style: TextStyle(fontSize: 10, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary, fontWeight: FontWeight.w600, letterSpacing: 0.3)),
                      ])),
                      Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                        Text('${r.score.round()}%',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900,
                              color: r.score >= 80 ? AppColors.success : r.score >= 60 ? AppColors.warning : AppColors.error)),
                        Text('match', style: TextStyle(fontSize: 9, color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                      ]),
                    ]),
                    const SizedBox(height: 10),

                    // Score bar
                    ClipRRect(
                      borderRadius: BorderRadius.circular(3),
                      child: LinearProgressIndicator(
                        value: r.score / 100,
                        minHeight: 4,
                        backgroundColor: isDark ? Colors.white.withOpacity(0.08) : Colors.black.withOpacity(0.06),
                        valueColor: AlwaysStoppedAnimation(
                          r.score >= 80 ? AppColors.success : r.score >= 60 ? AppColors.warning : AppColors.error,
                        ),
                      ),
                    ),
                    const SizedBox(height: 10),

                    // Tags + Reason
                    Wrap(spacing: 6, runSpacing: 6, children: [
                      _Tag(label: r.availability, color: availColor),
                      _Tag(label: '${r.currentTasks} tasks', color: AppColors.primary),
                    ]),
                    const SizedBox(height: 8),
                    Text('💡 ${r.reason}',
                      style: TextStyle(fontSize: 11, height: 1.4,
                          color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                    const SizedBox(height: 12),

                    // Assign button
                    GestureDetector(
                      onTap: () => setState(() => _assignedTo = isAssigned ? null : r.memberId),
                      child: Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(vertical: 10),
                        decoration: BoxDecoration(
                          gradient: isAssigned ? null : (isTop ? AppGradients.aurora : null),
                          color: isAssigned
                              ? AppColors.success.withOpacity(0.15)
                              : (!isTop ? (isDark ? Colors.white.withOpacity(0.08) : Colors.white.withOpacity(0.7)) : null),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: isAssigned ? AppColors.success.withOpacity(0.5) : Colors.transparent,
                          ),
                        ),
                        child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                          Icon(isAssigned ? Icons.check_circle_rounded : Icons.person_add_rounded,
                            color: isAssigned ? AppColors.success : (isTop ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                            size: 15),
                          const SizedBox(width: 6),
                          Text(isAssigned ? 'Assigned ✅' : 'Assign to ${r.memberName.split(' ').first}',
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: isAssigned ? AppColors.success : (isTop ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)))),
                        ])),
                      ),
                    ),
                  ]),
                ));
              }),
            ]),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 2 — AI DAILY PLANNER
// ══════════════════════════════════════════════════════════════════════════════

class _DailyPlannerTab extends ConsumerStatefulWidget {
  const _DailyPlannerTab();

  @override
  ConsumerState<_DailyPlannerTab> createState() => _DailyPlannerTabState();
}

class _DailyPlannerTabState extends ConsumerState<_DailyPlannerTab> {
  Map<String, dynamic>? _selectedMember;
  DateTime _date     = DateTime.now();
  bool _loading      = false;
  List<AiScheduleBlock> _schedule = [];
  String? _error;

  Color _typeColor(String type) {
    switch (type) {
      case 'focus':    return AppColors.auroraViolet;
      case 'meeting':  return AppColors.auroraCyan;
      case 'review':   return AppColors.warning;
      case 'break':    return AppColors.success;
      case 'admin':    return AppColors.textSecondaryOf(context);
      case 'planning': return AppColors.auroraPink;
      default:         return AppColors.primary;
    }
  }

  IconData _typeIcon(String type) {
    switch (type) {
      case 'focus':    return Icons.bolt_rounded;
      case 'meeting':  return Icons.video_call_rounded;
      case 'review':   return Icons.rate_review_rounded;
      case 'break':    return Icons.coffee_rounded;
      case 'admin':    return Icons.inbox_rounded;
      case 'planning': return Icons.map_rounded;
      default:         return Icons.task_alt_rounded;
    }
  }

  Future<void> _generateSchedule() async {
    if (_selectedMember == null) return;
    setState(() { _loading = true; _schedule = []; _error = null; });

    final m = _selectedMember!;
    final schedule = await AiSchedulerService.generateDailySchedule(
      memberName:     '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim(),
      role:           m['role']?.toString() ?? 'employee',
      designation:    m['designation']?.toString() ?? m['department']?.toString() ?? '',
      date:           _date,
      pendingTaskTitles: [],
      meetingCount:   0,
      workStartTime:  '09:00',
    );

    if (mounted) {
      setState(() {
        _schedule = schedule;
        _loading  = false;
        if (schedule.isEmpty) _error = 'Could not generate schedule. Check your API key.';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark    = Theme.of(context).brightness == Brightness.dark;
    final teamAsync = ref.watch(_aiTeamProvider);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Controls Card ────────────────────────────────────────────────────
        _GlassCard(
          isDark: isDark,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CardHeader(
              icon: Icons.calendar_today_rounded,
              title: 'AI Daily Work Planner',
              subtitle: 'Generate a time-blocked day schedule',
              color: AppColors.auroraCyan,
            ),
            const SizedBox(height: 16),

            // Team member picker
            _SectionLabel('Select Team Member', isDark),
            const SizedBox(height: 8),
            teamAsync.when(
              loading: () => const Center(child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
              error: (e, _) => Text('Error: $e', style: const TextStyle(color: AppColors.error, fontSize: 12)),
              data: (team) => team.isEmpty
                ? const _NoTeamEmptyState()
                : Wrap(
                spacing: 8, runSpacing: 8,
                children: team.cast<Map<String, dynamic>>().map((m) {
                  final name = '${m['firstName'] ?? ''} ${m['lastName'] ?? ''}'.trim();
                  final isSel = _selectedMember?['id'] == m['id'];
                  return GestureDetector(
                    onTap: () => setState(() => _selectedMember = m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 180),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        gradient: isSel ? AppGradients.aurora : null,
                        color: isSel ? null : (isDark ? Colors.white.withOpacity(0.07) : Colors.white.withOpacity(0.65)),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSel ? Colors.transparent : (isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder)),
                        boxShadow: isSel ? AppGlass.violetGlow(intensity: 0.25) : null,
                      ),
                      child: Row(mainAxisSize: MainAxisSize.min, children: [
                        Container(
                          width: 22, height: 22,
                          decoration: BoxDecoration(
                            color: isSel ? Colors.white.withOpacity(0.25) : AppColors.primary.withOpacity(0.15),
                            shape: BoxShape.circle,
                          ),
                          child: Center(child: Text(name.isNotEmpty ? name[0] : '?',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800,
                                color: isSel ? Colors.white : AppColors.primary))),
                        ),
                        const SizedBox(width: 6),
                        Text(name.split(' ').first,
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600,
                              color: isSel ? Colors.white : (isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
                      ]),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 14),

            // Date picker
            GestureDetector(
              onTap: () async {
                final d = await showDatePicker(
                  context: context,
                  initialDate: _date,
                  firstDate: DateTime.now().subtract(const Duration(days: 1)),
                  lastDate: DateTime.now().add(const Duration(days: 30)),
                );
                if (d != null) setState(() { _date = d; _schedule = []; });
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withOpacity(0.06) : Colors.white.withOpacity(0.7),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder),
                ),
                child: Row(children: [
                  const Icon(Icons.event_rounded, size: 16, color: AppColors.auroraCyan),
                  const SizedBox(width: 10),
                  Text(DateFormat('EEEE, d MMMM yyyy').format(_date),
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w600,
                        color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                  const Spacer(),
                  Icon(Icons.edit_calendar_rounded, size: 14,
                      color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary),
                ]),
              ),
            ),
            const SizedBox(height: 16),

            // Generate button
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                onTap: _loading || _selectedMember == null ? null : _generateSchedule,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: (_loading || _selectedMember == null) ? null : AppGradients.aurora,
                    color: (_loading || _selectedMember == null) ? Colors.grey.withOpacity(0.25) : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: (_loading || _selectedMember == null) ? null : AppGlass.violetGlow(intensity: 0.4),
                  ),
                  child: Center(child: _loading
                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Generating schedule...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_fix_high_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(
                          _selectedMember == null
                              ? '📅  Select a team member first'
                              : '📅  Generate Day Schedule for ${(_selectedMember!['firstName'] ?? '').toString().split(' ').first}',
                          style: TextStyle(
                            color: _selectedMember == null ? Colors.white.withOpacity(0.5) : Colors.white,
                            fontSize: 13, fontWeight: FontWeight.w800),
                        ),
                      ])),
                ),
                ),
              ),
            ),
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(_error!),
        ],

        if (_loading) ...[
          const SizedBox(height: 16),
          _GlassCard(
            isDark: isDark,
            child: Column(children: List.generate(4, (_) => const Padding(
              padding: EdgeInsets.only(bottom: 10),
              child: _ShimmerBox(width: double.infinity, height: 60, radius: 12),
            ))),
          ),
        ],

        // ── Schedule Timeline ────────────────────────────────────────────────
        if (_schedule.isNotEmpty) ...[
          const SizedBox(height: 16),
          _GlassCard(
            isDark: isDark,
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              _CardHeader(
                icon: Icons.schedule_rounded,
                title: 'Day Schedule — ${_selectedMember?['firstName'] ?? ''}',
                subtitle: DateFormat('EEEE, d MMMM').format(_date),
                color: AppColors.auroraCyan,
              ),
              const SizedBox(height: 16),

              // Total hours summary
              Row(children: [
                _SmallStat(label: 'Blocks', value: '${_schedule.length}', color: AppColors.auroraViolet),
                const SizedBox(width: 12),
                _SmallStat(
                  label: 'Total Hours',
                  value: '${(_schedule.fold<int>(0, (s, b) => s + b.durationMins) / 60).toStringAsFixed(1)}h',
                  color: AppColors.auroraCyan,
                ),
                const SizedBox(width: 12),
                _SmallStat(
                  label: 'Focus Time',
                  value: '${(_schedule.where((b) => b.type == 'focus').fold<int>(0, (s, b) => s + b.durationMins) / 60).toStringAsFixed(1)}h',
                  color: AppColors.success,
                ),
              ]),
              const SizedBox(height: 16),

              // Timeline blocks
              ..._schedule.asMap().entries.map((entry) {
                final i = entry.key;
                final block = entry.value;
                final color = _typeColor(block.type);
                final isLast = i == _schedule.length - 1;

                return _FadeSlideIn(index: i, child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  // Time column
                  SizedBox(
                    width: 72,
                    child: Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                      Text(block.startTime,
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                            color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                      Text('${block.durationMins}m',
                        style: TextStyle(fontSize: 9,
                            color: isDark ? AppColors.darkTextTertiary : AppColors.lightTextTertiary)),
                    ]),
                  ),
                  const SizedBox(width: 12),

                  // Connector line + dot
                  Column(children: [
                    Container(
                      width: 12, height: 12,
                      decoration: BoxDecoration(
                        gradient: LinearGradient(colors: [color, color.withOpacity(0.6)]),
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 6)],
                      ),
                    ),
                    if (!isLast)
                      Container(
                        width: 2, height: block.durationMins < 30 ? 50 : 70,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [color.withOpacity(0.5), color.withOpacity(0.05)],
                          ),
                        ),
                      ),
                  ]),
                  const SizedBox(width: 12),

                  // Block content
                  Expanded(
                    child: Padding(
                      padding: EdgeInsets.only(bottom: isLast ? 0 : 16),
                      child: Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          gradient: block.type == 'focus'
                              ? LinearGradient(colors: [color.withOpacity(isDark ? 0.14 : 0.07), color.withOpacity(isDark ? 0.06 : 0.03)])
                              : null,
                          color: block.type != 'focus'
                              ? (isDark ? Colors.white.withOpacity(0.04) : Colors.white.withOpacity(0.65))
                              : null,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(
                            color: block.type == 'focus' ? color.withOpacity(0.3) : (isDark ? Colors.white.withOpacity(0.07) : AppColors.lightBorder.withOpacity(0.5)),
                            width: block.type == 'focus' ? 1.5 : 1,
                          ),
                        ),
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Row(children: [
                            Container(
                              padding: const EdgeInsets.all(5),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.15),
                                borderRadius: BorderRadius.circular(7),
                              ),
                              child: Icon(_typeIcon(block.type), size: 13, color: color),
                            ),
                            const SizedBox(width: 8),
                            Expanded(child: Text(block.title,
                              style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                                  color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary))),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                              decoration: BoxDecoration(
                                color: color.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(block.type.toUpperCase(),
                                style: TextStyle(fontSize: 9, fontWeight: FontWeight.w700, color: color)),
                            ),
                          ]),
                          if (block.notes.isNotEmpty) ...[
                            const SizedBox(height: 6),
                            Text(block.notes,
                              style: TextStyle(fontSize: 11, height: 1.4,
                                  color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary)),
                          ],
                          const SizedBox(height: 6),
                          Text('${block.startTime} → ${block.endTime}',
                            style: TextStyle(fontSize: 10, fontWeight: FontWeight.w600, color: color.withOpacity(0.8))),
                        ]),
                      ),
                    ),
                  ),
                ]));
              }),
            ]),
          ),
        ],
        const SizedBox(height: 80),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TAB 3 — AI SMART ALERTS / NOTIFICATIONS
// ══════════════════════════════════════════════════════════════════════════════

class _SmartAlertsTab extends ConsumerStatefulWidget {
  const _SmartAlertsTab();

  @override
  ConsumerState<_SmartAlertsTab> createState() => _SmartAlertsTabState();
}

class _SmartAlertsTabState extends ConsumerState<_SmartAlertsTab> {
  bool _loading = false;
  List<AiAlert> _alerts = [];
  Set<int> _sentAlerts  = {};
  String? _error;
  bool _allClear = false;

  Color _urgencyColor(String u) {
    switch (u) {
      case 'critical': return AppColors.error;
      case 'warning':  return AppColors.warning;
      default:         return AppColors.auroraCyan;
    }
  }

  IconData _urgencyIcon(String u) {
    switch (u) {
      case 'critical': return Icons.emergency_rounded;
      case 'warning':  return Icons.warning_amber_rounded;
      default:         return Icons.info_rounded;
    }
  }

  Future<void> _generateAlerts() async {
    setState(() { _loading = true; _alerts = []; _sentAlerts = {}; _error = null; _allClear = false; });

    final teamAsync     = ref.read(_aiTeamProvider);
    final overviewAsync = ref.read(_aiOverviewProvider);

    final team     = teamAsync.valueOrNull?.cast<Map<String, dynamic>>() ?? [];
    final overview = overviewAsync.valueOrNull ?? {};

    List<AiAlert> alerts = [];
    Object? failure;
    try {
      alerts = await AiSchedulerService.generateSmartAlerts(
        teamMembers:      team,
        totalPendingTasks: (overview['pendingTasks'] as num?)?.toInt() ?? 0,
        overdueTasks:     (overview['overdueTasks'] as num?)?.toInt() ?? 0,
        pendingClaims:    (overview['pendingReimbursements'] as num?)?.toInt() ?? 0,
        absentToday:      (overview['absentToday'] as num?)?.toInt() ?? 0,
        teamSize:         team.length,
        upcomingDeadlines: [],
      );
    } catch (e) {
      failure = e;
    }

    if (mounted) {
      setState(() {
        _alerts  = alerts;
        _loading = false;
        if (failure != null) {
          _error = 'Could not generate alerts. Check your API key.';
        } else if (alerts.isEmpty) {
          _allClear = true;
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final criticalCount = _alerts.where((a) => a.urgency == 'critical').length;
    final warningCount  = _alerts.where((a) => a.urgency == 'warning').length;
    final infoCount     = _alerts.where((a) => a.urgency == 'info').length;
    final unsentCount   = _alerts.length - _sentAlerts.length;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Generate Card ────────────────────────────────────────────────────
        _GlassCard(
          isDark: isDark,
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            _CardHeader(
              icon: Icons.notifications_active_rounded,
              title: 'AI Smart Notifications',
              subtitle: 'Analyse team and generate actionable alerts',
              color: AppColors.auroraPink,
            ),
            const SizedBox(height: 14),

            // Stats row (if alerts generated)
            if (_alerts.isNotEmpty) ...[
              Row(children: [
                _SmallStat(label: 'Critical', value: '$criticalCount', color: AppColors.error),
                const SizedBox(width: 10),
                _SmallStat(label: 'Warnings', value: '$warningCount', color: AppColors.warning),
                const SizedBox(width: 10),
                _SmallStat(label: 'Info', value: '$infoCount', color: AppColors.auroraCyan),
                const SizedBox(width: 10),
                _SmallStat(label: 'Unsent', value: '$unsentCount', color: AppColors.auroraViolet),
              ]),
              const SizedBox(height: 14),
            ],

            // Generate button
            SizedBox(
              width: double.infinity,
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                onTap: _loading ? null : _generateAlerts,
                borderRadius: BorderRadius.circular(14),
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  decoration: BoxDecoration(
                    gradient: _loading ? null : AppGradients.aurora,
                    color: _loading ? Colors.grey.withOpacity(0.25) : null,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: _loading ? null : AppGlass.violetGlow(intensity: 0.4),
                  ),
                  child: Center(child: _loading
                    ? const Row(mainAxisSize: MainAxisSize.min, children: [
                        SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                        SizedBox(width: 10),
                        Text('Analysing team...', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
                      ])
                    : Row(mainAxisSize: MainAxisSize.min, children: [
                        const Icon(Icons.auto_awesome_rounded, color: Colors.white, size: 16),
                        const SizedBox(width: 8),
                        Text(_alerts.isEmpty ? '🔔  Analyse Team & Generate Alerts' : '🔄  Regenerate Alerts',
                          style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w800)),
                      ])),
                ),
                ),
              ),
            ),

            // Send all button
            if (_alerts.isNotEmpty && unsentCount > 0) ...[
              const SizedBox(height: 10),
              GestureDetector(
                onTap: () => setState(() => _sentAlerts = Set.from(List.generate(_alerts.length, (i) => i))),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.success.withOpacity(0.3)),
                  ),
                  child: Center(child: Row(mainAxisSize: MainAxisSize.min, children: [
                    const Icon(Icons.send_rounded, color: AppColors.success, size: 15),
                    const SizedBox(width: 8),
                    Text('Send All $unsentCount Alert${unsentCount == 1 ? '' : 's'} to Team',
                      style: const TextStyle(color: AppColors.success, fontWeight: FontWeight.w700, fontSize: 13)),
                  ])),
                ),
              ),
            ],
          ]),
        ),

        if (_error != null) ...[
          const SizedBox(height: 12),
          _ErrorBanner(_error!),
        ],

        if (_loading) ...[
          const SizedBox(height: 16),
          ...List.generate(3, (_) => const Padding(
            padding: EdgeInsets.only(bottom: 10),
            child: _ShimmerBox(width: double.infinity, height: 72, radius: 16),
          )),
        ],

        if (_allClear) ...[
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.success.withOpacity(0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.success.withOpacity(0.35)),
            ),
            child: Row(children: [
              const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text('All clear — nothing needs attention today',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700,
                      color: AppColors.textPrimaryOf(context)))),
            ]),
          ),
        ],

        // ── Alerts List ──────────────────────────────────────────────────────
        if (_alerts.isNotEmpty) ...[
          const SizedBox(height: 16),
          // Group by urgency
          ...['critical', 'warning', 'info'].expand((urgency) {
            final group = _alerts.asMap().entries.where((e) => e.value.urgency == urgency).toList();
            if (group.isEmpty) return <Widget>[];

            final urgColor = _urgencyColor(urgency);
            return [
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(children: [
                  Container(width: 3, height: 16,
                    decoration: BoxDecoration(color: urgColor, borderRadius: BorderRadius.circular(2))),
                  const SizedBox(width: 8),
                  Text(urgency == 'critical' ? '🚨 Critical' : urgency == 'warning' ? '⚠️ Warnings' : 'ℹ️ Info',
                    style: TextStyle(fontSize: 13, fontWeight: FontWeight.w800, color: urgColor)),
                  const SizedBox(width: 8),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: urgColor.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text('${group.length}', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: urgColor)),
                  ),
                ]),
              ),
              ...group.map((entry) {
                final i = entry.key;
                final alert = entry.value;
                final isSent = _sentAlerts.contains(i);
                final color = _urgencyColor(alert.urgency);

                return _FadeSlideIn(index: i, child: Container(
                  margin: const EdgeInsets.only(bottom: 10),
                  child: _GlassCard(
                    isDark: isDark,
                    padding: const EdgeInsets.all(14),
                    child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      // Emoji
                      Container(
                        width: 40, height: 40,
                        decoration: BoxDecoration(
                          color: color.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: color.withOpacity(0.25)),
                        ),
                        child: Center(child: Text(alert.emoji, style: const TextStyle(fontSize: 18))),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                        Row(children: [
                          Expanded(child: Text(alert.targetName,
                            style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700,
                                color: color))),
                          if (isSent)
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                              decoration: BoxDecoration(
                                color: AppColors.success.withOpacity(0.12),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: const Row(mainAxisSize: MainAxisSize.min, children: [
                                Icon(Icons.check_rounded, size: 10, color: AppColors.success),
                                SizedBox(width: 3),
                                Text('Sent', style: TextStyle(fontSize: 10, color: AppColors.success, fontWeight: FontWeight.w700)),
                              ]),
                            ),
                        ]),
                        const SizedBox(height: 4),
                        Text(alert.message,
                          style: TextStyle(fontSize: 13, height: 1.4,
                              color: isDark ? AppColors.darkTextPrimary : AppColors.lightTextPrimary)),
                        if (alert.actionLabel != null) ...[
                          const SizedBox(height: 8),
                          Row(children: [
                            GestureDetector(
                              onTap: () => setState(() => _sentAlerts.add(i)),
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                                decoration: BoxDecoration(
                                  gradient: isSent ? null : LinearGradient(colors: [color, color.withOpacity(0.7)]),
                                  color: isSent ? AppColors.success.withOpacity(0.12) : null,
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Row(mainAxisSize: MainAxisSize.min, children: [
                                  Icon(isSent ? Icons.check_rounded : Icons.send_rounded,
                                    size: 11, color: isSent ? AppColors.success : Colors.white),
                                  const SizedBox(width: 4),
                                  Text(isSent ? 'Sent' : 'Send: ${alert.actionLabel}',
                                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700,
                                        color: isSent ? AppColors.success : Colors.white)),
                                ]),
                              ),
                            ),
                          ]),
                        ],
                      ])),
                    ]),
                  ),
                ));
              }),
              const SizedBox(height: 8),
            ];
          }),
        ],

        const SizedBox(height: 80),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  SHARED WIDGETS
// ══════════════════════════════════════════════════════════════════════════════

class _AuroraOrb extends StatelessWidget {
  final Color color;
  final double size;
  const _AuroraOrb({required this.color, required this.size});

  @override
  Widget build(BuildContext context) => Container(
    width: size, height: size,
    decoration: BoxDecoration(
      shape: BoxShape.circle,
      gradient: RadialGradient(colors: [color.withOpacity(0.18), Colors.transparent]),
    ),
  );
}

class _GlassCard extends StatelessWidget {
  final Widget child;
  final bool isDark;
  final EdgeInsets? padding;
  const _GlassCard({required this.child, required this.isDark, this.padding});

  @override
  Widget build(BuildContext context) => ClipRRect(
    borderRadius: BorderRadius.circular(20),
    child: BackdropFilter(
      filter: ImageFilter.blur(sigmaX: 16, sigmaY: 16),
      child: Container(
        padding: padding ?? const EdgeInsets.all(18),
        decoration: BoxDecoration(
          gradient: isDark
              ? LinearGradient(colors: [Colors.white.withOpacity(0.07), Colors.white.withOpacity(0.03)])
              : LinearGradient(colors: [Colors.white.withOpacity(0.88), Colors.white.withOpacity(0.65)]),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isDark ? Colors.white.withOpacity(0.10) : AppColors.lightBorder.withOpacity(0.5),
          ),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(isDark ? 0.2 : 0.06), blurRadius: 20, offset: const Offset(0, 6))],
        ),
        child: child,
      ),
    ),
  );
}

class _CardHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  const _CardHeader({required this.icon, required this.title, required this.subtitle, required this.color});

  @override
  Widget build(BuildContext context) => Row(children: [
    Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: [color, color.withOpacity(0.7)]),
        borderRadius: BorderRadius.circular(12),
        boxShadow: [BoxShadow(color: color.withOpacity(0.3), blurRadius: 10)],
      ),
      child: Icon(icon, color: Colors.white, size: 18),
    ),
    const SizedBox(width: 12),
    Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(title, style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w800)),
      Text(subtitle, style: TextStyle(fontSize: 11, color: AppColors.textSecondaryOf(context))),
    ])),
  ]);
}

class _SectionLabel extends StatelessWidget {
  final String text;
  final bool isDark;
  const _SectionLabel(this.text, this.isDark);

  @override
  Widget build(BuildContext context) => Text(text,
    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.2,
        color: isDark ? AppColors.darkTextSecondary : AppColors.lightTextSecondary));
}

class _Tag extends StatelessWidget {
  final String label;
  final Color color;
  const _Tag({required this.label, required this.color});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
    decoration: BoxDecoration(
      color: color.withOpacity(0.12),
      borderRadius: BorderRadius.circular(8),
      border: Border.all(color: color.withOpacity(0.25)),
    ),
    child: Text(label, style: TextStyle(fontSize: 10, fontWeight: FontWeight.w700, color: color)),
  );
}

class _SmallStat extends StatelessWidget {
  final String label;
  final String value;
  final Color color;
  const _SmallStat({required this.label, required this.value, required this.color});

  @override
  Widget build(BuildContext context) => Expanded(child: Container(
    padding: const EdgeInsets.symmetric(vertical: 8),
    decoration: BoxDecoration(
      color: color.withOpacity(0.10),
      borderRadius: BorderRadius.circular(10),
      border: Border.all(color: color.withOpacity(0.20)),
    ),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Text(value, style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900, color: color)),
      Text(label, style: TextStyle(fontSize: 9, fontWeight: FontWeight.w600, color: color.withOpacity(0.75))),
    ]),
  ));
}

class _ErrorBanner extends StatelessWidget {
  final String message;
  const _ErrorBanner(this.message);

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.error.withOpacity(0.08),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withOpacity(0.25)),
    ),
    child: Row(children: [
      const Icon(Icons.error_outline, color: AppColors.error, size: 16),
      const SizedBox(width: 8),
      Expanded(child: Text(message, style: const TextStyle(fontSize: 12, color: AppColors.error))),
    ]),
  );
}

class _NoTeamEmptyState extends StatelessWidget {
  const _NoTeamEmptyState();

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 24),
    child: Column(mainAxisSize: MainAxisSize.min, children: [
      Icon(Icons.people_outline, size: 48, color: AppColors.textSecondaryOf(context)),
      const SizedBox(height: 12),
      Text('No team members yet',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w700,
              color: AppColors.textPrimaryOf(context))),
      const SizedBox(height: 6),
      Text('Add team members from Admin → Team tab first',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 12, color: AppColors.textSecondaryOf(context))),
      const SizedBox(height: 12),
      FilledButton.tonalIcon(
        onPressed: () => context.go('/admin'),
        icon: const Icon(Icons.group_add_rounded, size: 16),
        label: const Text('Go to Team'),
      ),
    ]),
  );
}
