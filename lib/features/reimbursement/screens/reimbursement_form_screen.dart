import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:image_picker/image_picker.dart';
import '../../../shared/services/api_service.dart';
import '../../../core/theme.dart';

// One editable expense line.
class _Line {
  DateTime date;
  final category = TextEditingController();
  final head = TextEditingController();
  final remarks = TextEditingController();
  final amount = TextEditingController();
  _Line({DateTime? date}) : date = date ?? DateTime.now();
  double get amt => double.tryParse(amount.text.trim()) ?? 0;
  Map<String, dynamic> toJson() => {
        'date': DateFormat('yyyy-MM-dd').format(date),
        'category': category.text.trim(),
        'expenseHead': head.text.trim(),
        'remarks': remarks.text.trim(),
        'amount': amt,
      };
  void dispose() { category.dispose(); head.dispose(); remarks.dispose(); amount.dispose(); }
}

class ReimbursementFormScreen extends ConsumerStatefulWidget {
  const ReimbursementFormScreen({super.key});
  @override
  ConsumerState<ReimbursementFormScreen> createState() => _ReimbursementFormScreenState();
}

class _ReimbursementFormScreenState extends ConsumerState<ReimbursementFormScreen> {
  final _title = TextEditingController(text: 'Reimbursement ${DateFormat('MMM yyyy').format(DateTime.now())}');
  final List<_Line> _lines = [_Line()];
  final List<XFile> _bills = [];
  bool _saving = false;

  double get _total => _lines.fold(0.0, (s, l) => s + l.amt);

  @override
  void dispose() {
    _title.dispose();
    for (final l in _lines) l.dispose();
    super.dispose();
  }

  Future<void> _pickBills() async {
    try {
      final picked = await ImagePicker().pickMultiImage();
      if (picked.isNotEmpty) setState(() => _bills.addAll(picked));
    } catch (_) {}
  }

  bool _valid() {
    if (_lines.isEmpty) return false;
    for (final l in _lines) {
      if (l.head.text.trim().isEmpty || l.amt <= 0) return false;
    }
    return true;
  }

  Future<void> _submit() async {
    if (!_valid()) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
        content: Text('Every line needs an expense head and an amount > 0'),
        backgroundColor: AppColors.error));
      return;
    }
    setState(() => _saving = true);
    try {
      final form = FormData();
      form.fields.add(MapEntry('title', _title.text.trim()));
      form.fields.add(MapEntry('items', jsonEncode(_lines.map((l) => l.toJson()).toList())));
      for (final b in _bills) {
        final bytes = await b.readAsBytes();
        form.files.add(MapEntry('bills', MultipartFile.fromBytes(bytes, filename: b.name)));
      }
      final res = await api.postForm('/reimbursements', form);
      final warnings = (res.data['data']?['duplicateWarnings'] as List?)?.cast<String>() ?? [];
      if (!mounted) return;
      if (warnings.isNotEmpty) {
        await showDialog(
          context: context,
          builder: (dctx) => AlertDialog(
            title: const Text('Submitted — with warnings'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Your claim was submitted. Accounts will see these possible duplicates:'),
                const SizedBox(height: 10),
                ...warnings.map((w) => Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: Text('• $w', style: const TextStyle(fontSize: 13)))),
              ],
            ),
            actions: [TextButton(onPressed: () => Navigator.pop(dctx), child: const Text('OK'))],
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Claim submitted ✓'), backgroundColor: AppColors.success));
      }
      if (mounted) context.pop(true);
    } catch (e) {
      final m = e is DioException
          ? (e.response?.data?['message']?.toString() ?? 'Submit failed')
          : 'Submit failed';
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m), backgroundColor: AppColors.error));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New claim')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 120),
        children: [
          TextField(
            controller: _title,
            decoration: const InputDecoration(labelText: 'Claim title'),
          ),
          const SizedBox(height: 16),
          const Text('Expense lines', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 8),
          ..._lines.asMap().entries.map((e) => _LineCard(
                line: e.value,
                index: e.key + 1,
                onChanged: () => setState(() {}),
                onRemove: _lines.length > 1
                    ? () => setState(() { _lines.removeAt(e.key).dispose(); })
                    : null,
                onPickDate: () async {
                  final d = await showDatePicker(
                    context: context,
                    initialDate: e.value.date,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now().add(const Duration(days: 1)),
                  );
                  if (d != null) setState(() => e.value.date = d);
                },
              )),
          const SizedBox(height: 4),
          OutlinedButton.icon(
            onPressed: () => setState(() => _lines.add(_Line())),
            icon: const Icon(Icons.add),
            label: const Text('Add line'),
          ),
          const SizedBox(height: 16),
          // Bills
          Row(children: [
            OutlinedButton.icon(
              onPressed: _pickBills,
              icon: const Icon(Icons.photo_camera_rounded),
              label: const Text('Attach bills'),
            ),
            const SizedBox(width: 10),
            if (_bills.isNotEmpty)
              Text('${_bills.length} photo${_bills.length == 1 ? '' : 's'}',
                  style: const TextStyle(color: AppColors.textSecondary)),
          ]),
        ],
      ),
      bottomSheet: Container(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        decoration: BoxDecoration(
          color: AppColors.surfaceOf(context),
          border: Border(top: BorderSide(color: AppColors.borderOf(context))),
        ),
        child: Row(children: [
          Column(crossAxisAlignment: CrossAxisAlignment.start, mainAxisSize: MainAxisSize.min, children: [
            const Text('Total', style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
            Text('₹${NumberFormat('#,##0.00').format(_total)}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
          ]),
          const Spacer(),
          FilledButton.icon(
            onPressed: _saving ? null : _submit,
            icon: _saving
                ? const SizedBox(width: 18, height: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.send_rounded),
            label: const Text('Submit'),
          ),
        ]),
      ),
    );
  }
}

class _LineCard extends StatelessWidget {
  final _Line line;
  final int index;
  final VoidCallback onChanged;
  final VoidCallback? onRemove;
  final VoidCallback onPickDate;
  const _LineCard({
    required this.line,
    required this.index,
    required this.onChanged,
    required this.onRemove,
    required this.onPickDate,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.surfaceOf(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.borderOf(context)),
      ),
      child: Column(
        children: [
          Row(children: [
            Text('#$index', style: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textSecondary)),
            const Spacer(),
            InkWell(
              onTap: onPickDate,
              child: Row(children: [
                const Icon(Icons.calendar_today_rounded, size: 14, color: AppColors.textSecondary),
                const SizedBox(width: 6),
                Text(DateFormat('d MMM yyyy').format(line.date),
                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
              ]),
            ),
            if (onRemove != null)
              IconButton(
                visualDensity: VisualDensity.compact,
                icon: const Icon(Icons.close_rounded, size: 18, color: AppColors.error),
                onPressed: onRemove,
              ),
          ]),
          const SizedBox(height: 6),
          Row(children: [
            Expanded(child: _tf(line.category, 'Category (e.g. Travel)')),
            const SizedBox(width: 10),
            Expanded(child: _tf(line.head, 'Expense head *')),
          ]),
          const SizedBox(height: 10),
          Row(children: [
            Expanded(flex: 2, child: _tf(line.remarks, 'Remarks')),
            const SizedBox(width: 10),
            Expanded(
              child: _tf(line.amount, 'Amount *',
                  keyboard: const TextInputType.numberWithOptions(decimal: true),
                  onChanged: (_) => onChanged(),
                  formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]),
            ),
          ]),
        ],
      ),
    );
  }

  Widget _tf(TextEditingController c, String label,
      {TextInputType? keyboard, ValueChanged<String>? onChanged, List<TextInputFormatter>? formatters}) {
    return TextField(
      controller: c,
      keyboardType: keyboard,
      onChanged: onChanged,
      inputFormatters: formatters,
      decoration: InputDecoration(labelText: label, isDense: true),
    );
  }
}
