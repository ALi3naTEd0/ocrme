// DEPRECATED: This file is replaced by the LanguageCatalog in language_util.dart
// Keeping this for backward compatibility, but should be removed in future

// Import the new structure
import 'package:ocrme/language_util.dart';

// Forward declarations to maintain backwards compatibility
class LanguageNames {
  static Map<String, String> get supportedLanguages =>
      LanguageCatalog.supportedLanguages;
  static Map<String, String> get shortLanguageNames =>
      LanguageCatalog.shortLanguageNames;

  static String getShortName(String code) => LanguageCatalog.getShortName(code);
  static String getNameFromCode(String code) =>
      LanguageCatalog.getNameFromCode(code);
  static String getNameForCode(String code) =>
      LanguageCatalog.getNameForCode(code);
}
