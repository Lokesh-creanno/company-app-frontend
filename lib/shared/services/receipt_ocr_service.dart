import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

/// On-device ML Kit OCR — completely free, no internet needed.
/// Works on Android & iOS only (Windows not supported).
class ReceiptOcrService {
  static final _recognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Extracts all text from a bill / receipt image.
  /// Returns empty string on failure or unsupported platform.
  static Future<String> extractText(File imageFile) async {
    if (Platform.isWindows || Platform.isMacOS || Platform.isLinux) {
      return ''; // ML Kit not supported on desktop
    }
    try {
      final inputImage = InputImage.fromFile(imageFile);
      final result     = await _recognizer.processImage(inputImage);
      return result.text;
    } catch (_) {
      return '';
    }
  }

  static void dispose() => _recognizer.close();
}
