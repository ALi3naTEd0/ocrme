import 'package:flutter/material.dart';
import 'package:logging/logging.dart';
import 'language_util.dart';
import 'language_manager.dart';
import 'ocr_processor.dart';

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

  // GlobalKey for ScaffoldMessenger to safely show snackbars after async operations
  final _scaffoldMessengerKey = GlobalKey<ScaffoldMessengerState>();

  @override
  void initState() {
    super.initState();
    _loadLanguagesAndStorage();
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

    // Show download progress dialog
    double progress = 0;
    bool downloadComplete = false;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Reinstalling Language'),
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

    try {
      final success = await widget.languageManager.installBundledLanguage(
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

      if (success && mounted) {
        _scaffoldMessengerKey.currentState?.showSnackBar(
          const SnackBar(content: Text('Language reinstalled successfully')),
        );
        _loadLanguagesAndStorage();
      }
    } catch (e) {
      _logger.severe('Error reinstalling language: $e');
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    }
  }

  Future<bool> _showConfirmationDialog(String title, String message) async {
    if (!mounted) return false;

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

  @override
  Widget build(BuildContext context) {
    return ScaffoldMessenger(
      key: _scaffoldMessengerKey,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Settings'),
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
            : SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
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
                            icon:
                                const Icon(Icons.download, color: Colors.blue),
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
    );
  }

  String _formatDate(DateTime date) {
    return '${date.day}/${date.month}/${date.year}';
  }
}
