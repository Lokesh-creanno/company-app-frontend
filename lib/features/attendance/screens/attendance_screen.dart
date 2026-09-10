import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/download_service.dart';
import '../../../shared/services/location_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';

final attendanceProvider = FutureProvider.autoDispose<Map<String, dynamic>>((ref) async {
  final now = DateTime.now();
  final response = await api.get('/attendance/my', params: {'month': now.month.toString(), 'year': now.year.toString()});
  return response.data['data'] as Map<String, dynamic>;
});

class AttendanceScreen extends ConsumerStatefulWidget {
  const AttendanceScreen({super.key});
  @override
  ConsumerState<AttendanceScreen> createState() => _AttendanceScreenState();
}

class _AttendanceScreenState extends ConsumerState<AttendanceScreen> {
  bool _checkingIn = false;
  bool _checkingOut = false;
  bool _downloading = false;

  Future<void> _downloadMonth() async {
    setState(() => _downloading = true);
    try {
      final now = DateTime.now();
      final bytes = await api.getBytes('/attendance/my/export',
          params: {'month': now.month.toString(), 'year': now.year.toString()});
      await saveFile(bytes, 'my_attendance_${now.year}-${now.month.toString().padLeft(2, '0')}.xlsx');
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Download failed: $e'), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _downloading = false);
    }
  }

  String _apiMsg(Object e) => e is DioException
      ? (e.response?.data?['message']?.toString() ?? 'Cannot reach server')
      : e.toString();

  void _snack(String m, {bool ok = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(m), backgroundColor: ok ? AppColors.success : AppColors.error));
  }

  Future<String?> _askNote() async {
    final c = TextEditingController();
    return showDialog<String>(
      context: context,
      builder: (dctx) => AlertDialog(
        title: const Text('Field check-in'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(labelText: 'Where are you? (e.g. client site, Noida)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(dctx, null), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(dctx, c.text.trim()), child: const Text('Check in')),
        ],
      ),
    );
  }

  // mode: 'office' (must be inside geofence) or 'field' (anywhere, with a note)
  Future<void> _checkIn({required String mode}) async {
    String? note;
    if (mode == 'field') {
      note = await _askNote();
      if (note == null) return; // cancelled
    }
    setState(() => _checkingIn = true);
    try {
      final loc = await LocationService.current();
      if (mode == 'office' && !loc.ok) {
        _snack(loc.error ?? 'Location needed for office check-in.');
        return;
      }
      final now = DateTime.now();
      final res = await api.post('/attendance/check-in', data: {
        'lat': loc.lat, 'lng': loc.lng, 'mode': mode, 'note': note,
        'localDate': DateFormat('yyyy-MM-dd').format(now),
        'localHour': now.hour, 'localMinute': now.minute,
      });
      ref.invalidate(attendanceProvider);
      _snack(res.data['message']?.toString() ?? 'Checked in ✓', ok: true);
    } catch (e) {
      _snack(_apiMsg(e));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _checkingOut = true);
    try {
      final loc = await LocationService.current(); // best-effort; checkout allowed without it
      final response = await api.post('/attendance/check-out', data: {
        'lat': loc.lat,
        'lng': loc.lng,
        'localDate': DateFormat('yyyy-MM-dd').format(DateTime.now()),
      });
      ref.invalidate(attendanceProvider);
      final hours = response.data['data']['workingHours'];
      _snack('Checked out! Working hours: ${hours}h ✓', ok: true);
    } catch (e) {
      _snack(_apiMsg(e));
    } finally {
      if (mounted) setState(() => _checkingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final attendanceAsync = ref.watch(attendanceProvider);
    final now = DateTime.now();

    return Scaffold(
      appBar: AppBar(title: const Text('Attendance'), actions: [
        IconButton(
          tooltip: 'Download this month (Excel)',
          icon: _downloading
              ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2))
              : const Icon(Icons.download_rounded),
          onPressed: _downloading ? null : _downloadMonth,
        ),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(attendanceProvider)),
      ]),
      body: attendanceAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (data) {
          final records = (data['records'] as List?) ?? [];
          final summary = data['summary'] as Map<String, dynamic>? ?? {};
          final today = records.firstWhere(
            (r) => r['date'] == DateFormat('yyyy-MM-dd').format(now),
            orElse: () => null,
          );

          final markedToday = today != null && today['checkInTime'] != null;

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Daily reminder — shown until today's attendance is marked
              if (!markedToday) ...[
                const InfoBanner(
                  message: 'You haven\'t marked attendance today. Tap "Check In" below.',
                  icon: Icons.notifications_active_rounded,
                  color: AppColors.warning,
                ),
                const SizedBox(height: 16),
              ],
              // Summary cards
              Row(children: [
                Expanded(child: StatCard(title: 'Present', value: '${summary['present'] ?? 0}', icon: Icons.check_circle, color: AppColors.success)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Absent', value: '${summary['absent'] ?? 0}', icon: Icons.cancel, color: AppColors.error)),
                const SizedBox(width: 8),
                Expanded(child: StatCard(title: 'Hours', value: '${summary['totalWorkingHours'] ?? 0}h', icon: Icons.timer, color: AppColors.primary)),
              ]),
              const SizedBox(height: 20),
              // Check-in/out buttons
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text('Today, ${DateFormat('d MMMM yyyy').format(now)}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),

                    if (!markedToday) ...[
                      // Two ways to mark: Office (must be inside geofence) or Field (anywhere).
                      Row(children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checkingIn ? null : () => _checkIn(mode: 'office'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.success),
                            icon: _checkingIn
                                ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                : const Icon(Icons.business_rounded, size: 18),
                            label: const Text('Office'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: _checkingIn ? null : () => _checkIn(mode: 'field'),
                            style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
                            icon: const Icon(Icons.travel_explore_rounded, size: 18),
                            label: const Text('Field'),
                          ),
                        ),
                      ]),
                      const SizedBox(height: 8),
                      const Text('Office needs you inside the office area. Field works anywhere.',
                          textAlign: TextAlign.center,
                          style: TextStyle(color: AppColors.textTertiary, fontSize: 11)),
                    ] else ...[
                      // Checked in — show time, late/field tag, and Check Out.
                      Wrap(alignment: WrapAlignment.center, spacing: 8, runSpacing: 6, children: [
                        StatusBadge(
                          label: 'In ${DateFormat('hh:mm a').format(DateTime.parse(today['checkInTime']).toLocal())}',
                          color: AppColors.success),
                        if (today['mode'] == 'field') const StatusBadge(label: 'FIELD', color: AppColors.secondary),
                        if (today['isLate'] == true)
                          const StatusBadge(label: 'LATE', color: AppColors.warning)
                        else
                          const StatusBadge(label: 'ON TIME', color: AppColors.success),
                        if (today['checkOutTime'] != null)
                          StatusBadge(
                            label: 'Out ${DateFormat('hh:mm a').format(DateTime.parse(today['checkOutTime']).toLocal())}',
                            color: AppColors.error),
                      ]),
                      const SizedBox(height: 14),
                      ElevatedButton.icon(
                        onPressed: (today['checkOutTime'] != null || _checkingOut) ? null : _checkOut,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.error,
                          disabledBackgroundColor: AppColors.error.withOpacity(0.4),
                        ),
                        icon: _checkingOut
                            ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                            : const Icon(Icons.logout, size: 18),
                        label: Text(today['checkOutTime'] != null ? 'Checked out' : 'Check Out'),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 20),
              // Calendar view
              TableCalendar(
                firstDay: DateTime.utc(now.year, now.month, 1),
                lastDay: DateTime.utc(now.year, now.month + 1, 0),
                focusedDay: now,
                calendarStyle: CalendarStyle(
                  todayDecoration: BoxDecoration(color: AppColors.primary.withOpacity(0.6), shape: BoxShape.circle),
                  selectedDecoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                ),
                calendarBuilders: CalendarBuilders(
                  markerBuilder: (context, day, events) {
                    final dateStr = DateFormat('yyyy-MM-dd').format(day);
                    final record = records.firstWhere((r) => r['date'] == dateStr, orElse: () => null);
                    if (record == null) return null;
                    Color c;
                    switch (record['status']) {
                      case 'present': c = AppColors.success; break;
                      case 'absent': c = AppColors.error; break;
                      case 'half_day': c = AppColors.warning; break;
                      default: c = AppColors.textTertiary;
                    }
                    return Positioned(bottom: 1, child: Container(width: 6, height: 6, decoration: BoxDecoration(color: c, shape: BoxShape.circle)));
                  },
                ),
              ),
              const SizedBox(height: 12),
              // Legend
              Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                _LegendDot(color: AppColors.success, label: 'Present'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.error, label: 'Absent'),
                const SizedBox(width: 16),
                _LegendDot(color: AppColors.warning, label: 'Half Day'),
              ]),
            ],
          );
        },
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;
  const _LegendDot({required this.color, required this.label});
  @override
  Widget build(BuildContext context) => Row(children: [
    Container(width: 10, height: 10, decoration: BoxDecoration(color: color, shape: BoxShape.circle)),
    const SizedBox(width: 4),
    Text(label, style: const TextStyle(fontSize: 12, color: AppColors.textSecondary)),
  ]);
}
