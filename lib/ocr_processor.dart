import 'dart:io';
import 'dart:convert';
import 'package:logging/logging.dart';
import 'package:ocrme/language_util.dart';
import 'package:path_provider/path_provider.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:path/path.dart' as path;
import 'language_manager.dart';

// Create a result class to hold both text and confidence score
class OcrResult {
  final String text;
  final double? confidenceScore;
  final String? engine; // Track which OCR engine was used
  final Map<String, dynamic>? metadata; // Additional data from OCR

  OcrResult(this.text, this.confidenceScore,
      {this.engine = 'tesseract', this.metadata});
}

// Define OCR Engine options
enum OcrEngine {
  tesseract, // Command-line Tesseract
  mlKit, // Google ML Kit (will be used if available)
  auto // Try multiple engines and combine results
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
    bool isMarkedAsRemoved =
        await _languageManager.isLanguageMarkedAsRemoved(langCode);
    return !isMarkedAsRemoved;
  }

  Future<void> _extractTrainedDataFile(String filename) async {
    try {
      final languageCode = filename.split('.').first;

      // Skip if not a bundled language
      if (!bundledLanguages.contains(languageCode)) {
        _logger.info(
            '$languageCode is not a bundled language, skipping extraction');
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

  Future<bool> downloadLanguage(String languageCode,
      {Function(double)? onProgress}) async {
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

  Future<OcrResult> processImage(File imageFile,
      {Function(String)? onLanguageUnavailable}) async {
    try {
      if (!await imageFile.exists()) {
        _logger.severe('File does not exist: ${imageFile.path}');
        return OcrResult('Error: File does not exist', 0.0);
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
              0.0);
        }
      }

      // We'll just use Tesseract for now
      return await _processWithTesseract(imageFile);
    } catch (e) {
      _logger.severe('OCR Error: $e');
      return OcrResult('Error: ${e.toString()}', null);
    }
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
      return OcrResult('Error: ${result.stderr}', 0.0);
    }

    // Read the output file
    final outputFile = File('$outputBase.txt');
    String text = '';
    if (await outputFile.exists()) {
      text = await outputFile.readAsString();
      if (text.isEmpty) {
        _logger.warning('OCR result is empty');
        return OcrResult('No text found in image', null, engine: 'tesseract');
      }
    } else {
      _logger.warning('Output file not found');
      return OcrResult('Error: Output file not generated', null,
          engine: 'tesseract');
    }

    // Read the confidence file
    final confidenceFile = File('$outputBase.tsv');
    double? confidenceScore;

    if (await confidenceFile.exists()) {
      confidenceScore = await _calculateConfidenceScore(confidenceFile);
    }

    // Validate the OCR result
    if (enableTextValidation) {
      text = _validateAndCorrectText(text);
    }

    return OcrResult(text, confidenceScore, engine: 'tesseract');
  }

  Future<double?> _calculateConfidenceScore(File confidenceFile) async {
    try {
      final confidenceData = await confidenceFile.readAsString();
      final lines = confidenceData
          .split('\n')
          .where((line) => line.trim().isNotEmpty)
          .toList();

      // Skip header row
      if (lines.length > 1) {
        double totalConfidence = 0.0;
        int confCount = 0;
        List<double> confidences = [];

        // Start from 1 to skip header
        for (int i = 1; i < lines.length; i++) {
          final columns = lines[i].split('\t');
          if (columns.length > 10) {
            double conf = double.tryParse(columns[10]) ?? 0.0;
            if (conf <= 0 && columns.length > 8) {
              conf = double.tryParse(columns[8]) ?? 0.0;
            }
            if (conf > 0) {
              confidences.add(conf);
              totalConfidence += conf;
              confCount++;
            }
          }
        }

        if (confCount > 0) {
          if (confidences.length > 5) {
            confidences.sort();
            double median;
            if (confidences.length % 2 == 0) {
              median = (confidences[confidences.length ~/ 2] +
                      confidences[confidences.length ~/ 2 - 1]) /
                  2;
            } else {
              median = confidences[confidences.length ~/ 2];
            }

            int q1Index = confidences.length ~/ 4;
            int q3Index = confidences.length * 3 ~/ 4;
            double q1 = confidences[q1Index];
            double q3 = confidences[q3Index];
            double iqr = q3 - q1;

            double lowerBound = q1 - 1.5 * iqr;
            double upperBound = q3 + 1.5 * iqr;

            double filteredTotal = 0.0;
            int filteredCount = 0;
            for (final conf in confidences) {
              if (conf >= lowerBound && conf <= upperBound) {
                filteredTotal += conf;
                filteredCount++;
              }
            }

            if (filteredCount > 0) {
              return filteredTotal / filteredCount;
            } else {
              return median;
            }
          } else {
            return totalConfidence / confCount;
          }
        }
      }
    } catch (e) {
      _logger.warning('Error processing confidence data: $e');
    }
    return null;
  }

  String _validateAndCorrectText(String text) {
    if (text.isEmpty) return text;

    Map<RegExp, String> commonErrors = {
      RegExp(r'(\d)l(\d)'): r'$11$2',
      RegExp(r'(\d)I(\d)'): r'$11$2',
      RegExp(r'l(\d)'): r'1$1',
      RegExp(r'O(\d)'): r'0$1',
      RegExp(r'(\d)O'): r'$10',
      RegExp(r'[^\x00-\x7F]+'): ' ',
    };

    String corrected = text;

    commonErrors.forEach((pattern, replacement) {
      corrected = corrected.replaceAll(pattern, replacement);
    });

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
