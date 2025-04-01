import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'language_util.dart';
import 'ocr_processor.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final Function() onSettingsPressed;
  final String selectedLanguage;
  final Function(String) onLanguageChanged;

  const CustomAppBar({
    Key? key,
    required this.onSettingsPressed,
    required this.selectedLanguage,
    required this.onLanguageChanged,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Use a more direct approach instead of the logo helper
    final bool isNarrowScreen = MediaQuery.of(context).size.width < 600;
    const String logoPath = 'assets/logo.svg';

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            Theme.of(context).colorScheme.primary,
            Theme.of(context).colorScheme.secondary,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
          child: Row(
            children: [
              // Logo with increased size
              Container(
                height: isNarrowScreen ? kToolbarHeight : kToolbarHeight + 8,
                width: isNarrowScreen
                    ? 120
                    : 160, // Increased width for larger logo
                padding: const EdgeInsets.all(2),
                child: SvgPicture.asset(
                  logoPath,
                  fit: BoxFit.contain,
                ),
              ),

              const Spacer(),

              // Simplified language selector
              _buildSimpleLanguageSelector(context),

              const SizedBox(width: 8),

              // Settings button
              IconButton(
                icon: const Icon(Icons.settings, color: Colors.white),
                onPressed: onSettingsPressed,
                tooltip: 'Settings',
                constraints: const BoxConstraints(
                  minWidth: 40,
                  minHeight: 40,
                ),
                padding: EdgeInsets.zero,
                visualDensity: VisualDensity.compact,
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSimpleLanguageSelector(BuildContext context) {
    String currentFlag = LanguageUtil.getFlagEmoji(selectedLanguage);

    return PopupMenuButton<String>(
      tooltip: 'Select language',
      onSelected: onLanguageChanged,
      itemBuilder: (BuildContext context) {
        final List<PopupMenuEntry<String>> menuItems = [];

        // Add header for pre-installed languages
        menuItems.add(const PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text(
            'Pre-installed Languages',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ));

        // Add core languages first
        for (final langCode in OcrProcessor.bundledLanguages) {
          final langName = LanguageNames.getNameForCode(langCode);
          final flag = LanguageUtil.getFlagEmoji(langCode);
          menuItems.add(_buildLanguageMenuItem(langCode, langName, flag));
        }

        // Add divider
        menuItems.add(const PopupMenuDivider());

        // Add header for downloadable languages
        menuItems.add(const PopupMenuItem<String>(
          enabled: false,
          height: 30,
          child: Text(
            'Download More Languages',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ));

        // Only show common downloadable languages
        for (final entry in LanguageNames.shortLanguageNames.entries) {
          if (!OcrProcessor.bundledLanguages.contains(entry.value)) {
            menuItems.add(_buildLanguageMenuItem(
              entry.value,
              entry.key,
              LanguageUtil.getFlagEmoji(entry.value),
              needsDownload: true,
            ));
          }
        }

        // All Languages option - keep this option and ensure it works
        menuItems.add(const PopupMenuDivider());
        menuItems.add(const PopupMenuItem<String>(
          value:
              'all_languages', // This value will trigger showing all languages dialog
          child: Row(
            children: [
              Icon(Icons.language,
                  color: Colors.blue), // Change to language icon for clarity
              SizedBox(width: 10),
              Text('View All Languages...'),
            ],
          ),
        ));

        return menuItems;
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: Colors.white.withAlpha(50),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              currentFlag,
              style: const TextStyle(fontSize: 18),
            ),
            const SizedBox(width: 4),
            const Icon(Icons.arrow_drop_down, color: Colors.white, size: 18),
          ],
        ),
      ),
    );
  }

  PopupMenuItem<String> _buildLanguageMenuItem(
      String code, String name, String flag,
      {bool needsDownload = false, bool isNotInstalled = false}) {
    return PopupMenuItem<String>(
      value: code,
      child: Row(
        children: [
          Text(flag, style: const TextStyle(fontSize: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(name)),
          if (needsDownload)
            const Icon(Icons.download, size: 16, color: Colors.grey)
          else if (isNotInstalled)
            const Icon(Icons.refresh, size: 16, color: Colors.orange),
        ],
      ),
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight + 8);
}
