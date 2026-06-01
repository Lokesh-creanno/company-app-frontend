import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:dio/dio.dart';
import 'package:intl/intl.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import '../../../shared/services/api_service.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

// ── OCR result data class ───────────────────────────────────────────────────
class _OcrResult {
  final String rawText;
  final String? title;
  final double? amount;
  final DateTime? date;
  final String? category;

  _OcrResult({
    required this.rawText,
    this.title,
    this.amount,
    this.date,
    this.category,
  });
}

// ── Smart parser for bill / receipt text ────────────────────────────────────
class _BillParser {
  static _OcrResult parse(String raw) {
    final lines = raw.split('\n').map((l) => l.trim()).where((l) => l.isNotEmpty).toList();
    final lower = raw.toLowerCase();

    // ── Amount ──────────────────────────────────────────────────────────────
    double? amount;
    // Try "Total", "Grand Total", "Amount", "Net Amount", "₹" patterns
    final amountPatterns = [
      RegExp(r'(?:grand\s*total|total\s*amount|net\s*amount|total|amount\s*paid|amount)\s*[:\-]?\s*[₹rs\.]*\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
      RegExp(r'[₹]\s*([\d,]+(?:\.\d{1,2})?)'),
      RegExp(r'rs\.?\s*([\d,]+(?:\.\d{1,2})?)', caseSensitive: false),
    ];
    for (final pattern in amountPatterns) {
      final match = pattern.firstMatch(raw);
      if (match != null) {
        final str = match.group(1)!.replaceAll(',', '');
        amount = double.tryParse(str);
        if (amount != null && amount > 0) break;
      }
    }
    // Fallback: find the largest plausible number (10–99999) in text
    if (amount == null) {
      final nums = RegExp(r'\b(\d{2,6}(?:\.\d{1,2})?)\b').allMatches(raw)
          .map((m) => double.tryParse(m.group(1)!))
          .whereType<double>()
          .where((n) => n >= 10 && n <= 99999)
          .toList();
      if (nums.isNotEmpty) {
        nums.sort((a, b) => b.compareTo(a));
        amount = nums.first;
      }
    }

    // ── Date ────────────────────────────────────────────────────────────────
    DateTime? date;
    // Try DD/MM/YYYY or DD-MM-YYYY or DD.MM.YYYY
    final datePatternDMY = RegExp(r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b');
    final datePatternYMD = RegExp(r'\b(\d{4})[\/\-\.](\d{1,2})[\/\-\.](\d{1,2})\b');
    // Month name patterns
    final monthNames = {'jan':1,'feb':2,'mar':3,'apr':4,'may':5,'jun':6,'jul':7,'aug':8,'sep':9,'oct':10,'nov':11,'dec':12};
    final datePatternMonthName = RegExp(r'\b(\d{1,2})\s*(jan|feb|mar|apr|may|jun|jul|aug|sep|oct|nov|dec)\w*\s*,?\s*(\d{4})\b', caseSensitive: false);

    var m = datePatternMonthName.firstMatch(lower);
    if (m != null) {
      final day = int.tryParse(m.group(1)!);
      final month = monthNames[m.group(2)!.toLowerCase().substring(0,3)];
      final year = int.tryParse(m.group(3)!);
      if (day != null && month != null && year != null) {
        date = DateTime(year, month, day);
      }
    }

    if (date == null) {
      m = datePatternDMY.firstMatch(raw);
      if (m != null) {
        final d = int.tryParse(m.group(1)!);
        final mo = int.tryParse(m.group(2)!);
        var yr = int.tryParse(m.group(3)!);
        if (yr != null && yr < 100) yr += 2000;
        if (d != null && mo != null && yr != null && d <= 31 && mo <= 12) {
          date = DateTime(yr, mo, d);
        }
      }
    }

    if (date == null) {
      m = datePatternYMD.firstMatch(raw);
      if (m != null) {
        final yr = int.tryParse(m.group(1)!);
        final mo = int.tryParse(m.group(2)!);
        final d = int.tryParse(m.group(3)!);
        if (yr != null && mo != null && d != null && mo <= 12 && d <= 31) {
          date = DateTime(yr, mo, d);
        }
      }
    }

    // Clamp to valid range
    if (date != null && (date.isAfter(DateTime.now()) || date.isBefore(DateTime(2015)))) {
      date = null;
    }

    // ── Category ────────────────────────────────────────────────────────────
    String? category;
    final categoryKeywords = <String, List<String>>{
      'food':          ['restaurant', 'cafe', 'food', 'lunch', 'dinner', 'breakfast', 'hotel', 'swiggy', 'zomato', 'pizza', 'burger', 'meal', 'eatery', 'dhaba', 'snacks'],
      'travel':        ['cab', 'taxi', 'uber', 'ola', 'auto', 'bus', 'train', 'flight', 'airline', 'airport', 'petrol', 'fuel', 'diesel', 'toll', 'travel', 'irctc', 'rapido', 'metro'],
      'accommodation': ['hotel', 'lodge', 'inn', 'stay', 'resort', 'accommodation', 'room', 'oyo', 'booking.com', 'airbnb'],
      'medical':       ['pharmacy', 'medical', 'clinic', 'hospital', 'doctor', 'medicine', 'chemist', 'diagnostic', 'lab', 'health'],
      'training':      ['course', 'training', 'workshop', 'seminar', 'certification', 'udemy', 'coursera', 'adobe', 'subscription', 'license'],
      'office_supplies': ['stationery', 'office', 'print', 'paper', 'ink', 'pen', 'supplies', 'amazon', 'flipkart'],
    };
    int bestScore = 0;
    for (final entry in categoryKeywords.entries) {
      final score = entry.value.where((kw) => lower.contains(kw)).length;
      if (score > bestScore) {
        bestScore = score;
        category = entry.key;
      }
    }

    // ── Title ───────────────────────────────────────────────────────────────
    String? title;
    // Use first meaningful line (skip short/numeric-only lines)
    for (final line in lines.take(5)) {
      if (line.length >= 4 && !RegExp(r'^[\d\s\W]+$').hasMatch(line)) {
        title = line.length > 60 ? line.substring(0, 60) : line;
        break;
      }
    }

    return _OcrResult(rawText: raw, title: title, amount: amount, date: date, category: category);
  }
}

// ── Main form screen ─────────────────────────────────────────────────────────
class ReimbursementFormScreen extends ConsumerStatefulWidget {
  const ReimbursementFormScreen({super.key});
  @override
  ConsumerState<ReimbursementFormScreen> createState() => _ReimbursementFormScreenState();
}

class _ReimbursementFormScreenState extends ConsumerState<ReimbursementFormScreen>
    with SingleTickerProviderStateMixin {
  final _formKey   = GlobalKey<FormState>();
  final _titleCtrl  = TextEditingController();
  final _descCtrl   = TextEditingController();
  final _amountCtrl = TextEditingController();
  final _remarksCtrl = TextEditingController();

  String   _category    = 'travel';
  DateTime _expenseDate = DateTime.now();
  List<PlatformFile> _bills = [];
  bool _saving    = false;
  bool _scanning  = false;

  // OCR state
  File? _scannedImage;
  _OcrResult? _lastOcrResult;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _descCtrl.dispose();
    _amountCtrl.dispose();
    _remarksCtrl.dispose();
    super.dispose();
  }

  // ── OCR: pick image → recognize → show result ──────────────────────────
  Future<void> _scanBillWithOcr(ImageSource source) async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: source, imageQuality: 90);
    if (picked == null) return;

    setState(() => _scanning = true);

    try {
      final imgFile = File(picked.path);
      final inputImage = InputImage.fromFile(imgFile);
      final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final result = await recognizer.processImage(inputImage);
      await recognizer.close();

      final raw = result.text;
      if (raw.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('No text found in image. Try a clearer photo.'), backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final parsed = _BillParser.parse(raw);
      setState(() {
        _scannedImage = imgFile;
        _lastOcrResult = parsed;
      });

      if (mounted) _showOcrResultSheet(parsed);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('OCR failed: $e'), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _scanning = false);
    }
  }

  // ── Bottom sheet: show parsed OCR data ────────────────────────────────
  void _showOcrResultSheet(_OcrResult result) {
    // Local apply-state controllers for the sheet
    final sheetTitleCtrl  = TextEditingController(text: result.title ?? '');
    final sheetAmountCtrl = TextEditingController(text: result.amount?.toStringAsFixed(0) ?? '');
    var   sheetDate       = result.date ?? _expenseDate;
    var   sheetCategory   = result.category ?? _category;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          return DraggableScrollableSheet(
            initialChildSize: 0.85,
            minChildSize: 0.5,
            maxChildSize: 0.95,
            builder: (_, scrollCtrl) => Container(
              decoration: BoxDecoration(
                color: Theme.of(context).scaffoldBackgroundColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Column(
                children: [
                  // Handle bar
                  Container(
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    width: 40, height: 4,
                    decoration: BoxDecoration(color: Colors.grey[400], borderRadius: BorderRadius.circular(2)),
                  ),

                  // Header
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.12), borderRadius: BorderRadius.circular(10)),
                          child: const Icon(Icons.document_scanner, color: AppColors.primary, size: 22),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('OCR Scan Result', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                              Text('Review & edit before applying', style: TextStyle(fontSize: 12, color: Colors.grey)),
                            ],
                          ),
                        ),
                        // Confidence badge
                        _ConfidenceBadge(result: result),
                      ],
                    ),
                  ),

                  const Divider(height: 20),

                  Expanded(
                    child: ListView(
                      controller: scrollCtrl,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Scanned image preview
                        if (_scannedImage != null)
                          ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.file(_scannedImage!, height: 160, width: double.infinity, fit: BoxFit.cover),
                          ),
                        const SizedBox(height: 16),

                        // Parsed fields — editable
                        const Text('Extracted Data', style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13, color: Colors.grey)),
                        const SizedBox(height: 10),

                        // Title
                        TextField(
                          controller: sheetTitleCtrl,
                          decoration: InputDecoration(
                            labelText: 'Merchant / Title',
                            prefixIcon: const Icon(Icons.store_outlined, size: 18),
                            suffixIcon: result.title != null ? const _FoundBadge() : const _NotFoundBadge(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Amount
                        TextField(
                          controller: sheetAmountCtrl,
                          keyboardType: const TextInputType.numberWithOptions(decimal: true),
                          decoration: InputDecoration(
                            labelText: 'Amount (₹)',
                            prefixIcon: const Icon(Icons.currency_rupee, size: 18),
                            suffixIcon: result.amount != null ? const _FoundBadge() : const _NotFoundBadge(),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Date
                        InkWell(
                          onTap: () async {
                            final picked = await showDatePicker(
                              context: ctx,
                              initialDate: sheetDate,
                              firstDate: DateTime(2020),
                              lastDate: DateTime.now(),
                            );
                            if (picked != null) setSheetState(() => sheetDate = picked);
                          },
                          child: InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Expense Date',
                              prefixIcon: const Icon(Icons.calendar_today_outlined, size: 18),
                              suffixIcon: result.date != null ? const _FoundBadge() : const _NotFoundBadge(),
                            ),
                            child: Text(DateFormat('d MMMM yyyy').format(sheetDate)),
                          ),
                        ),
                        const SizedBox(height: 12),

                        // Category
                        DropdownButtonFormField<String>(
                          value: sheetCategory,
                          decoration: InputDecoration(
                            labelText: 'Category',
                            prefixIcon: const Icon(Icons.category_outlined, size: 18),
                            suffixIcon: result.category != null ? const _FoundBadge() : const _NotFoundBadge(),
                          ),
                          items: AppConstants.reimbursementCategories.entries
                              .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                              .toList(),
                          onChanged: (v) => setSheetState(() => sheetCategory = v!),
                        ),

                        const SizedBox(height: 20),
                        const Divider(),
                        const SizedBox(height: 8),

                        // Raw OCR text expander
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Raw OCR Text', style: TextStyle(fontSize: 13, color: Colors.grey)),
                          children: [
                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: Colors.grey.withOpacity(0.08),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: SelectableText(result.rawText, style: const TextStyle(fontSize: 12, fontFamily: 'monospace')),
                            ),
                          ],
                        ),
                        const SizedBox(height: 80),
                      ],
                    ),
                  ),

                  // Apply / Discard buttons
                  SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                      child: Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => Navigator.pop(ctx),
                              child: const Text('Discard'),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: ElevatedButton.icon(
                              icon: const Icon(Icons.check_circle_outline, size: 18),
                              label: const Text('Apply to Form'),
                              onPressed: () {
                                _applyOcrToForm(
                                  title:    sheetTitleCtrl.text,
                                  amount:   sheetAmountCtrl.text,
                                  date:     sheetDate,
                                  category: sheetCategory,
                                );
                                Navigator.pop(ctx);
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  // ── Apply OCR results to main form ────────────────────────────────────
  void _applyOcrToForm({
    required String title,
    required String amount,
    required DateTime date,
    required String category,
  }) {
    setState(() {
      if (title.isNotEmpty) _titleCtrl.text = title;
      if (amount.isNotEmpty) _amountCtrl.text = amount;
      _expenseDate = date;
      _category = category;
      if (_descCtrl.text.isEmpty && _lastOcrResult != null) {
        _descCtrl.text = 'Scanned from bill image via OCR';
      }
    });
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Row(children: [
          Icon(Icons.check_circle, color: Colors.white, size: 18),
          SizedBox(width: 8),
          Text('OCR data applied to form!'),
        ]),
        backgroundColor: AppColors.success,
        duration: Duration(seconds: 2),
      ),
    );
  }

  // ── Source picker: camera or gallery ──────────────────────────────────
  void _showOcrSourcePicker() {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Padding(
              padding: EdgeInsets.all(16),
              child: Text('Scan Bill / Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.blue.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.camera_alt, color: Colors.blue),
              ),
              title: const Text('Take Photo'),
              subtitle: const Text('Use camera to capture bill'),
              onTap: () { Navigator.pop(ctx); _scanBillWithOcr(ImageSource.camera); },
            ),
            ListTile(
              leading: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(color: Colors.purple.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
                child: const Icon(Icons.photo_library, color: Colors.purple),
              ),
              title: const Text('Choose from Gallery'),
              subtitle: const Text('Pick an existing photo of bill'),
              onTap: () { Navigator.pop(ctx); _scanBillWithOcr(ImageSource.gallery); },
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  // ── File picker for bill upload ───────────────────────────────────────
  Future<void> _pickBills() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['pdf', 'jpg', 'jpeg', 'png'],
      allowMultiple: true,
    );
    if (result != null) setState(() => _bills = result.files);
  }

  // ── Submit ────────────────────────────────────────────────────────────
  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      final formData = FormData.fromMap({
        'title':       _titleCtrl.text,
        'description': _descCtrl.text,
        'category':    _category,
        'amount':      _amountCtrl.text,
        'expenseDate': DateFormat('yyyy-MM-dd').format(_expenseDate),
        'remarks':     _remarksCtrl.text,
        'bills': [
          for (final f in _bills)
            await MultipartFile.fromFile(f.path!, filename: f.name),
        ],
      });

      await api.postForm('/reimbursements', formData);
      if (mounted) {
        context.go('/reimbursements');
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reimbursement submitted!'), backgroundColor: AppColors.success),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Submit Claim'),
        actions: [
          if (_lastOcrResult != null)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: Chip(
                avatar: const Icon(Icons.document_scanner, size: 14, color: Colors.white),
                label: const Text('OCR Applied', style: TextStyle(fontSize: 11, color: Colors.white)),
                backgroundColor: AppColors.success,
                padding: EdgeInsets.zero,
              ),
            ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── OCR Scan Banner ──────────────────────────────────────
            _OcrScanBanner(
              scanning: _scanning,
              hasResult: _lastOcrResult != null,
              onScan: _showOcrSourcePicker,
              onRescan: _showOcrSourcePicker,
            ),
            const SizedBox(height: 20),

            // ── Form Fields ──────────────────────────────────────────
            TextFormField(
              controller: _titleCtrl,
              decoration: const InputDecoration(labelText: 'Title *', hintText: 'e.g. Team Lunch'),
              validator: (v) => v?.isEmpty == true ? 'Required' : null,
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _category,
              decoration: const InputDecoration(labelText: 'Category *'),
              items: AppConstants.reimbursementCategories.entries
                  .map((e) => DropdownMenuItem(value: e.key, child: Text(e.value)))
                  .toList(),
              onChanged: (v) => setState(() => _category = v!),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: const InputDecoration(labelText: 'Amount (₹) *', prefixIcon: Icon(Icons.currency_rupee)),
              validator: (v) {
                if (v?.isEmpty == true) return 'Required';
                if (double.tryParse(v!) == null) return 'Enter valid amount';
                return null;
              },
            ),
            const SizedBox(height: 12),

            InkWell(
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: _expenseDate,
                  firstDate: DateTime(2020),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _expenseDate = picked);
              },
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Expense Date *',
                  prefixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(DateFormat('d MMMM yyyy').format(_expenseDate)),
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _descCtrl,
              maxLines: 3,
              decoration: const InputDecoration(
                labelText: 'Description',
                hintText: 'Describe the expense...',
              ),
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: _remarksCtrl,
              decoration: const InputDecoration(labelText: 'Remarks'),
            ),
            const SizedBox(height: 16),

            // ── Bill upload ──────────────────────────────────────────
            OutlinedButton.icon(
              onPressed: _pickBills,
              icon: const Icon(Icons.upload_file),
              label: Text(_bills.isEmpty ? 'Upload Bills (PDF/Images)' : '${_bills.length} file(s) selected'),
              style: OutlinedButton.styleFrom(minimumSize: const Size(double.infinity, 48)),
            ),
            if (_bills.isNotEmpty) ...[
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: _bills.map((f) => Chip(
                  label: Text(f.name, style: const TextStyle(fontSize: 11)),
                  deleteIcon: const Icon(Icons.close, size: 14),
                  onDeleted: () => setState(() => _bills.remove(f)),
                )).toList(),
              ),
            ],
            const SizedBox(height: 32),

            ElevatedButton(
              onPressed: _saving ? null : _submit,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 52)),
              child: _saving
                  ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Submit Claim', style: TextStyle(fontSize: 16)),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── OCR Scan Banner widget ──────────────────────────────────────────────────
class _OcrScanBanner extends StatelessWidget {
  final bool scanning;
  final bool hasResult;
  final VoidCallback onScan;
  final VoidCallback onRescan;

  const _OcrScanBanner({
    required this.scanning,
    required this.hasResult,
    required this.onScan,
    required this.onRescan,
  });

  @override
  Widget build(BuildContext context) {
    if (scanning) {
      return Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: const Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)),
            SizedBox(width: 12),
            Text('Scanning bill with OCR...', style: TextStyle(fontWeight: FontWeight.w500)),
          ],
        ),
      );
    }

    if (hasResult) {
      return Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.success.withOpacity(0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.check_circle, color: AppColors.success, size: 28),
            const SizedBox(width: 12),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Bill scanned successfully', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  Text('Form auto-filled from OCR', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            TextButton.icon(
              onPressed: onRescan,
              icon: const Icon(Icons.refresh, size: 16),
              label: const Text('Re-scan', style: TextStyle(fontSize: 12)),
            ),
          ],
        ),
      );
    }

    // Default — prompt to scan
    return GestureDetector(
      onTap: onScan,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [AppColors.primary.withOpacity(0.08), Colors.blue.withOpacity(0.05)],
          ),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.primary.withOpacity(0.3)),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.document_scanner, color: Colors.white, size: 24),
            ),
            const SizedBox(width: 14),
            const Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Scan Bill with OCR', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  SizedBox(height: 2),
                  Text('Auto-fill form from receipt photo', style: TextStyle(fontSize: 12, color: Colors.grey)),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Text('Scan', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13)),
            ),
          ],
        ),
      ),
    );
  }
}

// ── Small helper widgets ────────────────────────────────────────────────────
class _FoundBadge extends StatelessWidget {
  const _FoundBadge();
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(right: 8),
    child: Icon(Icons.check_circle, color: Colors.green[600], size: 18),
  );
}

class _NotFoundBadge extends StatelessWidget {
  const _NotFoundBadge();
  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.only(right: 8),
    child: Icon(Icons.help_outline, color: Colors.grey, size: 18),
  );
}

class _ConfidenceBadge extends StatelessWidget {
  final _OcrResult result;
  const _ConfidenceBadge({required this.result});

  @override
  Widget build(BuildContext context) {
    final found = [result.title, result.amount, result.date, result.category].where((v) => v != null).length;
    final pct = (found / 4 * 100).round();
    final color = pct >= 75 ? Colors.green : pct >= 50 ? Colors.orange : Colors.red;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: color.withOpacity(0.12), borderRadius: BorderRadius.circular(99)),
      child: Text('$pct% match', style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 12)),
    );
  }
}
