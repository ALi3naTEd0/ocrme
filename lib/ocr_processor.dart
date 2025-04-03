import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:ocrme/language_util.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'language_manager.dart';
import 'android_tesseract.dart'; // Add this import

// Create a result class to hold text and metadata (without confidence score)
class OcrResult {
  final String text;
  final String? engine; // Track which OCR engine was used
  final Map<String, dynamic>? metadata; // Additional data from OCR

  OcrResult(
    this.text, {
    this.engine = 'tesseract',
    this.metadata,
  });
}

// Define OCR Engine options - simplify to avoid conflicts
enum OcrEngine {
  tesseract, // Command-line Tesseract
  mlKit, // Keep this to avoid breaking existing code
  auto, // Try multiple engines and combine results
}

class OcrProcessor {
  final _logger = Logger('OcrProcessor');
  Map<String, dynamic> _config = {};
  String? _localTessdataDir;
  final LanguageManager _languageManager = LanguageManager();

  // Use direct public fields instead of getters/setters for better code clarity
  OcrEngine preferredEngine = OcrEngine.auto;
  bool enableTextValidation = true;
  bool enableMultipleEngines = true;

  // Expose language manager for settings page
  LanguageManager get languageManager => _languageManager;

  // Core languages that are bundled with the app - reduced to just essential languages
  static const List<String> bundledLanguages = [
    'eng', // English
    'spa', // Spanish
  ];

  static const Map<String, String> supportedLanguages = {
    'Afrikaans': 'afr',
    'Amharic': 'amh',
    'Arabic': 'ara',
    'Assamese': 'asm',
    'Azerbaijani': 'aze',
    'Azerbaijani (Cyrillic)': 'aze_cyrl',
    'Belarusian': 'bel',
    'Bengali': 'ben',
    'Tibetan': 'bod',
    'Bosnian': 'bos',
    'Breton': 'bre',
    'Bulgarian': 'bul',
    'Catalan': 'cat',
    'Cebuano': 'ceb',
    'Czech': 'ces',
    'Chinese (Simplified)': 'chi_sim',
    'Chinese (Simplified Vertical)': 'chi_sim_vert',
    'Chinese (Traditional)': 'chi_tra',
    'Chinese (Traditional Vertical)': 'chi_tra_vert',
    'Cherokee': 'chr',
    'Corsican': 'cos',
    'Welsh': 'cym',
    'Danish': 'dan',
    'Danish (Fraktur)': 'dan_frak',
    'German': 'deu',
    'German (Fraktur)': 'deu_frak',
    'German (Latin)': 'deu_latf',
    'Divehi': 'div',
    'Dzongkha': 'dzo',
    'Greek': 'ell',
    'English': 'eng',
    'Middle English': 'enm',
    'Esperanto': 'epo',
    'Math/equation': 'equ',
    'Estonian': 'est',
    'Basque': 'eus',
    'Faroese': 'fao',
    'Persian': 'fas',
    'Filipino': 'fil',
    'Finnish': 'fin',
    'French': 'fra',
    'Middle French': 'frm',
    'Western Frisian': 'fry',
    'Scottish Gaelic': 'gla',
    'Irish': 'gle',
    'Galician': 'glg',
    'Ancient Greek': 'grc',
    'Gujarati': 'guj',
    'Haitian': 'hat',
    'Hebrew': 'heb',
    'Hindi': 'hin',
    'Croatian': 'hrv',
    'Hungarian': 'hun',
    'Armenian': 'hye',
    'Inuktitut': 'iku',
    'Indonesian': 'ind',
    'Icelandic': 'isl',
    'Italian': 'ita',
    'Old Italian': 'ita_old',
    'Javanese': 'jav',
    'Japanese': 'jpn',
    'Japanese Vertical': 'jpn_vert',
    'Kannada': 'kan',
    'Georgian': 'kat',
    'Old Georgian': 'kat_old',
    'Kazakh': 'kaz',
    'Khmer': 'khm',
    'Kyrgyz': 'kir',
    'Kurdish Kurmanji': 'kmr',
    'Korean': 'kor',
    'Korean Vertical': 'kor_vert',
    'Lao': 'lao',
    'Latin': 'lat',
    'Latvian': 'lav',
    'Lithuanian': 'lit',
    'Luxembourgish': 'ltz',
    'Malayalam': 'mal',
    'Marathi': 'mar',
    'Macedonian': 'mkd',
    'Maltese': 'mlt',
    'Mongolian': 'mon',
    'Maori': 'mri',
    'Malay': 'msa',
    'Burmese': 'mya',
    'Nepali': 'nep',
    'Dutch': 'nld',
    'Norwegian': 'nor',
    'Occitan': 'oci',
    'Oriya': 'ori',
    'Orientation Script Detection': 'osd',
    'Punjabi': 'pan',
    'Polish': 'pol',
    'Portuguese': 'por',
    'Pashto': 'pus',
    'Quechua': 'que',
    'Romanian': 'ron',
    'Russian': 'rus',
    'Sanskrit': 'san',
    'Sinhala': 'sin',
    'Slovak': 'slk',
    'Slovak (Fraktur)': 'slk_frak',
    'Slovenian': 'slv',
    'Sindhi': 'snd',
    'Spanish': 'spa',
    'Old Spanish': 'spa_old',
    'Albanian': 'sqi',
    'Serbian': 'srp',
    'Serbian (Latin)': 'srp_latn',
    'Sundanese': 'sun',
    'Swahili': 'swa',
    'Swedish': 'swe',
    'Syriac': 'syr',
    'Tamil': 'tam',
    'Tatar': 'tat',
    'Telugu': 'tel',
    'Tajik': 'tgk',
    'Tagalog': 'tgl',
    'Thai': 'tha',
    'Tigrinya': 'tir',
    'Tonga': 'ton',
    'Turkish': 'tur',
    'Uyghur': 'uig',
    'Ukrainian': 'ukr',
    'Urdu': 'urd',
    'Uzbek': 'uzb',
    'Uzbek (Cyrillic)': 'uzb_cyrl',
    'Vietnamese': 'vie',
    'Yiddish': 'yid',
    'Yoruba': 'yor',
  };

  String _currentLanguage = 'eng';

  OcrProcessor() {
    _initializeOcr();

    // Set platform-specific default engine
    if (Platform.isAndroid || Platform.isIOS) {
      preferredEngine =
          OcrEngine.auto; // Default to auto on mobile (favoring ML Kit)
    } else if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
      preferredEngine = OcrEngine.tesseract; // Default to Tesseract on desktop
    }
  }

  Future<void> _initializeOcr() async {
    await _loadConfig();
    await _extractTessdata();
  }

  Future<void> _loadConfig() async {
    try {
      final configString = await rootBundle.loadString(
        'assets/tessdata_config.json',
      );
      _config = jsonDecode(configString);
      _logger.info('Loaded tessdata config: $_config');
    } catch (e) {
      _logger.severe('Failed to load tessdata config: $e');
      // Set default configuration if loading fails
      _config = {
        "tessdata-dir": "assets/tessdata",
        "preserve_interword_spaces": "1",
        "psm": "4",
      };
    }
  }

  Future<void> _extractTessdata() async {
    try {
      // Create a local directory to store the tessdata files
      final appDir = await getApplicationSupportDirectory();
      _localTessdataDir = path.join(appDir.path, 'tessdata');

      // Create the local tessdata directory if it doesn't exist
      final tessdataDir = Directory(_localTessdataDir!);
      if (!await tessdataDir.exists()) {
        await tessdataDir.create(recursive: true);
      }

      // Initialize language manager
      await _languageManager.initialize(_localTessdataDir!);

      // Only extract bundled languages that haven't been explicitly deleted by user
      for (final lang in bundledLanguages) {
        if (await _shouldExtractLanguage(lang)) {
          await _extractTrainedDataFile('$lang.traineddata');
          await _languageManager.markLanguageAsAvailable(lang);
        }
      }

      _logger.info('Core language files extracted to: $_localTessdataDir');
    } catch (e) {
      _logger.severe('Error extracting tessdata: $e');
    }
  }

  Future<bool> _shouldExtractLanguage(String langCode) async {
    // Check if it's in the list of languages marked as deleted by user
    bool isMarkedAsRemoved = await _languageManager.isLanguageMarkedAsRemoved(
      langCode,
    );
    return !isMarkedAsRemoved;
  }

  Future<void> _extractTrainedDataFile(String filename) async {
    try {
      final languageCode = filename.split('.').first;

      // Skip if not a bundled language
      if (!bundledLanguages.contains(languageCode)) {
        _logger.info(
          '$languageCode is not a bundled language, skipping extraction',
        );
        return;
      }

      final data = await rootBundle.load('assets/tessdata/$filename');
      final bytes = data.buffer.asUint8List();

      final localFile = File('${_localTessdataDir!}/$filename');
      await localFile.writeAsBytes(bytes);
      _logger.info('Extracted $filename to local storage');
    } catch (e) {
      _logger.severe('Error extracting $filename: $e');
    }
  }

  Future<void> setLanguage(String language) async {
    // Use both our focused list and the comprehensive list
    if (LanguageCatalog.supportedLanguages.values.contains(language) ||
        supportedLanguages.containsValue(language)) {
      // Check if language is available or needs download
      final bool isAvailable = await isLanguageAvailable(language);
      if (!isAvailable && !bundledLanguages.contains(language)) {
        _logger.info('Language $language not available, download required');
        return; // Don't set unavailable language - let caller handle download
      }

      _currentLanguage = language;
      _logger.info('Language set to: $language');
    }
  }

  Future<bool> isLanguageAvailable(String languageCode) async {
    return _languageManager.isLanguageAvailable(languageCode);
  }

  Future<bool> downloadLanguage(
    String languageCode, {
    Function(double)? onProgress,
  }) async {
    try {
      // Skip download if the language is already included in the app bundle
      if (bundledLanguages.contains(languageCode)) {
        return true; // Language is already available
      }

      bool success = await _languageManager.downloadLanguage(
        languageCode,
        onProgress: onProgress,
      );
      return success;
    } catch (e) {
      _logger.severe('Error downloading language $languageCode: $e');
      return false;
    }
  }

  Future<OcrResult> processImage(
    File imageFile, {
    Function(String)? onLanguageUnavailable,
  }) async {
    try {
      if (!await imageFile.exists()) {
        _logger.severe('File does not exist: ${imageFile.path}');
        return OcrResult('Error: File does not exist');
      }

      _logger.info('Processing image: ${imageFile.path}');

      // Check if the local tessdata directory is ready
      if (_localTessdataDir == null ||
          !await Directory(_localTessdataDir!).exists()) {
        await _extractTessdata();
      }

      // Check if the selected language is available
      if (!await isLanguageAvailable(_currentLanguage)) {
        if (onLanguageUnavailable != null) {
          onLanguageUnavailable(_currentLanguage);
          return OcrResult(
            'Language $_currentLanguage is not available. Please download it first.',
          );
        }
      }

      // Check if we're on desktop and using ML Kit
      if (Platform.isLinux || Platform.isWindows || Platform.isMacOS) {
        if (preferredEngine == OcrEngine.mlKit) {
          return await _processWithMlKitOnDesktop(imageFile);
        }
      }

      // For Android, use the Android-specific OCR implementation
      if (Platform.isAndroid) {
        return await _processWithAndroidTesseract(imageFile);
      }
      // Otherwise use the standard Tesseract command-line approach
      return await _processWithTesseract(imageFile);
    } catch (e) {
      _logger.severe('OCR Error: $e');
      return OcrResult('Error: ${e.toString()}');
    }
  }

  Future<OcrResult> _processWithAndroidTesseract(File imageFile) async {
    try {
      _logger.info('Using Google ML Kit implementation');

      // Get the image path and tessdata path
      final imagePath = imageFile.path;

      if (_localTessdataDir == null) {
        _logger.severe('Tessdata directory not initialized');
        return OcrResult(
          'Error: OCR not properly initialized',
          engine: 'ml_kit',
        );
      }

      _logger.info('Using tessdata directory: $_localTessdataDir');
      _logger.info(
        'Processing image: $imagePath with language $_currentLanguage',
      );

      try {
        // Add Spanish context hints when Spanish is selected
        Map<String, dynamic> hints = {};
        if (_currentLanguage == 'spa') {
          _logger.info('Adding Spanish language hints');
          hints['preferSpanishRecognition'] = true;
        }

        // Use the ML Kit implementation with language hints
        final result = await AndroidTesseract.performOcr(
          imagePath,
          _currentLanguage,
          _localTessdataDir!,
          hints: hints,
        );

        final String recognizedText = result['text'] as String? ?? '';

        // Apply text validation if enabled
        String finalText = recognizedText;
        if (enableTextValidation) {
          finalText = _validateAndCorrectText(recognizedText);
        }

        return OcrResult(
          finalText,
          engine: 'ml_kit',
          metadata: {'original_text': recognizedText},
        );
      } catch (e) {
        _logger.severe('ML Kit error: $e');

        // This is the fallback OCR method if Google ML Kit fails
        return _performFallbackOcr(imageFile);
      }
    } catch (e) {
      _logger.severe('ML Kit error: $e');
      return OcrResult(
        'Error: ${e.toString()}',
        engine: 'ml_kit',
      );
    }
  }

  Future<OcrResult> _processWithMlKitOnDesktop(File imageFile) async {
    try {
      _logger.info('Using ML Kit on desktop');

      // Get the image path
      final imagePath = imageFile.path;

      try {
        // Use the ML Kit implementation directly on desktop
        final result = await AndroidTesseract.performOcr(
          imagePath,
          _currentLanguage,
          _localTessdataDir ?? '',
        );

        final String recognizedText = result['text'] as String? ?? '';

        // Apply text validation if enabled
        String finalText = recognizedText;
        if (enableTextValidation) {
          finalText = _validateAndCorrectText(recognizedText);
        }

        return OcrResult(
          finalText,
          engine:
              'ml_kit_desktop', // Use a distinct name for desktop ML Kit implementation
          metadata: {'original_text': recognizedText},
        );
      } catch (e) {
        _logger.severe('ML Kit on desktop error: $e');
        return OcrResult(
          'Error: ML Kit is not fully supported on desktop. Please use Tesseract or Auto mode instead.',
          engine: 'ml_kit_error',
        );
      }
    } catch (e) {
      _logger.severe('ML Kit desktop processing error: $e');
      return OcrResult(
        'Error: ${e.toString()}',
        engine: 'ml_kit_error',
      );
    }
  }

  Future<OcrResult> _performFallbackOcr(File imageFile) async {
    _logger.info('Using fallback OCR method');

    const String fallbackText =
        "OCR processing failed. Try another image or reinstall the app.";

    return OcrResult(fallbackText, engine: 'fallback');
  }

  Future<OcrResult> _processWithTesseract(File imageFile) async {
    // Create a temporary directory for output
    final tempDir = await getTemporaryDirectory();
    final outputBase = path.join(tempDir.path, 'ocr_output');

    // Create config file with parameters
    final configFile = File('${tempDir.path}/tesseract_config.txt');
    await configFile.writeAsString('''
preserve_interword_spaces ${_config["preserve_interword_spaces"] ?? "1"}
''');

    _logger.info('Using tessdata directory: $_localTessdataDir');

    // TSV parameter for confidence scores
    const tsvParam = 'tsv';

    // Add language parameter to tesseract command with TSV output
    final result = await Process.run('tesseract', [
      imageFile.path,
      outputBase,
      '-l',
      _currentLanguage,
      '--tessdata-dir',
      _localTessdataDir!,
      '--psm',
      _config["psm"] ?? "4",
      configFile.path,
      tsvParam,
    ]);

    if (result.exitCode != 0) {
      _logger.severe('Tesseract error: ${result.stderr}');
      return OcrResult('Error: ${result.stderr}');
    }

    // Read the output file
    final outputFile = File('$outputBase.txt');
    String text = '';
    if (await outputFile.exists()) {
      text = await outputFile.readAsString();
      if (text.isEmpty) {
        _logger.warning('OCR result is empty');
        return OcrResult('No text found in image', engine: 'tesseract');
      }
    } else {
      _logger.warning('Output file not found');
      return OcrResult(
        'Error: Output file not generated',
        engine: 'tesseract',
      );
    }

    // Validate the OCR result
    if (enableTextValidation) {
      text = _validateAndCorrectText(text);
    }

    return OcrResult(text, engine: 'tesseract');
  }

  String _validateAndCorrectText(String text) {
    if (text.isEmpty) return text;

    // Common OCR errors and corrections
    Map<RegExp, String> commonErrors = {
      RegExp(r'(\d)l(\d)'): r'$11$2',
      RegExp(r'(\d)I(\d)'): r'$11$2',
      RegExp(r'l(\d)'): r'1$1',
      RegExp(r'O(\d)'): r'0$1',
      RegExp(r'(\d)O'): r'$10',
    };

    // Special processing for Spanish if current language is Spanish
    if (_currentLanguage == 'spa') {
      // For Spanish, use standard corrections but be careful with accented characters
      String corrected = text;

      // Apply common error corrections but skip the non-ASCII cleanup for Spanish
      for (var entry in commonErrors.entries) {
        corrected = corrected.replaceAll(entry.key, entry.value);
      }

      // Clean up multiple spaces
      corrected = corrected.replaceAll(RegExp(r'\s+'), ' ').trim();

      int changes = text.length - corrected.length;
      if (changes.abs() > 0) {
        _logger.info('Made $changes corrections to Spanish OCR text');
      }

      return corrected;
    }

    // For other languages, use the standard correction
    String corrected = text;
    commonErrors.forEach((pattern, replacement) {
      corrected = corrected.replaceAll(pattern, replacement);
    });

    // Also apply non-ASCII cleanup for non-Spanish languages
    corrected = corrected.replaceAll(RegExp(r'[^\x00-\x7F]+'), ' ');
    corrected = corrected.replaceAll(RegExp(r'\s+'), ' ').trim();

    int changes = text.length - corrected.length;
    if (changes.abs() > 0) {
      _logger.info('Made $changes corrections to OCR text');
    }

    return corrected;
  }

  Future<void> syncLanguages() async {
    await _languageManager.syncBundledLanguages();
  }
}
