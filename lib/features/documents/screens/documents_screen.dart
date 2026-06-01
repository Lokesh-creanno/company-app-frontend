import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:file_picker/file_picker.dart';
import 'package:dio/dio.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../shared/services/api_service.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../core/theme.dart';
import '../../../core/constants.dart';

final documentsProvider = FutureProvider.autoDispose<List<dynamic>>((ref) async {
  final response = await api.get('/documents/my');
  return response.data['data'] as List;
});

class DocumentsScreen extends ConsumerStatefulWidget {
  const DocumentsScreen({super.key});
  @override
  ConsumerState<DocumentsScreen> createState() => _DocumentsScreenState();
}

class _DocumentsScreenState extends ConsumerState<DocumentsScreen> {
  bool _uploading = false;

  Future<void> _upload() async {
    final result = await FilePicker.platform.pickFiles(type: FileType.custom, allowedExtensions: AppConstants.allowedDocTypes);
    if (result == null) return;

    final type = await _showTypeDialog();
    if (type == null) return;

    setState(() => _uploading = true);
    try {
      final file = result.files.first;
      final formData = FormData.fromMap({
        'file': await MultipartFile.fromFile(file.path!, filename: file.name),
        'name': file.name,
        'type': type,
      });
      await api.postForm('/documents', formData);
      ref.invalidate(documentsProvider);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Document uploaded!'), backgroundColor: AppColors.success));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  Future<String?> _showTypeDialog() => showDialog<String>(
    context: context,
    builder: (_) => AlertDialog(
      title: const Text('Document Type'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: AppConstants.documentTypes.entries.map((e) => ListTile(
          title: Text(e.value),
          onTap: () => Navigator.pop(context, e.key),
        )).toList(),
      ),
    ),
  );

  Future<void> _downloadDoc(String id) async {
    try {
      final response = await api.get('/documents/$id/download');
      final url = response.data['data']['url'];
      await launchUrl(Uri.parse(url));
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString()), backgroundColor: AppColors.error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final docsAsync = ref.watch(documentsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Documents'), actions: [
        if (_uploading) const Padding(padding: EdgeInsets.all(16), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))),
        IconButton(icon: const Icon(Icons.refresh), onPressed: () => ref.invalidate(documentsProvider)),
      ]),
      body: docsAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text(e.toString())),
        data: (docs) {
          if (docs.isEmpty) return Center(child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.folder_open_outlined, size: 72, color: AppColors.textTertiary),
              const SizedBox(height: 16),
              const Text('No documents yet', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
              const SizedBox(height: 8),
              ElevatedButton.icon(onPressed: _upload, icon: const Icon(Icons.upload_file), label: const Text('Upload Document')),
            ],
          ));

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: docs.length,
            itemBuilder: (ctx, i) => _DocumentCard(doc: docs[i] as Map<String, dynamic>, onDownload: () => _downloadDoc(docs[i]['id'])),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _upload,
        icon: const Icon(Icons.upload_file),
        label: const Text('Upload'),
        backgroundColor: AppColors.primary,
      ),
    );
  }
}

class _DocumentCard extends StatelessWidget {
  final Map<String, dynamic> doc;
  final VoidCallback onDownload;
  const _DocumentCard({required this.doc, required this.onDownload});

  IconData get _icon {
    final mime = doc['mimeType']?.toString() ?? '';
    if (mime.contains('pdf')) return Icons.picture_as_pdf;
    if (mime.contains('image')) return Icons.image_outlined;
    return Icons.insert_drive_file_outlined;
  }

  Color get _iconColor {
    final mime = doc['mimeType']?.toString() ?? '';
    if (mime.contains('pdf')) return AppColors.error;
    if (mime.contains('image')) return AppColors.primary;
    return AppColors.textSecondary;
  }

  String _formatSize(int? bytes) {
    if (bytes == null) return '';
    if (bytes < 1024) return '${bytes}B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)}KB';
    return '${(bytes / (1024 * 1024)).toStringAsFixed(1)}MB';
  }

  @override
  Widget build(BuildContext context) {
    return AppCard(
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: _iconColor.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Icon(_icon, color: _iconColor, size: 28),
          ),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(doc['name'] ?? '', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 14), maxLines: 1, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 4),
            Row(children: [
              Container(padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2), decoration: BoxDecoration(color: AppColors.surfaceVariant, borderRadius: BorderRadius.circular(4)), child: Text(AppConstants.documentTypes[doc['type']] ?? doc['type'] ?? '', style: const TextStyle(fontSize: 10, color: AppColors.textSecondary))),
              if (doc['fileSize'] != null) ...[const SizedBox(width: 8), Text(_formatSize(doc['fileSize']), style: const TextStyle(fontSize: 11, color: AppColors.textTertiary))],
            ]),
            if (doc['isVerified'] == true) Row(children: [const Icon(Icons.verified, color: AppColors.success, size: 14), const SizedBox(width: 4), const Text('Verified', style: TextStyle(color: AppColors.success, fontSize: 11))]),
          ])),
          IconButton(onPressed: onDownload, icon: const Icon(Icons.download_outlined, color: AppColors.primary)),
        ],
      ),
    );
  }
}
