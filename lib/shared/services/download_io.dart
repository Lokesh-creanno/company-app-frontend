import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// Mobile/desktop: write to a temp file and open it with the OS default app.
Future<void> saveFile(List<int> bytes, String filename) async {
  final dir = await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(bytes, flush: true);
  await OpenFile.open(f.path);
}
