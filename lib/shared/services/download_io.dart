import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:open_file/open_file.dart';

// Mobile/desktop: write the file somewhere the user can reach it, then try to
// open it. On Android the app's external files dir is visible in any file
// manager, unlike the cache dir — and most phones have no .xlsx viewer, so we
// return the path for the caller to show instead of failing silently.
Future<String> saveFile(List<int> bytes, String filename) async {
  final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
  final f = File('${dir.path}/$filename');
  await f.writeAsBytes(bytes, flush: true);

  final opened = await OpenFile.open(f.path);
  if (opened.type == ResultType.done) return 'Opened $filename';
  return 'Saved to ${f.path}';
}
