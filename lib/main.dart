import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:logging/logging.dart';
import 'package:flutter/services.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'ocr_processor.dart';
import 'unified_drop_zone.dart';
import 'custom_app_bar.dart';
import 'language_util.dart';
import 'settings_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize logging
  Logger.root.level = Level.INFO;
  Logger.root.onRecord.listen((record) {
    // ignore: avoid_print
    print('${record.level.name}: ${record.time}: ${record.message}');
  });

  // Initialize sqflite_ffi for desktop platforms
  if (!kIsWeb && (Platform.isLinux || Platform.isWindows || Platform.isMacOS)) {
    // Initialize FFI
    sqfliteFfiInit();
    // Set the database factory
    databaseFactory = databaseFactoryFfi;
    Logger.root.info('Initialized sqflite_ffi for desktop');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'OCRMe',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6A11CB),
          secondary: const Color(0xFF2575FC),
        ),
        useMaterial3: true,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(8),
            ),
          ),
        ),
      ),
      home: const MyHomePage(),
      debugShowCheckedModeBanner: false,
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({super.key});

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  final _logger = Logger('MyHomePage');
  final OcrProcessor _ocrProcessor = OcrProcessor();
  File? _image;
  String _ocrResult = '';
  String _outputDirectory = '';
  final String _outputFilename = 'output.txt';
  String _selectedLanguage = 'eng';
  bool _isProcessing = false;
  double _confidenceScore = 0.0;

  @override
  void initState() {
    super.initState();
    _initializeOutputDirectory();
  }

  Future<void> _initializeOutputDirectory() async {
    final directory = await getApplicationDocumentsDirectory();
    setState(() {
      _outputDirectory = directory.path;
    });
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(source: ImageSource.gallery);

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _ocrResult = '';
        _confidenceScore = 0.0;
      });

      // Automatically start OCR processing when an image is selected
      await _performOCR();
    }
  }

  Future<void> _takePhoto() async {
    final picker = ImagePicker();
    final pickedFile = await picker.pickImage(
      source: ImageSource.camera,
      preferredCameraDevice: CameraDevice.rear,
    );

    if (pickedFile != null) {
      setState(() {
        _image = File(pickedFile.path);
        _ocrResult = '';
        _confidenceScore = 0.0;
      });

      // Automatically start OCR processing when a photo is taken
      await _performOCR();
    }
  }

  Future<void> _performOCR() async {
    if (_image != null) {
      try {
        setState(() {
          _isProcessing = true;
          _ocrResult = 'Processing...';
          _confidenceScore = 0.0;
        });

        final result = await _ocrProcessor.processImage(
          _image!,
          onLanguageUnavailable: (lang) {
            _showLanguageDownloadDialog(lang);
          },
        );

        setState(() {
          _ocrResult = result.text;
          _confidenceScore = result.confidenceScore;
          _isProcessing = false;
        });

        await _saveResultToFile(result.text);
        _logger.info('OCR completed successfully');
      } catch (e) {
        setState(() {
          _ocrResult = 'Error: $e';
          _isProcessing = false;
        });
        _logger.severe('Error during OCR: $e');
      }
    } else {
      setState(() {
        _ocrResult = 'Please select an image first';
      });
    }
  }

  Future<void> _saveResultToFile(String result) async {
    try {
      final file = File('$_outputDirectory/$_outputFilename');
      await file.writeAsString(result);
      _logger.info('Result saved to: ${file.path}');
    } catch (e) {
      _logger.severe('Error saving result: $e');
    }
  }

  void _openSettingsDialog() {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => SettingsPage(
          languageManager: _ocrProcessor.languageManager,
          ocrProcessor: _ocrProcessor,
        ),
      ),
    );
  }

  Future<void> _handleFileDropped(File file) async {
    setState(() {
      _image = file;
      _ocrResult = '';
      _confidenceScore = 0.0;
    });
    await _performOCR();
  }

  void _copyToClipboard() {
    if (_ocrResult.isNotEmpty &&
        _ocrResult != 'No result yet' &&
        !_ocrResult.startsWith('Error:') &&
        !_ocrResult.startsWith('Processing...')) {
      Clipboard.setData(ClipboardData(text: _ocrResult));
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OCR result copied to clipboard'),
          duration: Duration(seconds: 2),
        ),
      );
      _logger.info('Result copied to clipboard');
    }
  }

  void _handleLanguageSelection(String value) {
    if (value == 'all_languages') {
      _showAllLanguagesDialog();
    } else {
      _checkAndSetLanguage(value);
    }
  }

  Future<void> _checkAndSetLanguage(String languageCode) async {
    final isAvailable = await _ocrProcessor.isLanguageAvailable(languageCode);

    if (isAvailable || OcrProcessor.bundledLanguages.contains(languageCode)) {
      setState(() {
        _selectedLanguage = languageCode;
        _ocrProcessor.setLanguage(languageCode);
      });
    } else {
      _showLanguageDownloadDialog(languageCode);
    }
  }

  void _showLanguageDownloadDialog(String languageCode) {
    String languageName = LanguageUtil.getDisplayName(languageCode);

    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text('Download $languageName Language'),
          content: Text(
              'The $languageName language data is not installed. Would you like to download it now?'),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                Navigator.of(context).pop();
                await _downloadLanguageWithProgress(languageCode);
              },
              child: const Text('Download'),
            ),
          ],
        );
      },
    );
  }

  Future<void> _downloadLanguageWithProgress(String languageCode) async {
    double progress = 0;
    bool downloadComplete = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: const Text('Downloading Language'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 16),
                  Text('${(progress * 100).toStringAsFixed(1)}%'),
                ],
              ),
              actions: [
                if (downloadComplete)
                  TextButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                    },
                    child: const Text('Done'),
                  )
              ],
            );
          },
        );
      },
    );

    final success = await _ocrProcessor.downloadLanguage(
      languageCode,
      onProgress: (p) {
        if (mounted) {
          setState(() {
            progress = p;
            if (p >= 1.0) {
              downloadComplete = true;
            }
          });
        }
      },
    );

    if (mounted && Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    }

    if (success) {
      _logger.info('Language $languageCode downloaded successfully');

      setState(() {
        _selectedLanguage = languageCode;
        _ocrProcessor.setLanguage(languageCode);
      });

      if (_image != null) {
        await _performOCR();
      }
    } else {
      setState(() {
        _ocrResult = 'Failed to download language data. Please try again.';
        _isProcessing = false;
      });
    }
  }

  void _showAllLanguagesDialog() {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          title: const Text('All Available Languages'),
          content: SizedBox(
            width: double.maxFinite,
            height: 400,
            child: ListView.builder(
              itemCount: OcrProcessor.supportedLanguages.length,
              itemBuilder: (context, index) {
                final entry =
                    OcrProcessor.supportedLanguages.entries.elementAt(index);
                final languageName = entry.key;
                final languageCode = entry.value;
                final flag = LanguageUtil.getFlagEmoji(languageCode);
                final isPreinstalled =
                    OcrProcessor.bundledLanguages.contains(languageCode);

                return ListTile(
                  leading: Text(
                    flag,
                    style: const TextStyle(fontSize: 24),
                  ),
                  title: Text(languageName),
                  trailing: isPreinstalled
                      ? const Icon(Icons.check, color: Colors.green)
                      : const Icon(Icons.download, color: Colors.blue),
                  onTap: () async {
                    Navigator.of(context).pop();
                    if (!isPreinstalled) {
                      final isAvailable =
                          await _ocrProcessor.isLanguageAvailable(languageCode);
                      if (!isAvailable) {
                        _showLanguageDownloadDialog(languageCode);
                      } else {
                        setState(() {
                          _selectedLanguage = languageCode;
                          _ocrProcessor.setLanguage(languageCode);
                        });
                      }
                    } else {
                      setState(() {
                        _selectedLanguage = languageCode;
                        _ocrProcessor.setLanguage(languageCode);
                      });
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(
        children: [
          CustomAppBar(
            onSettingsPressed: _openSettingsDialog,
            selectedLanguage: _selectedLanguage,
            onLanguageChanged: _handleLanguageSelection,
          ),
          Expanded(
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    Theme.of(context).colorScheme.surface,
                    Theme.of(context)
                        .colorScheme
                        .surfaceContainerHighest
                        .withAlpha(77),
                  ],
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                ),
              ),
              child: SingleChildScrollView(
                child: Center(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: <Widget>[
                        Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: UnifiedDropZone(
                              height: 300,
                              onFileDropped: _handleFileDropped,
                              child: _image == null
                                  ? const Center(
                                      child: Column(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          Icon(
                                            Icons.upload_file,
                                            size: 64,
                                            color: Colors.grey,
                                          ),
                                          SizedBox(height: 16),
                                          Text(
                                            'Drag and drop an image here\nor click to select',
                                            textAlign: TextAlign.center,
                                            style: TextStyle(
                                              color: Colors.grey,
                                              fontSize: 16,
                                            ),
                                          ),
                                        ],
                                      ),
                                    )
                                  : Stack(
                                      alignment: Alignment.center,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.all(8),
                                          child: Image.file(
                                            _image!,
                                            height: 280,
                                            fit: BoxFit.contain,
                                          ),
                                        ),
                                        if (_isProcessing)
                                          Container(
                                            color: Colors.black.withAlpha(128),
                                            child: const Center(
                                              child:
                                                  CircularProgressIndicator(),
                                            ),
                                          ),
                                      ],
                                    ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            ElevatedButton.icon(
                              onPressed: _pickImage,
                              icon: const Icon(Icons.photo_library),
                              label: const Text('Gallery'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _takePhoto,
                              icon: const Icon(Icons.camera_alt),
                              label: const Text('Camera'),
                              style: ElevatedButton.styleFrom(
                                backgroundColor:
                                    Theme.of(context).colorScheme.secondary,
                                foregroundColor: Colors.white,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 24),
                        Card(
                          elevation: 4,
                          shadowColor: Colors.black26,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  mainAxisAlignment:
                                      MainAxisAlignment.spaceBetween,
                                  children: [
                                    const Text(
                                      'OCR Result:',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        fontSize: 18,
                                      ),
                                    ),
                                    if (_ocrResult.isNotEmpty &&
                                        _ocrResult != 'No result yet' &&
                                        !_ocrResult.startsWith('Error:') &&
                                        !_ocrResult.startsWith('Processing...'))
                                      Row(
                                        children: [
                                          Tooltip(
                                            message: 'Confidence Level',
                                            child: Row(
                                              children: [
                                                Icon(
                                                  _confidenceScore > 85
                                                      ? Icons.check_circle
                                                      : _confidenceScore > 70
                                                          ? Icons.info
                                                          : Icons.warning,
                                                  color: _confidenceScore > 85
                                                      ? Colors.green
                                                      : _confidenceScore > 70
                                                          ? Colors.orange
                                                          : Colors.red,
                                                  size: 18,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  '${_confidenceScore.toStringAsFixed(1)}%',
                                                  style: TextStyle(
                                                    color: _confidenceScore > 85
                                                        ? Colors.green
                                                        : _confidenceScore > 70
                                                            ? Colors.orange
                                                            : Colors.red,
                                                    fontWeight: FontWeight.bold,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                          const SizedBox(width: 12),
                                          IconButton(
                                            icon: const Icon(Icons.copy),
                                            tooltip: 'Copy to clipboard',
                                            onPressed: _copyToClipboard,
                                            color: Theme.of(context)
                                                .colorScheme
                                                .primary,
                                          ),
                                        ],
                                      ),
                                  ],
                                ),
                                const Divider(),
                                Container(
                                  padding: const EdgeInsets.all(12),
                                  decoration: BoxDecoration(
                                    color: Colors.grey[100],
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(
                                      color: Colors.grey[300]!,
                                    ),
                                  ),
                                  width: double.infinity,
                                  constraints: const BoxConstraints(
                                    minHeight: 100,
                                    maxHeight: 300,
                                  ),
                                  child: SingleChildScrollView(
                                    child: SelectableText(
                                      _ocrResult.isEmpty
                                          ? 'No result yet'
                                          : _ocrResult,
                                      style: TextStyle(
                                        color: _ocrResult.isEmpty
                                            ? Colors.grey
                                            : Colors.black87,
                                        fontSize: 16,
                                        height: 1.5,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
