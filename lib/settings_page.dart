import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'package:ocrme/ocr_strategy_manager.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'language_util.dart';
import 'language_manager.dart';
import 'ocr_processor.dart';
import 'utils/platform_extensions.dart'; // Add this import

class SettingsPage extends StatefulWidget {
  final LanguageManager languageManager;
  final OcrProcessor ocrProcessor;

  const SettingsPage({
    Key? key,
    required this.languageManager,
    required this.ocrProcessor,
  }) : super(key: key);

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  final _logger = Logger('SettingsPage');
  List<Map<String, dynamic>> _languages = [];
  String _storageUsed = "0 B";
  bool _isLoading = true;
  bool _autoSaveEnabled = true;
  String _savePath = '';

  // GlobalKey for ScaffoldMessenger to safely show snackbars after async operations
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadSettings();
    _loadLanguagesAndStorage();
  }

  Future<void> _loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _autoSaveEnabled = prefs.getBool('autoSaveEnabled') ?? true;
      _savePath = prefs.getString('savePath') ?? '';
    });
  }

  Future<void> _loadLanguagesAndStorage() async {
    setState(() => _isLoading = true);

    try {
      // First, synchronize the database with the current bundled languages
      await widget.ocrProcessor.syncLanguages();

      // Then get the languages list and storage usage
      final languages = await widget.languageManager.getAvailableLanguages();
      final storageUsed = await widget.languageManager.getStorageUsage();

      if (mounted) {
        setState(() {
          // Filter out any obsolete bundled languages
          _languages = languages.where((lang) {
            final code = lang['code'] as String;
            final isBundled = lang['is_bundled'] == 1;

            // If it's bundled but not in current bundled list, hide it
            if (isBundled && !OcrProcessor.bundledLanguages.contains(code)) {
              return false;
            }
            return true;
          }).toList();

          _storageUsed = storageUsed;
          _isLoading = false;
        });
      }
    } catch (e) {
      _logger.severe('Error loading language data: $e');
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _deleteLanguage(String languageCode) async {
    final isBundled = OcrProcessor.bundledLanguages.contains(languageCode);
    String message =
        "Are you sure you want to delete this language? You will need to download it again if you need it later.";

    // Special warning for bundled languages
    if (isBundled) {
      message =
          "This is a pre-installed language. If you delete it, you'll need to download it again when needed. Continue?";
    }

    final confirmed = await _showConfirmationDialog(
      "Delete Language",
      message,
    );

    if (confirmed && mounted) {
      final success = await widget.languageManager.deleteLanguage(languageCode);
      if (success && mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Language deleted successfully')),
        );
        _loadLanguagesAndStorage();
      }
    }
  }

  Future<void> _reinstallBundledLanguage(String languageCode) async {
    if (!OcrProcessor.bundledLanguages.contains(languageCode)) {
      return;
    }

    // Track progress variables locally
    double progress = 0;
    bool downloadComplete = false;

    // Declare the entry variable first before using it
    late final OverlayEntry entry;

    // Create a stateful builder that will be updated as progress changes
    entry = OverlayEntry(
      builder: (context) => Material(
        color: Colors.black54,
        child: Center(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 20),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(8),
            ),
            child: StatefulBuilder(
              builder: (context, setState) {
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      'Reinstalling Language',
                      style:
                          TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 16),
                    LinearProgressIndicator(value: progress),
                    const SizedBox(height: 16),
                    Text('${(progress * 100).toStringAsFixed(1)}%'),
                    const SizedBox(height: 16),
                    if (downloadComplete)
                      ElevatedButton(
                        onPressed: () {
                          entry.remove();
                        },
                        child: const Text('Done'),
                      ),
                  ],
                );
              },
            ),
          ),
        ),
      ),
    );

    // Insert the overlay entry
    Overlay.of(context).insert(entry);

    try {
      final success = await widget.languageManager.installBundledLanguage(
        languageCode,
        onProgress: (p) {
          // Use setState callback to update progress
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

      // Remove the overlay entry when done
      if (mounted) {
        entry.remove();
      }

      // Only proceed if still mounted
      if (!mounted) return;

      if (success) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Language reinstalled successfully')),
        );
        _loadLanguagesAndStorage();
      }
    } catch (e) {
      _logger.severe('Error reinstalling language: $e');
      // Ensure overlay is removed on error
      if (mounted) {
        entry.remove();
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    return await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: Text(title),
            content: Text(message),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(false),
                child: const Text('Cancel'),
              ),
              TextButton(
                onPressed: () => Navigator.of(context).pop(true),
                child: const Text('Confirm'),
              ),
            ],
          ),
        ) ??
        false;
  }

  Future<void> _cleanupDatabase() async {
    final confirmed = await _showConfirmationDialog("Clean Up Storage",
        "This will remove any unused language files and clean the database. Continue?");

    if (confirmed && mounted) {
      setState(() => _isLoading = true);

      try {
        final result = await widget.languageManager.cleanupStorage();

        if (result['success'] && mounted) {
          setState(() {
            _storageUsed = result['currentSize'];
            _isLoading = false;
          });

          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text(
                  'Cleanup complete: ${result['filesRemoved']} files removed, ${result['spaceFreed']} freed'),
              duration: const Duration(seconds: 4),
            ),
          );

          // Reload languages list to reflect changes
          _loadLanguagesAndStorage();
        }
      } catch (e) {
        _logger.severe('Error during cleanup: $e');
        if (mounted) {
          setState(() => _isLoading = false);
          _scaffoldMessengerKey.currentState?.showSnackBar(
            SnackBar(
              content: Text('Error during cleanup: ${e.toString()}'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    }
  }

  Future<void> _selectSaveDirectory() async {
    try {
      // Get available directories - skip getExternalStorageDirectory on Linux
      final List<Directory> directories = [];

      try {
        directories.add(await getApplicationDocumentsDirectory());
      } catch (e) {
        _logger.warning('Could not get application documents directory: $e');
      }

      // Only try to get external storage on Android
      if (!Platform.isLinux && !Platform.isMacOS && !Platform.isWindows) {
        try {
          final extDir = await getExternalStorageDirectory();
          if (extDir != null) {
            directories.add(extDir);
          }
        } catch (e) {
          _logger.warning('Could not get external storage directory: $e');
        }
      }

      try {
        directories.add(await getTemporaryDirectory());
      } catch (e) {
        _logger.warning('Could not get temporary directory: $e');
      }

      // On Linux, also add the Home directory
      if (Platform.isLinux) {
        final home = Directory(Platform.environment['HOME'] ??
            '/home/${Platform.environment['USER']}');
        if (await home.exists()) {
          directories.add(home);

          // Also add some common Linux directories
          final downloads = Directory('${home.path}/Downloads');
          final documents = Directory('${home.path}/Documents');
          final pictures = Directory('${home.path}/Pictures');

          if (await downloads.exists()) directories.add(downloads);
          if (await documents.exists()) directories.add(documents);
          if (await pictures.exists()) directories.add(pictures);
        }
      }

      // Remove unnecessary null check here
      final validDirs = directories;

      if (validDirs.isEmpty || !mounted) {
        _logger.warning('No valid directories available');
        return;
      }

      // Show a simple dialog with directory options
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Select Save Location'),
          content: SizedBox(
            width: double.maxFinite,
            height: 250,
            child: ListView.builder(
              itemCount: validDirs.length,
              itemBuilder: (context, index) {
                // Remove unnecessary non-null assertion here
                final dir = validDirs[index];
                String displayName;

                if (dir.path.contains('Documents')) {
                  displayName = 'Documents';
                } else if (dir.path.contains('Downloads')) {
                  displayName = 'Downloads';
                } else if (dir.path.contains('Pictures')) {
                  displayName = 'Pictures';
                } else if (dir.path.contains('temp') ||
                    dir.path.contains('cache')) {
                  displayName = 'Temporary';
                } else if (dir.path.contains('/home')) {
                  displayName = 'Home';
                } else {
                  displayName = 'Directory ${index + 1}';
                }

                return ListTile(
                  title: Text(displayName),
                  subtitle: Text(dir.path),
                  onTap: () async {
                    Navigator.of(context).pop();

                    // Save the selected path
                    final prefs = await SharedPreferences.getInstance();
                    await prefs.setString('savePath', dir.path);

                    if (mounted) {
                      setState(() {
                        _savePath = dir.path;
                      });

                      _scaffoldMessengerKey.currentState?.showSnackBar(
                        SnackBar(
                          content: Text('Save location set to: $displayName'),
                          duration: const Duration(seconds: 2),
                        ),
                      );
                    }
                  },
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
          ],
        ),
      );
    } catch (e) {
      _logger.severe('Error selecting save directory: $e');

      // Show error message to user
      if (mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          SnackBar(
            content: Text('Error selecting directory: $e'),
            backgroundColor: Colors.red,
            duration: const Duration(seconds: 3),
          ),
        );
      }
    }
  }

  Future<void> _toggleAutoSave(bool value) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('autoSaveEnabled', value);
    if (mounted) {
      setState(() {
        _autoSaveEnabled = value;
      });
    }
  }

  Widget _buildPlatformInfoCard() {
    return Card(
      margin: const EdgeInsets.all(16),
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Platform Information',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: Icon(
                kIsWeb
                    ? Icons.web
                    : Platform.isAndroid
                        ? Icons.android
                        : Platform.isIOS
                            ? Icons.ios_share
                            : Platform.isLinux
                                ? Icons.computer
                                : Platform.isWindows
                                    ? Icons.window
                                    : Platform.isMacOS
                                        ? Icons.desktop_mac
                                        : Icons.devices,
                color: Theme.of(context).colorScheme.primary,
              ),
              title: Text(
                kIsWeb
                    ? 'Web'
                    : Platform.isAndroid
                        ? 'Android'
                        : Platform.isIOS
                            ? 'iOS'
                            : Platform.isLinux
                                ? 'Linux'
                                : Platform.isWindows
                                    ? 'Windows'
                                    : Platform.isMacOS
                                        ? 'macOS'
                                        : 'Unknown',
              ),
            ),
            FutureBuilder<Map<String, dynamic>>(
              future: OcrStrategyManager.getBestStrategy(),
              builder: (builderContext, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(
                    child: CircularProgressIndicator(),
                  );
                }

                final data = snapshot.data!;
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      title: const Text('OCR Engine'),
                      subtitle: Text(data['engine'].toString()),
                    ),
                    ListTile(
                      title: const Text('Multiple Languages Support'),
                      subtitle: Text(
                          data['supportsMultipleLanguages'] ? 'Yes' : 'No'),
                    ),
                    if (PlatformExtensions.isDesktop &&
                        data['engine'] == 'tesseract_command')
                      ElevatedButton(
                        onPressed: () => _handleShowLanguagesPressed(),
                        child: const Text('Show Available Languages'),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  // Handle button press without using BuildContext in an async gap
  void _handleShowLanguagesPressed() {
    // First show the loading dialog synchronously with the current context
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => const AlertDialog(
        title: Text('Loading Languages'),
        content: SizedBox(
          height: 100,
          child: Center(child: CircularProgressIndicator()),
        ),
      ),
    );

    // Then start the async operation
    _fetchAndShowLanguages();
  }

  // Separate method to handle async operations
  Future<void> _fetchAndShowLanguages() async {
    try {
      final strategy = await OcrStrategyManager.getBestStrategy();
      final languages = strategy['availableLanguages'] as List<dynamic>;

      // Check if still mounted before proceeding
      if (!mounted) return;

      // Close the loading dialog
      Navigator.of(context).pop();

      // Show the languages dialog - this will use a fresh BuildContext from Navigator
      showDialog(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Available Tesseract Languages'),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: languages.length,
              itemBuilder: (listContext, index) {
                return ListTile(
                  title: Text(languages[index].toString()),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Close'),
            ),
          ],
        ),
      );
    } catch (error) {
      // Check if still mounted before showing error message
      if (!mounted) return;

      // Close the loading dialog if it's still showing
      Navigator.of(context).pop();

      // Show error message
      _logger.severe('Error fetching languages: $error');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error loading languages: $error')),
      );
    }
  }

  String _getOcrEngineName() {
    // Show appropriate engines based on platform
    if (PlatformExtensions.isDesktop) {
      switch (widget.ocrProcessor.preferredEngine) {
        case OcrEngine.tesseract:
          return 'Tesseract';
        case OcrEngine.mlKit:
          return 'ML Kit';
        case OcrEngine.auto:
          return 'Auto (Best Results)';
      }
    } else {
      // For mobile platforms
      switch (widget.ocrProcessor.preferredEngine) {
        case OcrEngine.tesseract:
          return 'Tesseract Only';
        case OcrEngine.mlKit:
          return 'ML Kit';
        case OcrEngine.auto:
          return 'Auto (Best Results)';
      }
    }
  }

  void _setOcrEngine(String engineName) {
    // Initialize with the current value first
    OcrEngine engine = widget.ocrProcessor.preferredEngine;

    if (PlatformExtensions.isDesktop) {
      switch (engineName) {
        case 'Tesseract':
          engine = OcrEngine.tesseract;
          break;
        case 'ML Kit':
          engine = OcrEngine.mlKit;
          break;
        case 'Auto (Best Results)':
          engine = OcrEngine.auto;
          break;
      }
    } else {
      switch (engineName) {
        case 'Tesseract Only':
          engine = OcrEngine.tesseract;
          break;
        case 'ML Kit':
          engine = OcrEngine.mlKit;
          break;
        case 'Auto (Best Results)':
          engine = OcrEngine.auto;
          break;
      }
    }

    setState(() {
      widget.ocrProcessor.preferredEngine = engine;
    });

    // Show language options dialog if ML Kit is selected
    if (engineName == 'ML Kit') {
      _showMlKitLanguagesDialog();
    }
  }

  void _showMlKitLanguagesDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('ML Kit Language Support'),
        content: SizedBox(
          width: double.maxFinite,
          height: 300,
          child: Column(
            children: [
              Text(
                PlatformExtensions.isDesktop
                    ? 'ML Kit on desktop has limited support and may not work properly with all images.'
                    : 'ML Kit automatically detects language for the following scripts:',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: PlatformExtensions.isDesktop
                      ? Colors.orange
                      : Colors.black,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Expanded(
                child: ListView(
                  children: [
                    _buildMlKitScriptTile(
                      'Latin',
                      'English, Spanish, French, etc.',
                      isSupported: true,
                    ),
                    _buildMlKitScriptTile(
                      'Chinese',
                      'Simplified & Traditional',
                      isSupported: !PlatformExtensions.isDesktop,
                    ),
                    _buildMlKitScriptTile(
                      'Japanese',
                      null,
                      isSupported: !PlatformExtensions.isDesktop,
                    ),
                    _buildMlKitScriptTile(
                      'Korean',
                      null,
                      isSupported: !PlatformExtensions.isDesktop,
                    ),
                    _buildMlKitScriptTile(
                      'Devanagari',
                      'Hindi, Sanskrit, etc.',
                      isSupported: !PlatformExtensions.isDesktop,
                    ),
                    _buildMlKitScriptTile(
                      'Cyrillic',
                      'Russian, Ukrainian, etc.',
                      isSupported: !PlatformExtensions.isDesktop,
                    ),
                    _buildMlKitScriptTile(
                      'Arabic',
                      null,
                      isSupported: !PlatformExtensions.isDesktop,
                    ),
                    if (PlatformExtensions.isDesktop)
                      const Padding(
                        padding: EdgeInsets.all(8.0),
                        child: Text(
                          'Note: For best results on desktop, we recommend using Tesseract or Auto mode.',
                          style: TextStyle(fontStyle: FontStyle.italic),
                          textAlign: TextAlign.center,
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  Widget _buildMlKitScriptTile(String scriptName, String? examples,
      {bool isSupported = true}) {
    return ListTile(
      leading: Icon(
        isSupported ? Icons.check_circle : Icons.cancel,
        color: isSupported ? Colors.green : Colors.red,
      ),
      title: Text(
        scriptName,
        style: TextStyle(
          color: isSupported ? Colors.black : Colors.grey,
        ),
      ),
      subtitle: examples != null ? Text(examples) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: Theme.of(context),
      home: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
          leading: IconButton(
            icon: const Icon(Icons.arrow_back),
            onPressed: () => Navigator.of(context).pop(),
          ),
          flexibleSpace: Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.secondary,
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
          ),
          foregroundColor: Colors.white,
        ),
        body: _isLoading
            ? const Center(child: CircularProgressIndicator())
            : Builder(
                builder: (context) => SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // OCR Settings Card
                      Card(
                        margin: const EdgeInsets.all(16),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'OCR Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // OCR Engine selection
                              ListTile(
                                title: const Text('OCR Engine'),
                                subtitle: const Text(
                                    'Select which OCR engine to use'),
                                trailing: DropdownButton<String>(
                                  value: _getOcrEngineName(),
                                  onChanged: (String? newValue) {
                                    if (newValue != null) {
                                      _setOcrEngine(newValue);
                                    }
                                  },
                                  items: PlatformExtensions.isDesktop
                                      ? <String>[
                                          'Tesseract',
                                          'ML Kit',
                                          'Auto (Best Results)',
                                        ].map<DropdownMenuItem<String>>(
                                          (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList()
                                      : <String>[
                                          'Auto (Best Results)',
                                          'ML Kit',
                                          'Tesseract Only',
                                        ].map<DropdownMenuItem<String>>(
                                          (String value) {
                                          return DropdownMenuItem<String>(
                                            value: value,
                                            child: Text(value),
                                          );
                                        }).toList(),
                                ),
                              ),

                              // Text validation toggle
                              SwitchListTile(
                                title: const Text('Text Validation'),
                                subtitle: const Text(
                                    'Automatically correct common OCR errors'),
                                value: widget.ocrProcessor.enableTextValidation,
                                onChanged: (value) {
                                  setState(() {
                                    widget.ocrProcessor.enableTextValidation =
                                        value;
                                  });
                                },
                              ),

                              // Multiple engines toggle
                              SwitchListTile(
                                title: const Text('Use Multiple Engines'),
                                subtitle: const Text(
                                    'Try different OCR engines for best results'),
                                value:
                                    widget.ocrProcessor.enableMultipleEngines,
                                onChanged: (value) {
                                  setState(() {
                                    widget.ocrProcessor.enableMultipleEngines =
                                        value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),
                      ),

                      // File Settings Card
                      Card(
                        margin: const EdgeInsets.all(16),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'File Settings',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Auto-save toggle
                              SwitchListTile(
                                title: const Text('Auto-save OCR results'),
                                subtitle: const Text(
                                    'Automatically save results after processing'),
                                value: _autoSaveEnabled,
                                onChanged: _toggleAutoSave,
                              ),

                              // Save path selection
                              ListTile(
                                title: const Text('Save Location'),
                                subtitle: Text(_savePath.isEmpty
                                    ? 'Default location (Pictures folder)'
                                    : _savePath),
                                trailing: IconButton(
                                  icon: const Icon(Icons.folder_open),
                                  onPressed: _selectSaveDirectory,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Add Platform Info Card
                      _buildPlatformInfoCard(),

                      // Storage information card
                      Card(
                        margin: const EdgeInsets.all(16),
                        elevation: 2,
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Storage',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  const Icon(Icons.storage),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Language data size: $_storageUsed',
                                    style: const TextStyle(fontSize: 16),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 16),
                              // Add cleanup button
                              SizedBox(
                                width: double.infinity,
                                child: ElevatedButton.icon(
                                  onPressed: _cleanupDatabase,
                                  icon: const Icon(Icons.cleaning_services),
                                  label: const Text('Clean Up Storage'),
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor:
                                        Theme.of(context).colorScheme.secondary,
                                    foregroundColor: Colors.white,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Languages section
                      const Padding(
                        padding:
                            EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                        child: Text(
                          'Installed Languages',
                          style: TextStyle(
                            fontSize: 20,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),

                      // Language list
                      ListView.builder(
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        itemCount: _languages.length,
                        itemBuilder: (context, index) {
                          final language = _languages[index];
                          final code = language['code'] as String;
                          final name = language['name'] as String;
                          final size = language['size'] as int;
                          final isBundled = language['is_bundled'] == 1;
                          final isInstalled = language['is_installed'] != 0;
                          final date = DateTime.fromMillisecondsSinceEpoch(
                            language['downloaded_date'] as int,
                          );

                          // Skip languages that are not currently bundled but were previously marked as bundled
                          // and are not installed anymore
                          if (!OcrProcessor.bundledLanguages.contains(code) &&
                              isBundled &&
                              !isInstalled) {
                            return const SizedBox
                                .shrink(); // Don't show this entry
                          }

                          // Format size in KB or MB
                          String formattedSize;
                          if (size < 1024) {
                            formattedSize = '$size B';
                          } else if (size < 1024 * 1024) {
                            formattedSize =
                                '${(size / 1024).toStringAsFixed(1)} KB';
                          } else {
                            formattedSize =
                                '${(size / (1024 * 1024)).toStringAsFixed(1)} MB';
                          }

                          String flag = LanguageUtil.getFlagEmoji(code);

                          String statusText;
                          if (OcrProcessor.bundledLanguages.contains(code)) {
                            statusText = isInstalled
                                ? "Pre-installed"
                                : "Not installed (bundled)";
                          } else {
                            statusText = "Downloaded ${_formatDate(date)}";
                          }

                          // Show different widgets based on language status
                          Widget trailing;
                          if (isInstalled) {
                            trailing = IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.red),
                              onPressed: () => _deleteLanguage(code),
                              tooltip: 'Delete language data',
                            );
                          } else {
                            trailing = IconButton(
                              icon: const Icon(Icons.download,
                                  color: Colors.blue),
                              onPressed: () => _reinstallBundledLanguage(code),
                              tooltip: 'Reinstall language',
                            );
                          }

                          return ListTile(
                            leading: Text(
                              flag,
                              style: const TextStyle(fontSize: 24),
                            ),
                            title: Text('$name ($code)'),
                            subtitle: Text('$formattedSize • $statusText'),
                            trailing: trailing,
                          );
                        },
                      ),
                    ],
                  ),
                ),
              ),
      ),
      scaffoldMessengerKey: _scaffoldMessengerKey,
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
