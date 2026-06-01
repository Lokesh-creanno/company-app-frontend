import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';
import 'package:dio/dio.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/services/ai_service.dart';
import '../../../shared/services/receipt_ocr_service.dart';
import '../../../core/theme.dart';
import '../../../core/ai_config.dart';
import '../../../features/auth/providers/auth_provider.dart';

// ─── Business categories (real agency use cases) ─────────────────────────────
const _kCategories = [
  (value: 'travel',              label: 'Travel',               icon: Icons.flight_rounded),
  (value: 'client_entertainment',label: 'Client Entertainment', icon: Icons.restaurant_rounded),
  (value: 'accommodation',       label: 'Accommodation',        icon: Icons.hotel_rounded),
  (value: 'food',                label: 'Food & Meals',         icon: Icons.fastfood_rounded),
  (value: 'medical',             label: 'Medical',              icon: Icons.medical_services_rounded),
  (value: 'training',            label: 'Training & Dev',       icon: Icons.school_rounded),
  (value: 'office_supplies',     label: 'Office Supplies',      icon: Icons.inventory_2_rounded),
  (value: 'fuel',                label: 'Fuel / Conveyance',    icon: Icons.local_gas_station_rounded),
  (value: 'other',               label: 'Other',                icon: Icons.receipt_rounded),
];

String _catLabel(String? val) {
  if (val == null) return 'Other';
  return _kCategories.firstWhere((c) => c.value == val, orElse: () => _kCategories.last).label;
}

// ─── Expense entry model ──────────────────────────────────────────────────────
class _ExpenseEntry {
  final TextEditingController nameCtrl;
  final TextEditingController amountCtrl;
  String category;

  _ExpenseEntry({this.category = 'other'})
      : nameCtrl = TextEditingController(),
        amountCtrl = TextEditingController();

  void dispose() {
    nameCtrl.dispose();
    amountCtrl.dispose();
  }

  String get name => nameCtrl.text.trim();
  double get amount => double.tryParse(amountCtrl.text.trim().replaceAll(',', '')) ?? 0.0;
  bool get isValid => name.isNotEmpty && amount > 0;
}

// ═══════════════════════════════════════════════════════════════════════════════
//  MAIN SCREEN
// ═══════════════════════════════════════════════════════════════════════════════
class ExpenseClaimScreen extends ConsumerStatefulWidget {
  const ExpenseClaimScreen({super.key});

  @override
  ConsumerState<ExpenseClaimScreen> createState() => _ExpenseClaimScreenState();
}

class _ExpenseClaimScreenState extends ConsumerState<ExpenseClaimScreen> {
  final PageController _pageCtrl = PageController();
  int _step = 0;

  // ── Step 1 state ─────────────────────────────────────────────────────────────
  final _step1FormKey = GlobalKey<FormState>();
  final _projectCtrl  = TextEditingController();
  final _remarksCtrl  = TextEditingController();
  final List<_ExpenseEntry> _entries = [_ExpenseEntry()];
  DateTime _claimDate = DateTime.now();
  String _claimCategory = 'other'; // overall claim category

  // ── Step 2 state ─────────────────────────────────────────────────────────────
  final List<File> _billImages = [];

  // ── Loading flags ─────────────────────────────────────────────────────────────
  bool _submitting    = false;
  bool _pdfGenerating = false;
  bool _ocrScanning   = false;

  @override
  void dispose() {
    _pageCtrl.dispose();
    _projectCtrl.dispose();
    _remarksCtrl.dispose();
    for (final e in _entries) e.dispose();
    super.dispose();
  }

  double get _total => _entries.fold(0.0, (s, e) => s + e.amount);
  List<_ExpenseEntry> get _validEntries => _entries.where((e) => e.isValid).toList();

  // ── Navigation ────────────────────────────────────────────────────────────────
  void _goTo(int step) {
    if (step == _step) return;
    setState(() => _step = step);
    _pageCtrl.animateToPage(step,
        duration: const Duration(milliseconds: 300), curve: Curves.easeInOut);
  }

  void _nextStep() {
    if (_step == 0) {
      if (!_step1FormKey.currentState!.validate()) return;
      if (_validEntries.isEmpty) {
        _snack('Add at least one expense with name and amount', warn: true);
        return;
      }
    }
    _goTo((_step + 1).clamp(0, 2));
  }

  void _prevStep() => _goTo((_step - 1).clamp(0, 2));

  // ── Snack ────────────────────────────────────────────────────────────────────
  void _snack(String msg, {bool warn = false, bool error = false}) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(
      content: Text(msg),
      backgroundColor: error ? AppColors.error : warn ? Colors.orange.shade700 : AppColors.success,
    ));
  }

  // ── Image picking ────────────────────────────────────────────────────────────
  Future<void> _addImages() async {
    final isDesktop = !Platform.isAndroid && !Platform.isIOS;
    try {
      if (isDesktop) {
        final result = await FilePicker.platform.pickFiles(
          type: FileType.custom,
          allowedExtensions: ['jpg', 'jpeg', 'png', 'webp', 'heic', 'pdf'],
          allowMultiple: true,
        );
        if (result != null && mounted) {
          setState(() {
            _billImages.addAll(
                result.files.where((f) => f.path != null).map((f) => File(f.path!)));
          });
        }
      } else {
        _showMobilePicker();
      }
    } catch (e) {
      _snack('Could not pick file: $e', error: true);
    }
  }

  void _showMobilePicker() {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => SafeArea(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          Container(margin: const EdgeInsets.symmetric(vertical: 10), width: 36, height: 4,
              decoration: BoxDecoration(color: Colors.grey.shade300, borderRadius: BorderRadius.circular(2))),
          const Text('Add Bill / Receipt', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
          const SizedBox(height: 8),
          ListTile(leading: const Icon(Icons.camera_alt_rounded, color: AppColors.primary), title: const Text('Take Photo'),
            onTap: () async {
              Navigator.pop(ctx);
              final img = await ImagePicker().pickImage(source: ImageSource.camera, imageQuality: 85);
              if (img != null && mounted) setState(() => _billImages.add(File(img.path)));
            },
          ),
          ListTile(leading: const Icon(Icons.photo_library_rounded, color: AppColors.primary), title: const Text('Choose from Gallery'),
            onTap: () async {
              Navigator.pop(ctx);
              final imgs = await ImagePicker().pickMultiImage(imageQuality: 85);
              if (imgs.isNotEmpty && mounted) setState(() => _billImages.addAll(imgs.map((x) => File(x.path))));
            },
          ),
          const SizedBox(height: 8),
        ]),
      ),
    );
  }

  // ── AI OCR Receipt Scan ───────────────────────────────────────────────────────
  Future<void> _scanReceiptWithAi(File imageFile) async {
    if (!AiConfig.aiEnabled) {
      _snack('Add your free Gemini API key in ai_config.dart to enable AI scanning', warn: true);
      return;
    }
    setState(() => _ocrScanning = true);
    try {
      // Step 1: ML Kit extracts raw text (on-device, free)
      final rawText = await ReceiptOcrService.extractText(imageFile);
      if (rawText.trim().isEmpty) {
        _snack('Could not read text from image. Try a clearer photo.', warn: true);
        return;
      }

      // Step 2: Gemini structures the extracted text
      final data = await AiService.parseReceiptText(rawText);
      if (data == null) {
        _snack('AI could not parse receipt. Fill fields manually.', warn: true);
        return;
      }

      // Step 3: Show confirm dialog
      if (!mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (_) => _OcrResultDialog(data: data),
      );

      // Step 4: Fill fields if confirmed
      if (confirmed == true && mounted) {
        setState(() {
          if (data.merchantName.isNotEmpty && _entries.isNotEmpty) {
            _entries[0].nameCtrl.text = data.merchantName;
          }
          if (data.amount > 0 && _entries.isNotEmpty) {
            _entries[0].amountCtrl.text = data.amount.toStringAsFixed(2);
          }
          if (data.category.isNotEmpty) {
            _entries[0].category = data.category;
            _claimCategory = data.category;
          }
          if (data.date != null) _claimDate = data.date!;
          if (data.description.isNotEmpty) {
            _remarksCtrl.text = data.description;
          }
        });
        _snack('✨ AI filled fields from receipt!');
        // Jump to review step
        _goTo(0);
      }
    } catch (e) {
      _snack('Scan failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _ocrScanning = false);
    }
  }

  // ── PDF builder ───────────────────────────────────────────────────────────────
  Future<Uint8List> _buildPdf(String employeeName) async {
    final doc  = pw.Document();
    final fmt  = NumberFormat('#,##0.00');
    final valid = _validEntries;
    final total = valid.fold(0.0, (s, e) => s + e.amount);
    final refNo = 'EC-${DateTime.now().millisecondsSinceEpoch.toString().substring(5)}';
    final dateStr      = DateFormat('d MMMM yyyy').format(_claimDate);
    final submittedStr = DateFormat('d MMMM yyyy, hh:mm a').format(DateTime.now());

    Uint8List? logoBytes;
    try {
      final data = await rootBundle.load('assets/CREANNO_Icon.png');
      logoBytes = data.buffer.asUint8List();
    } catch (_) {}

    final billData = <Uint8List>[];
    for (final f in _billImages) {
      try {
        if (await f.exists()) {
          final bytes = await f.readAsBytes();
          // only embed images (skip pdf attachments)
          final ext = f.path.split('.').last.toLowerCase();
          if (['jpg','jpeg','png','webp'].contains(ext)) billData.add(bytes);
        }
      } catch (_) {}
    }

    doc.addPage(pw.MultiPage(
      pageFormat: PdfPageFormat.a4,
      margin: const pw.EdgeInsets.all(36),
      header: (ctx) => pw.Container(
        padding: const pw.EdgeInsets.only(bottom: 10),
        decoration: const pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.blueGrey200, width: 1))),
        child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Row(children: [
            if (logoBytes != null) ...[
              pw.Image(pw.MemoryImage(logoBytes), width: 36, height: 36),
              pw.SizedBox(width: 10),
            ],
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              pw.Text('CREANNO', style: pw.TextStyle(fontSize: 17, fontWeight: pw.FontWeight.bold, color: PdfColors.blueGrey900)),
              pw.Text('Agency Expense Claim Form', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            ]),
          ]),
          pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
            pw.Text('Ref: $refNo', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo800)),
            pw.Text('Submitted: $submittedStr', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
          ]),
        ]),
      ),
      footer: (ctx) => pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
        pw.Text('CREANNO — Confidential Internal Document', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
        pw.Text('Page ${ctx.pageNumber} of ${ctx.pagesCount}', style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey500)),
      ]),
      build: (ctx) => [
        pw.SizedBox(height: 16),
        // Info box
        pw.Container(
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(
            color: PdfColors.indigo50,
            borderRadius: const pw.BorderRadius.all(pw.Radius.circular(6)),
            border: pw.Border.all(color: PdfColors.indigo100),
          ),
          child: pw.Row(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
              _pdfField('Team Member', employeeName),
              pw.SizedBox(height: 5),
              _pdfField('Project', _projectCtrl.text.trim()),
              pw.SizedBox(height: 5),
              _pdfField('Category', _catLabel(_claimCategory)),
              pw.SizedBox(height: 5),
              _pdfField('Expense Date', dateStr),
              if (_remarksCtrl.text.trim().isNotEmpty) ...[
                pw.SizedBox(height: 5),
                _pdfField('Remarks', _remarksCtrl.text.trim()),
              ],
            ])),
            pw.SizedBox(width: 20),
            pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.end, children: [
              pw.Text('TOTAL CLAIM', style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
              pw.SizedBox(height: 4),
              pw.Text('Rs. ${fmt.format(total)}',
                  style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: PdfColors.green800)),
              pw.SizedBox(height: 4),
              pw.Text('${valid.length} expense item${valid.length == 1 ? '' : 's'}',
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey600)),
            ]),
          ]),
        ),
        pw.SizedBox(height: 20),
        pw.Text('Expense Breakdown', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
        pw.SizedBox(height: 8),
        pw.Table(
          border: pw.TableBorder.all(color: PdfColors.blueGrey100, width: 0.5),
          columnWidths: const {
            0: pw.FixedColumnWidth(30),
            1: pw.FlexColumnWidth(3),
            2: pw.FixedColumnWidth(110),
            3: pw.FixedColumnWidth(110),
          },
          children: [
            pw.TableRow(decoration: const pw.BoxDecoration(color: PdfColors.indigo800), children: [
              _pdfCell('#', isHeader: true),
              _pdfCell('Expense Name', isHeader: true),
              _pdfCell('Category', isHeader: true),
              _pdfCell('Amount (Rs.)', isHeader: true, align: pw.TextAlign.right),
            ]),
            ...valid.asMap().entries.map((entry) => pw.TableRow(
              decoration: pw.BoxDecoration(color: entry.key.isEven ? PdfColors.white : PdfColors.grey50),
              children: [
                _pdfCell('${entry.key + 1}'),
                _pdfCell(entry.value.name),
                _pdfCell(_catLabel(entry.value.category)),
                _pdfCell(fmt.format(entry.value.amount), align: pw.TextAlign.right),
              ],
            )),
            pw.TableRow(
              decoration: const pw.BoxDecoration(color: PdfColors.lightGreen50),
              children: [
                _pdfCell('', isTotal: true),
                _pdfCell('GRAND TOTAL', isTotal: true),
                _pdfCell('', isTotal: true),
                _pdfCell('Rs. ${fmt.format(total)}', isTotal: true, align: pw.TextAlign.right),
              ],
            ),
          ],
        ),
        pw.SizedBox(height: 28),
        pw.Row(children: [
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 5),
            pw.Text('Member Signature', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text(employeeName, style: const pw.TextStyle(fontSize: 10)),
          ])),
          pw.SizedBox(width: 40),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 5),
            pw.Text('Manager Approval', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text('Date: _____________', style: const pw.TextStyle(fontSize: 10)),
          ])),
          pw.SizedBox(width: 40),
          pw.Expanded(child: pw.Column(crossAxisAlignment: pw.CrossAxisAlignment.start, children: [
            pw.Container(height: 1, color: PdfColors.grey400),
            pw.SizedBox(height: 5),
            pw.Text('Accounts Verified', style: const pw.TextStyle(fontSize: 9, color: PdfColors.grey600)),
            pw.SizedBox(height: 2),
            pw.Text('Date: _____________', style: const pw.TextStyle(fontSize: 10)),
          ])),
        ]),
        if (billData.isNotEmpty) ...[
          pw.SizedBox(height: 28),
          pw.Text('Bill Attachments (${billData.length})', style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 10),
          ...List.generate((billData.length + 2) ~/ 3, (rowIdx) {
            final start = rowIdx * 3;
            final end   = (start + 3).clamp(0, billData.length);
            final rowItems = billData.sublist(start, end);
            return pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Row(children: rowItems.map((bytes) => pw.Padding(
                padding: const pw.EdgeInsets.only(right: 8),
                child: pw.Container(
                  decoration: pw.BoxDecoration(border: pw.Border.all(color: PdfColors.grey300, width: 0.5)),
                  child: pw.Image(pw.MemoryImage(bytes), width: 155, height: 115, fit: pw.BoxFit.cover),
                ),
              )).toList()),
            );
          }),
        ],
      ],
    ));

    return doc.save();
  }

  pw.Widget _pdfField(String label, String value) => pw.RichText(text: pw.TextSpan(children: [
    pw.TextSpan(text: '$label: ', style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold)),
    pw.TextSpan(text: value, style: const pw.TextStyle(fontSize: 10)),
  ]));

  pw.Widget _pdfCell(String text, {bool isHeader = false, bool isTotal = false, pw.TextAlign align = pw.TextAlign.left}) =>
      pw.Padding(
        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 7),
        child: pw.Text(text, textAlign: align,
            style: pw.TextStyle(
              fontSize: isHeader ? 9 : 10,
              fontWeight: (isHeader || isTotal) ? pw.FontWeight.bold : pw.FontWeight.normal,
              color: isHeader ? PdfColors.white : isTotal ? PdfColors.green900 : PdfColors.black,
            )),
      );

  Future<void> _previewPdf(String employeeName) async {
    setState(() => _pdfGenerating = true);
    try {
      final bytes = await _buildPdf(employeeName);
      final dir   = await getTemporaryDirectory();
      final file  = File('${dir.path}/CREANNO_Claim_Preview.pdf');
      await file.writeAsBytes(bytes);
      final result = await OpenFile.open(file.path);
      if (result.type != ResultType.done && mounted) {
        _snack('Could not open PDF: ${result.message}', warn: true);
      }
    } catch (e) {
      _snack('PDF error: $e', error: true);
    } finally {
      if (mounted) setState(() => _pdfGenerating = false);
    }
  }

  Future<void> _submit(String employeeName) async {
    setState(() => _submitting = true);
    try {
      final pdfBytes = await _buildPdf(employeeName);
      final dir      = await getTemporaryDirectory();
      final pdfFile  = File('${dir.path}/CREANNO_Expense_Claim.pdf');
      await pdfFile.writeAsBytes(pdfBytes);

      final valid = _validEntries;
      final total = valid.fold(0.0, (s, e) => s + e.amount);

      final description = [
        ...valid.asMap().entries.map((e) =>
            '${e.key + 1}. ${e.value.name} [${_catLabel(e.value.category)}]: Rs.${e.value.amount.toStringAsFixed(2)}'),
        '',
        'Grand Total: Rs.${total.toStringAsFixed(2)}',
        if (_remarksCtrl.text.trim().isNotEmpty) 'Remarks: ${_remarksCtrl.text.trim()}',
      ].join('\n');

      final billFiles = <MultipartFile>[];
      for (final img in _billImages) {
        if (await img.exists()) {
          billFiles.add(await MultipartFile.fromFile(
            img.path, filename: img.path.split(Platform.pathSeparator).last));
        }
      }
      billFiles.add(await MultipartFile.fromFile(pdfFile.path, filename: 'CREANNO_Expense_Claim.pdf'));

      final formData = FormData.fromMap({
        'title': '${_catLabel(_claimCategory)}: ${_projectCtrl.text.trim()}',
        'category': _claimCategory,
        'amount': total.toStringAsFixed(2),
        'expenseDate': DateFormat('yyyy-MM-dd').format(_claimDate),
        'description': description,
        'remarks': _remarksCtrl.text.trim(),
        'bills': billFiles,
      });

      await api.postForm('/reimbursements', formData);

      if (mounted) {
        context.go('/reimbursements');
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Row(children: [
            Icon(Icons.check_circle, color: Colors.white, size: 18),
            SizedBox(width: 8),
            Expanded(child: Text('Expense claim submitted successfully!')),
          ]),
          backgroundColor: AppColors.success,
          duration: Duration(seconds: 3),
        ));
      }
    } catch (e) {
      _snack('Submission failed: $e', error: true);
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════════
  //  BUILD
  // ═══════════════════════════════════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final user         = ref.watch(authStateProvider).valueOrNull;
    final employeeName = user?.fullName ?? 'Team Member';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Submit Expense Claim', style: TextStyle(fontWeight: FontWeight.w700)),
        leading: _step == 0
            ? IconButton(icon: const Icon(Icons.close_rounded), tooltip: 'Cancel',
                onPressed: () => context.go('/reimbursements'))
            : IconButton(icon: const Icon(Icons.arrow_back_rounded), onPressed: _prevStep),
        actions: [
          if (_step == 2)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: OutlinedButton.icon(
                onPressed: _pdfGenerating ? null : () => _previewPdf(employeeName),
                icon: _pdfGenerating
                    ? const SizedBox(width: 14, height: 14, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Icon(Icons.picture_as_pdf_rounded, size: 16),
                label: const Text('Preview PDF'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.red.shade700,
                  side: BorderSide(color: Colors.red.shade300),
                ),
              ),
            ),
        ],
      ),
      body: Column(children: [
        // ── Step indicator ──────────────────────────────────────────────────
        _StepIndicator(currentStep: _step, onTap: (i) { if (i < _step) _goTo(i); }),

        // ── Page view (non-swipeable) ───────────────────────────────────────
        Expanded(
          child: PageView(
            controller: _pageCtrl,
            physics: const NeverScrollableScrollPhysics(),
            children: [
              // ── STEP 1 : Expenses ─────────────────────────────────────────
              _Step1Expenses(
                formKey:        _step1FormKey,
                projectCtrl:    _projectCtrl,
                remarksCtrl:    _remarksCtrl,
                entries:        _entries,
                date:           _claimDate,
                total:          _total,
                claimCategory:  _claimCategory,
                onDateChanged:  (d) => setState(() => _claimDate = d),
                onCatChanged:   (c) => setState(() => _claimCategory = c),
                onAddRow:       () => setState(() => _entries.add(_ExpenseEntry())),
                onRemoveRow:    (i) => setState(() { _entries[i].dispose(); _entries.removeAt(i); }),
                onEntryChanged: () => setState(() {}),
                onNext:         _nextStep,
              ),

              // ── STEP 2 : Bills ────────────────────────────────────────────
              _Step2Bills(
                images:      _billImages,
                onAdd:       _addImages,
                onRemove:    (i) => setState(() => _billImages.removeAt(i)),
                onNext:      _nextStep,
                onBack:      _prevStep,
                ocrScanning: _ocrScanning,
                onScanAi:    (Platform.isAndroid || Platform.isIOS) && AiConfig.aiEnabled
                    ? (file) => _scanReceiptWithAi(file)
                    : null,
              ),

              // ── STEP 3 : Review & Submit ──────────────────────────────────
              _Step3Review(
                projectName:    _projectCtrl.text,
                claimCategory:  _claimCategory,
                entries:        _validEntries,
                total:          _total,
                date:           _claimDate,
                remarks:        _remarksCtrl.text,
                employeeName:   employeeName,
                billCount:      _billImages.length,
                submitting:     _submitting,
                onEditStep:     _goTo,
                onSubmit:       () => _submit(employeeName),
              ),
            ],
          ),
        ),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STEP INDICATOR
// ═══════════════════════════════════════════════════════════════════════════════
class _StepIndicator extends StatelessWidget {
  final int currentStep;
  final void Function(int) onTap;
  const _StepIndicator({required this.currentStep, required this.onTap});

  static const _steps = [
    (label: 'Expenses',  icon: Icons.receipt_long_rounded),
    (label: 'Bills',     icon: Icons.attach_file_rounded),
    (label: 'Review',    icon: Icons.fact_check_rounded),
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Theme.of(context).cardColor,
        border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.12))),
      ),
      child: Row(children: List.generate(_steps.length * 2 - 1, (i) {
        if (i.isOdd) {
          final passed = currentStep > i ~/ 2;
          return Expanded(child: Container(height: 2, margin: const EdgeInsets.symmetric(horizontal: 4),
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(1),
                color: passed ? AppColors.primary : Colors.grey.withOpacity(0.22),
              )));
        }
        final idx      = i ~/ 2;
        final isActive = idx == currentStep;
        final isPassed = idx < currentStep;
        return GestureDetector(
          onTap: () => onTap(idx),
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              width: 34, height: 34,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: isPassed ? AppColors.success : isActive ? AppColors.primary : Colors.grey.withOpacity(0.15),
                boxShadow: isActive ? [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 8, offset: const Offset(0,2))] : null,
              ),
              child: Center(child: isPassed
                  ? const Icon(Icons.check_rounded, color: Colors.white, size: 16)
                  : Icon(_steps[idx].icon,
                      color: isActive ? Colors.white : AppColors.textTertiary, size: 16)),
            ),
            const SizedBox(height: 4),
            Text(_steps[idx].label,
                style: TextStyle(fontSize: 10, fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                    color: isActive ? AppColors.primary : isPassed ? AppColors.success : AppColors.textTertiary)),
          ]),
        );
      })),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STEP 1 — EXPENSES
// ═══════════════════════════════════════════════════════════════════════════════
class _Step1Expenses extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController projectCtrl;
  final TextEditingController remarksCtrl;
  final List<_ExpenseEntry> entries;
  final DateTime date;
  final double total;
  final String claimCategory;
  final ValueChanged<DateTime> onDateChanged;
  final ValueChanged<String> onCatChanged;
  final VoidCallback onAddRow;
  final void Function(int) onRemoveRow;
  final VoidCallback onEntryChanged;
  final VoidCallback onNext;

  const _Step1Expenses({
    required this.formKey, required this.projectCtrl, required this.remarksCtrl,
    required this.entries, required this.date, required this.total,
    required this.claimCategory, required this.onDateChanged,
    required this.onCatChanged, required this.onAddRow, required this.onRemoveRow,
    required this.onEntryChanged, required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return Form(
      key: formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          // ── Header hint ────────────────────────────────────────────────────
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.06),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.18)),
            ),
            child: Row(children: const [
              Icon(Icons.lightbulb_outline_rounded, color: AppColors.primary, size: 16),
              SizedBox(width: 8),
              Expanded(child: Text(
                'Fill in all expenses, choose category, then tap "Next → Add Bills".',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              )),
            ]),
          ),
          const SizedBox(height: 16),

          // ── Project Name ───────────────────────────────────────────────────
          TextFormField(
            controller: projectCtrl,
            decoration: const InputDecoration(
              labelText: 'Project Name *',
              hintText: 'e.g. Sharma Residence — Interior Design',
              prefixIcon: Icon(Icons.work_outline_rounded),
            ),
            validator: (v) => (v == null || v.trim().isEmpty) ? 'Project name is required' : null,
          ),
          const SizedBox(height: 12),

          // ── Date ───────────────────────────────────────────────────────────
          InkWell(
            onTap: () async {
              final picked = await showDatePicker(
                context: context, initialDate: date,
                firstDate: DateTime(2020), lastDate: DateTime.now(),
              );
              if (picked != null) onDateChanged(picked);
            },
            borderRadius: BorderRadius.circular(12),
            child: InputDecorator(
              decoration: const InputDecoration(
                labelText: 'Expense Date',
                prefixIcon: Icon(Icons.calendar_today_rounded),
              ),
              child: Text(DateFormat('d MMMM yyyy').format(date)),
            ),
          ),
          const SizedBox(height: 12),

          // ── Claim Category ─────────────────────────────────────────────────
          DropdownButtonFormField<String>(
            value: claimCategory,
            decoration: const InputDecoration(
              labelText: 'Claim Category *',
              prefixIcon: Icon(Icons.category_rounded),
            ),
            items: _kCategories.map((c) => DropdownMenuItem(
              value: c.value,
              child: Row(children: [
                Icon(c.icon, size: 16, color: AppColors.primary),
                const SizedBox(width: 8),
                Text(c.label),
              ]),
            )).toList(),
            onChanged: (v) { if (v != null) onCatChanged(v); },
          ),
          const SizedBox(height: 20),

          // ── Expense Table ──────────────────────────────────────────────────
          // Header
          Container(
            decoration: const BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            child: const Row(children: [
              SizedBox(width: 28, child: Text('#', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
              Expanded(flex: 3, child: Text('Expense Name', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 8),
              SizedBox(width: 80, child: Text('Category', style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11), overflow: TextOverflow.ellipsis)),
              SizedBox(width: 8),
              SizedBox(width: 80, child: Text('Amount (Rs.)', textAlign: TextAlign.right, style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 11))),
              SizedBox(width: 28),
            ]),
          ),

          // Rows
          Container(
            decoration: BoxDecoration(
              border: Border.all(color: Colors.grey.withOpacity(0.15)),
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(12)),
            ),
            child: Column(children: [
              ...entries.asMap().entries.map((e) => _ExpenseRowWidget(
                index: e.key,
                entry: e.value,
                canDelete: entries.length > 1,
                isLast: e.key == entries.length - 1,
                onDelete: () => onRemoveRow(e.key),
                onChanged: onEntryChanged,
              )),
              // Total row
              Container(
                decoration: BoxDecoration(
                  color: AppColors.success.withOpacity(0.07),
                  border: Border(top: BorderSide(color: Colors.grey.withOpacity(0.18))),
                  borderRadius: const BorderRadius.vertical(bottom: Radius.circular(11)),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
                child: Row(children: [
                  const SizedBox(width: 28),
                  const Expanded(flex: 3, child: Text('GRAND TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
                  const SizedBox(width: 8),
                  const SizedBox(width: 80),
                  const SizedBox(width: 8),
                  SizedBox(width: 80, child: Text('Rs. ${fmt.format(total)}',
                      textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: AppColors.success))),
                  const SizedBox(width: 28),
                ]),
              ),
            ]),
          ),
          const SizedBox(height: 10),

          // Add row button
          OutlinedButton.icon(
            onPressed: onAddRow,
            icon: const Icon(Icons.add_rounded, size: 18),
            label: const Text('Add Expense Row'),
            style: OutlinedButton.styleFrom(
              foregroundColor: AppColors.primary,
              side: BorderSide(color: AppColors.primary.withOpacity(0.4)),
              padding: const EdgeInsets.symmetric(vertical: 12),
            ),
          ),
          const SizedBox(height: 16),

          // Remarks field
          TextFormField(
            controller: remarksCtrl,
            maxLines: 2,
            maxLength: 200,
            decoration: const InputDecoration(
              labelText: 'Additional Remarks (optional)',
              hintText: 'e.g. Client site visit for project kickoff. Petrol bills attached.',
              prefixIcon: Icon(Icons.notes_rounded),
            ),
          ),
          const SizedBox(height: 24),

          // ── NEXT BUTTON (embedded inside scroll — always visible) ───────────
          _NextButton(
            label: 'Next  →  Add Bills',
            sublabel: total > 0 ? 'Total: Rs. ${NumberFormat('#,##0.00').format(total)}' : 'Fill expenses above',
            enabled: true,
            onTap: onNext,
          ),
          const SizedBox(height: 8),
        ],
      ),
    );
  }
}

// ── Expense row widget ────────────────────────────────────────────────────────
class _ExpenseRowWidget extends StatefulWidget {
  final int index;
  final _ExpenseEntry entry;
  final bool canDelete;
  final bool isLast;
  final VoidCallback onDelete;
  final VoidCallback onChanged;

  const _ExpenseRowWidget({
    required this.index, required this.entry, required this.canDelete,
    required this.isLast, required this.onDelete, required this.onChanged,
  });

  @override
  State<_ExpenseRowWidget> createState() => _ExpenseRowWidgetState();
}

class _ExpenseRowWidgetState extends State<_ExpenseRowWidget> {
  @override
  Widget build(BuildContext context) {
    final isEven = widget.index.isEven;
    return Container(
      decoration: BoxDecoration(
        color: isEven ? Colors.transparent : Colors.grey.withOpacity(0.025),
        border: widget.isLast ? null : Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.1))),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 2),
      child: Row(crossAxisAlignment: CrossAxisAlignment.center, children: [
        // Row number
        SizedBox(width: 28, child: Text('${widget.index + 1}',
            style: const TextStyle(color: AppColors.textTertiary, fontSize: 12))),
        // Expense name
        Expanded(flex: 3, child: TextField(
          controller: widget.entry.nameCtrl,
          onChanged: (_) => widget.onChanged(),
          decoration: const InputDecoration(
            hintText: 'Expense name...', border: InputBorder.none, isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
          style: const TextStyle(fontSize: 13),
        )),
        const SizedBox(width: 8),
        // Category mini picker
        SizedBox(
          width: 80,
          child: DropdownButton<String>(
            value: widget.entry.category,
            isExpanded: true,
            underline: const SizedBox.shrink(),
            style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
            items: _kCategories.map((c) => DropdownMenuItem(
              value: c.value,
              child: Text(c.label, style: const TextStyle(fontSize: 11), overflow: TextOverflow.ellipsis),
            )).toList(),
            onChanged: (v) { if (v != null) setState(() { widget.entry.category = v; widget.onChanged(); }); },
          ),
        ),
        const SizedBox(width: 8),
        // Amount
        SizedBox(width: 80, child: TextField(
          controller: widget.entry.amountCtrl,
          onChanged: (_) => widget.onChanged(),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          textAlign: TextAlign.right,
          inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[\d.]'))],
          decoration: const InputDecoration(
            hintText: '0.00', border: InputBorder.none, isDense: true,
            contentPadding: EdgeInsets.symmetric(vertical: 10),
          ),
          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
        )),
        // Delete
        SizedBox(width: 28, child: widget.canDelete
            ? IconButton(
                icon: const Icon(Icons.remove_circle_outline_rounded, size: 16, color: AppColors.error),
                onPressed: widget.onDelete, padding: EdgeInsets.zero, visualDensity: VisualDensity.compact)
            : const SizedBox.shrink()),
      ]),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STEP 2 — BILLS
// ═══════════════════════════════════════════════════════════════════════════════
class _Step2Bills extends StatelessWidget {
  final List<File> images;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  final VoidCallback onNext;
  final VoidCallback onBack;
  final bool ocrScanning;
  final void Function(File)? onScanAi;

  const _Step2Bills({
    required this.images, required this.onAdd, required this.onRemove,
    required this.onNext, required this.onBack,
    this.ocrScanning = false,
    this.onScanAi,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        // Info card
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(0.05),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.primary.withOpacity(0.18)),
          ),
          child: const Row(children: [
            Icon(Icons.info_outline_rounded, color: AppColors.primary, size: 16),
            SizedBox(width: 8),
            Expanded(child: Text(
              'Attach photos/scans of all receipts. Supported: JPG, PNG, PDF. Bills are embedded in the PDF report.',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            )),
          ]),
        ),
        const SizedBox(height: 12),

        // Bill count badge
        if (images.isNotEmpty) Row(children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
            decoration: BoxDecoration(color: AppColors.success.withOpacity(0.1), borderRadius: BorderRadius.circular(20)),
            child: Row(mainAxisSize: MainAxisSize.min, children: [
              const Icon(Icons.attach_file_rounded, size: 14, color: AppColors.success),
              const SizedBox(width: 4),
              Text('${images.length} file${images.length == 1 ? '' : 's'} attached',
                  style: const TextStyle(fontSize: 12, color: AppColors.success, fontWeight: FontWeight.w600)),
            ]),
          ),
          // ✨ AI Scan button (shows when images uploaded on mobile)
          if (onScanAi != null && images.isNotEmpty) ...[
            const Spacer(),
            GestureDetector(
              onTap: ocrScanning ? null : () => onScanAi!(images.last),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  gradient: LinearGradient(colors: [
                    AppColors.auroraViolet.withOpacity(0.85),
                    AppColors.auroraCyan.withOpacity(0.85),
                  ]),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [BoxShadow(
                    color: AppColors.auroraViolet.withOpacity(0.3),
                    blurRadius: 8,
                  )],
                ),
                child: ocrScanning
                    ? const SizedBox(width: 14, height: 14,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                    : const Row(mainAxisSize: MainAxisSize.min, children: [
                        Text('✨', style: TextStyle(fontSize: 12)),
                        SizedBox(width: 4),
                        Text('AI Scan & Fill',
                          style: TextStyle(fontSize: 11, color: Colors.white, fontWeight: FontWeight.w700)),
                      ]),
              ),
            ),
          ],
        ]),
        if (images.isNotEmpty) const SizedBox(height: 8),

        // Grid or empty state
        Expanded(child: images.isEmpty ? _EmptyBills(onAdd: onAdd) : _BillsGrid(images: images, onAdd: onAdd, onRemove: onRemove)),

        const SizedBox(height: 16),

        // ── Navigation ────────────────────────────────────────────────────────
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: onBack,
            icon: const Icon(Icons.arrow_back_rounded, size: 16),
            label: const Text('← Back'),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 14),
              foregroundColor: AppColors.textSecondary,
            ),
          )),
          const SizedBox(width: 12),
          Expanded(flex: 2, child: _NextButton(
            label: images.isEmpty ? 'Skip  →  Review' : 'Next  →  Review',
            sublabel: images.isEmpty ? 'You can submit without bills' : '${images.length} bill${images.length == 1 ? '' : 's'} attached',
            enabled: true,
            onTap: onNext,
          )),
        ]),
      ]),
    );
  }
}

class _EmptyBills extends StatelessWidget {
  final VoidCallback onAdd;
  const _EmptyBills({required this.onAdd});

  @override
  Widget build(BuildContext context) => Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
    Container(width: 80, height: 80,
        decoration: BoxDecoration(color: AppColors.primary.withOpacity(0.07), shape: BoxShape.circle),
        child: const Icon(Icons.receipt_long_rounded, size: 36, color: AppColors.primary)),
    const SizedBox(height: 16),
    const Text('No bills attached yet', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
    const SizedBox(height: 6),
    const Text('Tap below to add bill photos / PDFs', style: TextStyle(color: AppColors.textSecondary, fontSize: 13)),
    const SizedBox(height: 24),
    ElevatedButton.icon(
      onPressed: onAdd,
      icon: const Icon(Icons.add_photo_alternate_rounded),
      label: const Text('Add Bill Photos / PDF'),
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 13),
      ),
    ),
    const SizedBox(height: 8),
    const Text('You can also skip this step', style: TextStyle(color: AppColors.textTertiary, fontSize: 12)),
  ]));
}

class _BillsGrid extends StatelessWidget {
  final List<File> images;
  final VoidCallback onAdd;
  final void Function(int) onRemove;
  const _BillsGrid({required this.images, required this.onAdd, required this.onRemove});

  bool _isPdf(File f) => f.path.toLowerCase().endsWith('.pdf');

  @override
  Widget build(BuildContext context) => GridView.builder(
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3, crossAxisSpacing: 8, mainAxisSpacing: 8),
    itemCount: images.length + 1,
    itemBuilder: (ctx, i) {
      if (i == images.length) {
        return GestureDetector(onTap: onAdd, child: Container(
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary.withOpacity(0.4), style: BorderStyle.solid),
            borderRadius: BorderRadius.circular(12),
            color: AppColors.primary.withOpacity(0.04),
          ),
          child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [
            Icon(Icons.add_photo_alternate_rounded, color: AppColors.primary, size: 26),
            SizedBox(height: 4),
            Text('Add More', style: TextStyle(fontSize: 10, color: AppColors.primary, fontWeight: FontWeight.w500)),
          ]),
        ));
      }
      final file = images[i];
      return Stack(children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: _isPdf(file)
              ? Container(color: Colors.red.shade50,
                  child: const Center(child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.picture_as_pdf_rounded, color: Colors.red, size: 32),
                    Text('PDF', style: TextStyle(fontSize: 10, color: Colors.red, fontWeight: FontWeight.w600)),
                  ])))
              : Image.file(file, fit: BoxFit.cover, width: double.infinity, height: double.infinity,
                  errorBuilder: (_, __, ___) => const Center(child: Icon(Icons.broken_image_rounded, color: AppColors.textTertiary))),
        ),
        Positioned(top: 4, right: 4, child: GestureDetector(
          onTap: () => onRemove(i),
          child: Container(padding: const EdgeInsets.all(3),
              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
              child: const Icon(Icons.close_rounded, color: Colors.white, size: 12)),
        )),
        Positioned(bottom: 4, left: 4, child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 2),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(4)),
          child: Text('${i + 1}', style: const TextStyle(color: Colors.white, fontSize: 10)),
        )),
      ]);
    },
  );
}

// ═══════════════════════════════════════════════════════════════════════════════
//  STEP 3 — REVIEW & SUBMIT
// ═══════════════════════════════════════════════════════════════════════════════
class _Step3Review extends StatelessWidget {
  final String projectName;
  final String claimCategory;
  final List<_ExpenseEntry> entries;
  final double total;
  final DateTime date;
  final String remarks;
  final String employeeName;
  final int billCount;
  final bool submitting;
  final void Function(int) onEditStep;
  final VoidCallback onSubmit;

  const _Step3Review({
    required this.projectName, required this.claimCategory, required this.entries,
    required this.total, required this.date, required this.remarks,
    required this.employeeName, required this.billCount, required this.submitting,
    required this.onEditStep, required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    // group by category for summary
    final Map<String, double> byCat = {};
    for (final e in entries) {
      byCat[e.category] = (byCat[e.category] ?? 0) + e.amount;
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        // ── Total hero ────────────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppGradients.primary,
            borderRadius: BorderRadius.circular(16),
            boxShadow: AppShadows.glow(AppColors.primary, intensity: 0.2),
          ),
          child: Row(children: [
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('Total Claim Amount', style: TextStyle(color: Colors.white70, fontSize: 12)),
              const SizedBox(height: 4),
              Text('Rs. ${fmt.format(total)}',
                  style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w900)),
              const SizedBox(height: 4),
              Text('${entries.length} expense item${entries.length == 1 ? '' : 's'}  •  $projectName',
                  style: const TextStyle(color: Colors.white70, fontSize: 11), overflow: TextOverflow.ellipsis),
            ])),
            Container(padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.white.withOpacity(0.15), shape: BoxShape.circle),
                child: const Icon(Icons.receipt_long_rounded, color: Colors.white, size: 26)),
          ]),
        ),
        const SizedBox(height: 16),

        // ── Category breakdown ────────────────────────────────────────────────
        if (byCat.length > 1) ...[
          _ReviewCard(title: 'Breakdown by Category', child: Column(children: byCat.entries.map((e) => Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
            child: Row(children: [
              Icon(_kCategories.firstWhere((c) => c.value == e.key, orElse: () => _kCategories.last).icon,
                  size: 14, color: AppColors.primary),
              const SizedBox(width: 8),
              Expanded(child: Text(_catLabel(e.key), style: const TextStyle(fontSize: 13))),
              Text('Rs. ${fmt.format(e.value)}', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600)),
            ]),
          )).toList())),
          const SizedBox(height: 12),
        ],

        // ── Claim details ─────────────────────────────────────────────────────
        _ReviewCard(
          title: 'Claim Details',
          action: TextButton(onPressed: () => onEditStep(0), child: const Text('Edit')),
          child: Column(children: [
            _ReviewRow(label: 'Team Member', value: employeeName),
            _ReviewRow(label: 'Project',    value: projectName),
            _ReviewRow(label: 'Category',   value: _catLabel(claimCategory)),
            _ReviewRow(label: 'Date',       value: DateFormat('d MMMM yyyy').format(date)),
            if (remarks.trim().isNotEmpty) _ReviewRow(label: 'Remarks', value: remarks.trim()),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Expenses table ────────────────────────────────────────────────────
        _ReviewCard(
          title: 'Expenses (${entries.length})',
          action: TextButton(onPressed: () => onEditStep(0), child: const Text('Edit')),
          child: Column(children: [
            Container(color: AppColors.primary.withOpacity(0.07),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
                child: const Row(children: [
                  SizedBox(width: 26, child: Text('#', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary))),
                  Expanded(child: Text('Expense', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary))),
                  SizedBox(width: 80, child: Text('Category', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary))),
                  SizedBox(width: 70, child: Text('Amount', textAlign: TextAlign.right, style: TextStyle(fontWeight: FontWeight.bold, fontSize: 11, color: AppColors.textSecondary))),
                ])),
            ...entries.asMap().entries.map((e) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: e.key.isEven ? Colors.transparent : Colors.grey.withOpacity(0.025),
                border: Border(bottom: BorderSide(color: Colors.grey.withOpacity(0.07))),
              ),
              child: Row(children: [
                SizedBox(width: 26, child: Text('${e.key + 1}', style: const TextStyle(fontSize: 12, color: AppColors.textTertiary))),
                Expanded(child: Text(e.value.name, style: const TextStyle(fontSize: 12))),
                SizedBox(width: 80, child: Text(_catLabel(e.value.category),
                    style: const TextStyle(fontSize: 10, color: AppColors.textSecondary), overflow: TextOverflow.ellipsis)),
                SizedBox(width: 70, child: Text('₹${fmt.format(e.value.amount)}', textAlign: TextAlign.right,
                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600))),
              ]),
            )),
            Container(color: AppColors.success.withOpacity(0.06),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                child: Row(children: [
                  const SizedBox(width: 26),
                  const Expanded(child: Text('TOTAL', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13))),
                  const SizedBox(width: 80),
                  SizedBox(width: 70, child: Text('₹${fmt.format(total)}', textAlign: TextAlign.right,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: AppColors.success))),
                ])),
          ]),
        ),
        const SizedBox(height: 12),

        // ── Bills status ──────────────────────────────────────────────────────
        _ReviewCard(
          title: 'Bill Attachments',
          action: TextButton(onPressed: () => onEditStep(1), child: const Text('Edit')),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(children: [
              Icon(billCount > 0 ? Icons.check_circle_rounded : Icons.warning_amber_rounded,
                  color: billCount > 0 ? AppColors.success : AppColors.warning, size: 20),
              const SizedBox(width: 10),
              Expanded(child: Text(
                billCount > 0
                    ? '$billCount bill${billCount == 1 ? '' : 's'} attached — will be embedded in PDF'
                    : 'No bills attached — claim may be queried by accounts',
                style: TextStyle(fontSize: 13, color: billCount > 0 ? AppColors.textPrimary : AppColors.warning),
              )),
            ]),
          ),
        ),
        const SizedBox(height: 28),

        // ── Confirm + Submit ──────────────────────────────────────────────────
        Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.success.withOpacity(0.06),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.success.withOpacity(0.2)),
          ),
          child: const Text(
            '✅ By submitting, you confirm that all listed expenses are genuine, project-related, and supported by valid receipts.',
            style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
        ),
        const SizedBox(height: 14),

        // Submit button
        SizedBox(
          width: double.infinity,
          height: 54,
          child: ElevatedButton(
            onPressed: submitting ? null : onSubmit,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.success,
              disabledBackgroundColor: AppColors.success.withOpacity(0.5),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: submitting
                ? const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white)),
                    SizedBox(width: 12),
                    Text('Generating PDF & Submitting...', style: TextStyle(fontSize: 15, color: Colors.white)),
                  ])
                : const Row(mainAxisAlignment: MainAxisAlignment.center, children: [
                    Icon(Icons.send_rounded, color: Colors.white, size: 20),
                    SizedBox(width: 10),
                    Text('Submit Final Claim', style: TextStyle(fontSize: 16, color: Colors.white, fontWeight: FontWeight.bold)),
                  ]),
          ),
        ),
        const SizedBox(height: 32),
      ],
    );
  }
}

// ─── Shared review widgets ────────────────────────────────────────────────────
class _ReviewCard extends StatelessWidget {
  final String title;
  final Widget child;
  final Widget? action;
  const _ReviewCard({required this.title, required this.child, this.action});

  @override
  Widget build(BuildContext context) => Container(
    decoration: BoxDecoration(
      color: Theme.of(context).cardColor,
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: Colors.grey.withOpacity(0.12)),
      boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 6, offset: const Offset(0, 2))],
    ),
    clipBehavior: Clip.hardEdge,
    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
        child: Row(children: [
          Expanded(child: Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14))),
          if (action != null) action!,
        ]),
      ),
      const Divider(height: 1),
      child,
    ]),
  );
}

class _ReviewRow extends StatelessWidget {
  final String label, value;
  final TextStyle? valueStyle;
  const _ReviewRow({required this.label, required this.value, this.valueStyle});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
    child: Row(children: [
      SizedBox(width: 100, child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 13))),
      Expanded(child: Text(value, style: valueStyle ?? const TextStyle(fontSize: 13, fontWeight: FontWeight.w500))),
    ]),
  );
}

// ─── Reusable Next button (always inside scroll) ──────────────────────────────
class _NextButton extends StatelessWidget {
  final String label;
  final String sublabel;
  final bool enabled;
  final VoidCallback onTap;
  const _NextButton({required this.label, required this.sublabel, required this.enabled, required this.onTap});

  @override
  Widget build(BuildContext context) => GestureDetector(
    onTap: enabled ? onTap : null,
    child: Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
      decoration: BoxDecoration(
        gradient: enabled ? AppGradients.primary : null,
        color: enabled ? null : Colors.grey.shade300,
        borderRadius: BorderRadius.circular(14),
        boxShadow: enabled ? [BoxShadow(color: AppColors.primary.withOpacity(0.35), blurRadius: 12, offset: const Offset(0, 4))] : null,
      ),
      child: Row(mainAxisAlignment: MainAxisAlignment.center, children: [
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(label, style: TextStyle(color: enabled ? Colors.white : AppColors.textSecondary,
              fontSize: 15, fontWeight: FontWeight.bold)),
          if (sublabel.isNotEmpty)
            Text(sublabel, style: TextStyle(color: enabled ? Colors.white.withOpacity(0.75) : AppColors.textTertiary, fontSize: 11)),
        ])),
        Icon(Icons.arrow_forward_rounded, color: enabled ? Colors.white : AppColors.textTertiary, size: 20),
      ]),
    ),
  );
}

// ──────────────────────────────────────────────────────────────────────────────
//  ✨ OCR RESULT DIALOG
// ──────────────────────────────────────────────────────────────────────────────
class _OcrResultDialog extends StatelessWidget {
  final AiReceiptData data;
  const _OcrResultDialog({required this.data});

  String _catLabel(String val) {
    const labels = {
      'travel': 'Travel', 'food': 'Food & Meals', 'accommodation': 'Accommodation',
      'fuel': 'Fuel / Conveyance', 'medical': 'Medical', 'training': 'Training & Dev',
      'office_supplies': 'Office Supplies', 'client_entertainment': 'Client Entertainment',
      'other': 'Other',
    };
    return labels[val] ?? 'Other';
  }

  @override
  Widget build(BuildContext context) {
    final fmt = NumberFormat('#,##0.00');
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      title: Row(children: [
        const Text('✨', style: TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        ShaderMask(
          shaderCallback: (b) => AppGradients.aurora.createShader(b),
          child: const Text('AI Scanned Receipt',
            style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w800)),
        ),
      ]),
      content: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('AI detected these details. Tap "Fill Fields" to auto-fill your expense form.',
          style: TextStyle(fontSize: 12, color: AppColors.textSecondary)),
        const SizedBox(height: 16),
        _OcrRow(label: 'Merchant', value: data.merchantName.isEmpty ? '—' : data.merchantName),
        _OcrRow(label: 'Amount',   value: data.amount > 0 ? 'Rs. ${fmt.format(data.amount)}' : '—'),
        _OcrRow(label: 'Category', value: _catLabel(data.category)),
        if (data.date != null)
          _OcrRow(label: 'Date', value: DateFormat('d MMMM yyyy').format(data.date!)),
        if (data.description.isNotEmpty)
          _OcrRow(label: 'Note', value: data.description),
      ]),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: () => Navigator.pop(context, true),
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          child: const Text('✨ Fill Fields', style: TextStyle(color: Colors.white, fontWeight: FontWeight.w700)),
        ),
      ],
    );
  }
}

class _OcrRow extends StatelessWidget {
  final String label, value;
  const _OcrRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(children: [
      SizedBox(width: 70, child: Text(label,
        style: const TextStyle(fontSize: 12, color: AppColors.textSecondary, fontWeight: FontWeight.w600))),
      const SizedBox(width: 8),
      Expanded(child: Text(value,
        style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600))),
    ]),
  );
}
