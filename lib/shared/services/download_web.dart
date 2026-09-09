import 'dart:html' as html;

// Web: trigger a browser download via an object-URL blob.
Future<void> saveFile(List<int> bytes, String filename) async {
  final blob = html.Blob(<Object>[bytes]);
  final url = html.Url.createObjectUrlFromBlob(blob);
  final a = html.AnchorElement(href: url)..download = filename;
  html.document.body!.append(a);
  a.click();
  a.remove();
  html.Url.revokeObjectUrl(url);
}
