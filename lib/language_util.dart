class LanguageUtil {
  // Map language codes to country flags (ISO 3166-1 alpha-2 country codes)
  // We're using country emoji flags which are composed of two regional indicator symbols
  static Map<String, String> languageToFlag = {
    'afr': '🇿🇦', // Afrikaans - South Africa
    'amh': '🇪🇹', // Amharic - Ethiopia
    'ara': '🇸🇦', // Arabic - Saudi Arabia
    'asm': '🇮🇳', // Assamese - India
    'aze': '🇦🇿', // Azerbaijani - Azerbaijan
    'bel': '🇧🇾', // Belarusian - Belarus
    'ben': '🇧🇩', // Bengali - Bangladesh
    'bod': '🇨🇳', // Tibetan - China
    'bos': '🇧🇦', // Bosnian - Bosnia and Herzegovina
    'bre': '🇫🇷', // Breton - France
    'bul': '🇧🇬', // Bulgarian - Bulgaria
    'cat': '🇪🇸', // Catalan - Spain
    'ceb': '🇵🇭', // Cebuano - Philippines
    'ces': '🇨🇿', // Czech - Czech Republic
    'chi_sim': '🇨🇳', // Chinese Simplified - China
    'chi_tra': '🇹🇼', // Chinese Traditional - Taiwan
    'chr': '🇺🇸', // Cherokee - USA
    'cym': '🇬🇧', // Welsh - UK
    'dan': '🇩🇰', // Danish - Denmark
    'deu': '🇩🇪', // German - Germany
    'dzo': '🇧🇹', // Dzongkha - Bhutan
    'ell': '🇬🇷', // Greek - Greece
    'eng': '🇺🇸', // English - USA
    'enm': '🇬🇧', // Middle English - UK
    'epo': '🌍', // Esperanto - World
    'est': '🇪🇪', // Estonian - Estonia
    'eus': '🇪🇸', // Basque - Spain
    'fao': '🇫🇴', // Faroese - Faroe Islands
    'fas': '🇮🇷', // Persian - Iran
    'fil': '🇵🇭', // Filipino - Philippines
    'fin': '🇫🇮', // Finnish - Finland
    'fra': '🇫🇷', // French - France
    'frm': '🇫🇷', // Middle French - France
    'fry': '🇳🇱', // Western Frisian - Netherlands
    'gla': '🇬🇧', // Scottish Gaelic - Scotland
    'gle': '🇮🇪', // Irish - Ireland
    'glg': '🇪🇸', // Galician - Spain
    'grc': '🇬🇷', // Ancient Greek - Greece
    'guj': '🇮🇳', // Gujarati - India
    'hat': '🇭🇹', // Haitian - Haiti
    'heb': '🇮🇱', // Hebrew - Israel
    'hin': '🇮🇳', // Hindi - India
    'hrv': '🇭🇷', // Croatian - Croatia
    'hun': '🇭🇺', // Hungarian - Hungary
    'hye': '🇦🇲', // Armenian - Armenia
    'iku': '🇨🇦', // Inuktitut - Canada
    'ind': '🇮🇩', // Indonesian - Indonesia
    'isl': '🇮🇸', // Icelandic - Iceland
    'ita': '🇮🇹', // Italian - Italy
    'jav': '🇮🇩', // Javanese - Indonesia
    'jpn': '🇯🇵', // Japanese - Japan
    'kan': '🇮🇳', // Kannada - India
    'kat': '🇬🇪', // Georgian - Georgia
    'kaz': '🇰🇿', // Kazakh - Kazakhstan
    'khm': '🇰🇭', // Khmer - Cambodia
    'kir': '🇰🇬', // Kyrgyz - Kyrgyzstan
    'kor': '🇰🇷', // Korean - South Korea
    'lao': '🇱🇦', // Lao - Laos
    'lat': '🇻🇦', // Latin - Vatican
    'lav': '🇱🇻', // Latvian - Latvia
    'lit': '🇱🇹', // Lithuanian - Lithuania
    'ltz': '🇱🇺', // Luxembourgish - Luxembourg
    'mal': '🇮🇳', // Malayalam - India
    'mar': '🇮🇳', // Marathi - India
    'mkd': '🇲🇰', // Macedonian - North Macedonia
    'mlt': '🇲🇹', // Maltese - Malta
    'mon': '🇲🇳', // Mongolian - Mongolia
    'mri': '🇳🇿', // Maori - New Zealand
    'msa': '🇲🇾', // Malay - Malaysia
    'mya': '🇲🇲', // Burmese - Myanmar
    'nep': '🇳🇵', // Nepali - Nepal
    'nld': '🇳🇱', // Dutch - Netherlands
    'nor': '🇳🇴', // Norwegian - Norway
    'ori': '🇮🇳', // Oriya - India
    'pan': '🇮🇳', // Punjabi - India
    'pol': '🇵🇱', // Polish - Poland
    'por': '🇵🇹', // Portuguese - Portugal
    'pus': '🇦🇫', // Pashto - Afghanistan
    'ron': '🇷🇴', // Romanian - Romania
    'rus': '🇷🇺', // Russian - Russia
    'san': '🇮🇳', // Sanskrit - India
    'sin': '🇱🇰', // Sinhala - Sri Lanka
    'slk': '🇸🇰', // Slovak - Slovakia
    'slv': '🇸🇮', // Slovenian - Slovenia
    'spa': '🇪🇸', // Spanish - Spain
    'sqi': '🇦🇱', // Albanian - Albania
    'srp': '🇷🇸', // Serbian - Serbia
    'swa': '🇹🇿', // Swahili - Tanzania
    'swe': '🇸🇪', // Swedish - Sweden
    'syr': '🇸🇾', // Syriac - Syria
    'tam': '🇮🇳', // Tamil - India
    'tel': '🇮🇳', // Telugu - India
    'tgk': '🇹🇯', // Tajik - Tajikistan
    'tgl': '🇵🇭', // Tagalog - Philippines
    'tha': '🇹🇭', // Thai - Thailand
    'tir': '🇪🇷', // Tigrinya - Eritrea
    'tur': '🇹🇷', // Turkish - Turkey
    'uig': '🇨🇳', // Uyghur - China
    'ukr': '🇺🇦', // Ukrainian - Ukraine
    'urd': '🇵🇰', // Urdu - Pakistan
    'uzb': '🇺🇿', // Uzbek - Uzbekistan
    'vie': '🇻🇳', // Vietnamese - Vietnam
    'yid': '🇮🇱', // Yiddish - Israel
    'yor': '🇳🇬', // Yoruba - Nigeria

    // Add missing language-to-flag mappings
    'all_languages': '🌐', // Globe for "all languages" option

    // Add fallbacks for languages that might be missing flags
    'equ': '🔢', // Math/equation - using numbers symbol
    'osd': '📝', // Orientation Script Detection - using memo symbol
  };

  // Get flag emoji for a language code
  static String getFlagEmoji(String languageCode) {
    return languageToFlag[languageCode] ??
        '🌐'; // Use globe instead of white flag
  }

  // Get the display name from language code
  static String getDisplayName(String languageCode) {
    // Reverse lookup in the supportedLanguages map
    for (var entry in LanguageNames.supportedLanguages.entries) {
      if (entry.value == languageCode) {
        return entry.key;
      }
    }
    return languageCode; // Fallback to the code itself
  }
}

// Separate class to store just the language names
class LanguageNames {
  // Full set of common languages
  static const Map<String, String> supportedLanguages = {
    'English': 'eng',
    'French': 'fra',
    'Spanish': 'spa',
    'German': 'deu',
    'Italian': 'ita',
    'Portuguese': 'por',
    'Russian': 'rus',
    'Japanese': 'jpn',
    'Korean': 'kor',
    'Chinese (Simplified)': 'chi_sim',
    'Chinese (Traditional)': 'chi_tra',
    'Arabic': 'ara',
    'Hindi': 'hin',
    'Bengali': 'ben',
    'Dutch': 'nld',
    'Greek': 'ell',
    'Turkish': 'tur',
    'Vietnamese': 'vie',
    'Polish': 'pol',
    'Ukrainian': 'ukr',
    'Hebrew': 'heb',
    'Swedish': 'swe',
    'Czech': 'ces',
    'Romanian': 'ron',
    'Hungarian': 'hun',
  };

  // Shorter list of languages for dropdown menu
  static const Map<String, String> shortLanguageNames = {
    'English': 'eng',
    'Spanish': 'spa',
    'French': 'fra',
    'German': 'deu',
    'Chinese': 'chi_sim',
    'Russian': 'rus',
    'Japanese': 'jpn',
    'Arabic': 'ara',
    'Portuguese': 'por',
    'Italian': 'ita',
  };

  // Get a shorter display name if available
  static String getShortName(String code) {
    return shortLanguageNames[code] ?? getNameFromCode(code);
  }

  // Get language name from code by looking up the original map
  static String getNameFromCode(String code) {
    for (var entry in supportedLanguages.entries) {
      if (entry.value == code) {
        return entry.key;
      }
    }
    return code;
  }

  // Get a language name from its code
  static String getNameForCode(String code) {
    for (final entry in supportedLanguages.entries) {
      if (entry.value == code) {
        return entry.key;
      }
    }
    return code;
  }
}
