import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:logging/logging.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

class AndroidTesseract {
  static final _logger =
      Logger('GoogleMLKit'); // Changed from 'AndroidTesseract'
  static final TextRecognizer _textRecognizer =
      TextRecognizer(script: TextRecognitionScript.latin);

  /// Perform OCR using Google ML Kit's text recognition
  static Future<Map<String, dynamic>> performOcr(
    String imagePath,
    String language,
    String tessdataPath, {
    Map<String, dynamic>? hints,
  }) async {
    try {
      // Check if image exists
      final file = File(imagePath);
      if (!await file.exists()) {
        throw Exception("Image file not found: $imagePath");
      }

      _logger.info("Starting Google ML Kit OCR"); // Updated log message

      // Create input image from file
      final inputImage = InputImage.fromFilePath(imagePath);

      // Configure text recognizer based on language
      TextRecognizer textRecognizer;
      if (language == 'spa' ||
          (hints != null && hints['preferSpanishRecognition'] == true)) {
        // Use Latin script explicitly for Spanish
        textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
        _logger.info("Using Latin script optimized for Spanish");
      } else {
        // Use default script selection
        textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      }

      // Use Google ML Kit to recognize text
      final recognizedText = await textRecognizer.processImage(inputImage);

      // Close the recognizer when done
      await textRecognizer.close();

      final text = recognizedText.text;

      // Post-process text to ensure Spanish characters are preserved
      final processedText = _processRecognizedText(text, language);

      _logger.info(
          "OCR completed with Google ML Kit: ${recognizedText.blocks.length} text blocks found");

      return {
        'text': processedText,
      };
    } catch (e) {
      _logger.severe("Error in Google ML Kit OCR: $e"); // Updated log message

      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        return await _performDesktopOcr(imagePath, language, tessdataPath);
      }

      return {
        'text': "Error processing image: ${e.toString()}",
      };
    }
  }

  /// Process recognized text to handle language-specific characters
  static String _processRecognizedText(String text, String language) {
    // Special handling for Spanish language
    if (language == 'spa') {
      // More comprehensive map for Spanish character recognition
      final Map<Pattern, String> replacements = {
        // Common character replacements
        'n~': 'ñ',
        'nˆ': 'ñ',
        'n˜': 'ñ',
        'n\\^': 'ñ',
        'n\\~': 'ñ',
        'n`': 'ñ',

        // Missing accents on vowels
        'a\u0301': 'á',
        'e\u0301': 'é',
        'i\u0301': 'í',
        'o\u0301': 'ó',
        'u\u0301': 'ú',

        // Spaces between letter and accent
        'a ́': 'á',
        'e ́': 'é',
        'i ́': 'í',
        'o ́': 'ó',
        'u ́': 'ú',

        // Uppercase accented vowels
        'A\u0301': 'Á',
        'E\u0301': 'É',
        'I\u0301': 'Í',
        'O\u0301': 'Ó',
        'U\u0301': 'Ú',
      };

      String processedText = text;
      replacements.forEach((pattern, replacement) {
        processedText = processedText.replaceAll(pattern, replacement);
      });
      return processedText;
    }

    // Otherwise just return the original text
    return text;
  }

  /// Desktop OCR handling with fallback to Tesseract command-line
  static Future<Map<String, dynamic>> _performDesktopOcr(
      String imagePath, String language, String tessdataPath) async {
    // If we're on desktop and explicitly requested ML Kit, try to use it directly
    try {
      // Try desktop ML Kit if possible
      final inputImage = InputImage.fromFilePath(imagePath);
      final recognizedText = await _textRecognizer.processImage(inputImage);

      _logger.info('Successfully used ML Kit on desktop');

      return {
        'text': recognizedText.text,
      };
    } catch (e) {
      _logger.warning('ML Kit on desktop failed: $e');

      // Try using the command-line Tesseract as fallback (preserves language support on desktop)
      if (Platform.isLinux || Platform.isMacOS) {
        try {
          // Check if Tesseract is installed
          final checkResult = await Process.run('which', ['tesseract']);
          if (checkResult.exitCode == 0) {
            _logger.info('Using command-line Tesseract on desktop');

            // Execute Tesseract with the provided language and tessdata path
            final result = await Process.run('tesseract', [
              imagePath,
              'stdout',
              '-l',
              language,
              '--tessdata-dir',
              tessdataPath
            ]);

            if (result.exitCode == 0) {
              return {
                'text': result.stdout.toString(),
              };
            }
          }
        } catch (e) {
          _logger.warning('Command-line Tesseract not available: $e');
        }
      }

      // Ultimate fallback - basic placeholder
      return {
        'text':
            'OCR not available on this platform. Please install Tesseract command-line tool.',
      };
    }
  }

  /// Set up the OCR engine
  static Future<bool> installTesseractFastModel() async {
    try {
      // We'll still maintain the tessdata directory for command-line Tesseract compatibility
      final appDir = await getApplicationSupportDirectory();
      final tessdataDir = Directory(path.join(appDir.path, 'tessdata'));

      if (!await tessdataDir.exists()) {
        await tessdataDir.create(recursive: true);
      }

      _logger.info('Created tessdata directory at: ${tessdataDir.path}');
      return true;
    } catch (e) {
      _logger.severe('Failed to set up OCR: $e');
      return false;
    }
  }

  /// Clean up resources when done
  static Future<void> closeOcr() async {
    await _textRecognizer.close();
  }
}
