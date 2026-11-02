import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:file_picker/file_picker.dart';
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
  final List<PlatformFile> _bills = [];
  static const _maxBillMb = 4;
  static const _maxBillBytes = _maxBillMb * 1024 * 1024;
  static const _billTypes = ['pdf', 'jpg', 'jpeg', 'png'];
  bool _saving = false;

  double get _total => _lines.fold(0.0, (s, l) => s + l.amt);

  @override
  void dispose() {
    _title.dispose();
    for (final l in _lines) l.dispose();
    super.dispose();
  }

  // File picker, not image picker: bills arrive as PDFs as often as photos, and
  // the old empty catch hid every failure, so the button looked dead.
  Future<void> _pickBills() async {
    try {
      final res = await FilePicker.platform.pickFiles(
        allowMultiple: true,
        withData: true, // web gives no path, so we need the bytes
        type: FileType.custom,
        allowedExtensions: _billTypes,
      );
      if (res == null) return; // user cancelled
      final readable = res.files.where((f) => f.bytes != null).toList();
      // Same rule the server enforces, checked here so the person is told
      // before a long upload fails.
      final tooBig = readable.where((f) => f.size > _maxBillBytes).toList();
      final usable = readable.where((f) => f.size <= _maxBillBytes).toList();
      if (!mounted) return;
      if (tooBig.isNotEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content: Text(tooBig.length == 1
                ? '${tooBig.first.name} is ${(tooBig.first.size / 1048576).toStringAsFixed(1)} MB. Each bill must be under $_maxBillMb MB.'
                : '${tooBig.length} files are over $_maxBillMb MB and were left out.'),
            backgroundColor: AppColors.error));
      }
      if (usable.isEmpty && tooBig.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Could not read those files. Try again.'),
            backgroundColor: AppColors.error));
        return;
      }
      if (usable.isNotEmpty) setState(() => _bills.addAll(usable));
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text('Could not open files: $e'),
          backgroundColor: AppColors.error));
    }
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
        form.files.add(MapEntry(
            'bills', MultipartFile.fromBytes(b.bytes!, filename: b.name)));
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
            // The app theme gives every OutlinedButton an infinite minimum
            // width, which makes it unlayoutable inside a Row — the button
            // simply never appeared. Override the size here.
            OutlinedButton.icon(
              onPressed: _pickBills,
              style: OutlinedButton.styleFrom(
                  minimumSize: const Size(150, 46),
                  padding: const EdgeInsets.symmetric(horizontal: 16)),
              icon: const Icon(Icons.attach_file_rounded),
              label: const Text('Attach bills'),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                _bills.isEmpty
                    ? 'PDF, JPG or PNG · under $_maxBillMb MB'
                    : '${_bills.length} file${_bills.length == 1 ? '' : 's'} attached',
                style: TextStyle(color: AppColors.textSecondaryOf(context)),
              ),
            ),
          ]),
          // Show what is attached so a wrong file can be taken off again.
          if (_bills.isNotEmpty) ...[
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: List.generate(_bills.length, (i) {
                final f = _bills[i];
                final kb = ((f.size) / 1024).round();
                return Chip(
                  avatar: Icon(
                      f.extension == 'pdf'
                          ? Icons.picture_as_pdf_rounded
                          : Icons.image_rounded,
                      size: 18),
                  label: Text('${f.name}  ·  $kb KB',
                      overflow: TextOverflow.ellipsis),
                  onDeleted: () => setState(() => _bills.removeAt(i)),
                );
              }),
            ),
          ],
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
          // Phones get one field per row (side-by-side truncates the labels).
          LayoutBuilder(builder: (context, c) {
            final narrow = c.maxWidth < 420;
            final category = _tf(line.category, 'Category');
            final head = _tf(line.head, 'Expense head *');
            final remarks = _tf(line.remarks, 'Remarks');
            final amount = _tf(line.amount, 'Amount *',
                keyboard: const TextInputType.numberWithOptions(decimal: true),
                onChanged: (_) => onChanged(),
                formatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9.]'))]);

            if (narrow) {
              return Column(children: [
                category,
                const SizedBox(height: 10),
                head,
                const SizedBox(height: 10),
                remarks,
                const SizedBox(height: 10),
                amount,
              ]);
            }
            return Column(children: [
              Row(children: [
                Expanded(child: category),
                const SizedBox(width: 10),
                Expanded(child: head),
              ]),
              const SizedBox(height: 10),
              Row(children: [
                Expanded(flex: 2, child: remarks),
                const SizedBox(width: 10),
                Expanded(child: amount),
              ]),
            ]);
          }),
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
