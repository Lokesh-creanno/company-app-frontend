import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:table_calendar/table_calendar.dart';
import '../../../shared/services/api_service.dart';
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

  // Returns lat/lng — null on Windows/Web where GPS is unavailable
  Future<Map<String, double?>?> _getLocation() async {
    return null; // GPS not available on desktop — backend accepts null coordinates
  }

  Future<void> _checkIn() async {
    setState(() => _checkingIn = true);
    try {
      final pos = await _getLocation();
      // Send localDate so backend uses device's date, not server UTC date
      final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      await api.post('/attendance/check-in', data: {
        'lat': pos?['lat'],
        'lng': pos?['lng'],
        'localDate': localDate,
      });
      ref.invalidate(attendanceProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Checked in successfully! ✓'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _checkingIn = false);
    }
  }

  Future<void> _checkOut() async {
    setState(() => _checkingOut = true);
    try {
      final pos = await _getLocation();
      // Send localDate so backend matches today's check-in record correctly
      final localDate = DateFormat('yyyy-MM-dd').format(DateTime.now());
      final response = await api.post('/attendance/check-out', data: {
        'lat': pos?['lat'],
        'lng': pos?['lng'],
        'localDate': localDate,
      });
      ref.invalidate(attendanceProvider);
      final hours = response.data['data']['workingHours'];
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Checked out! Working hours: ${hours}h ✓'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
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

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
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
                  children: [
                    Text('Today, ${DateFormat('d MMMM yyyy').format(now)}', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (today != null && today['checkInTime'] != null) || _checkingIn ? null : _checkIn,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.success,
                              disabledBackgroundColor: AppColors.success.withOpacity(0.4),
                            ),
                            icon: _checkingIn ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.login, size: 18),
                            label: Text(today?['checkInTime'] != null ? 'Checked In ${DateFormat('hh:mm a').format(DateTime.parse(today['checkInTime']).toLocal())}' : 'Check In'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: (today == null || today['checkInTime'] == null || today['checkOutTime'] != null) || _checkingOut ? null : _checkOut,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.error,
                              disabledBackgroundColor: AppColors.error.withOpacity(0.4),
                            ),
                            icon: _checkingOut ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)) : const Icon(Icons.logout, size: 18),
                            label: Text(today?['checkOutTime'] != null ? 'Checked Out ${DateFormat('hh:mm a').format(DateTime.parse(today['checkOutTime']).toLocal())}' : 'Check Out'),
                          ),
                        ),
                      ],
                    ),
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
