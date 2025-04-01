# OCRMe

A cross-platform OCR application built with Flutter.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## Language System

OCRMe uses a smart language management system to keep the app size small while providing support for many languages:

### Pre-installed Languages

The app comes with 2 core languages pre-installed to keep it lightweight:
- English (eng)
- Spanish (spa)

These languages are immediately available without downloading additional files.

### Downloadable Languages

When you select a language that isn't pre-installed, OCRMe will:
1. Prompt you to download the language data file
2. Retrieve the file from the official Tesseract GitHub repository
3. Save it locally for future use

After downloading, the language becomes available for OCR processing just like the pre-installed languages.

## Technical Details

- Language files are stored in the application's support directory
- Downloaded languages are tracked using SQLite for persistent storage
- Languages can be deleted and reinstalled as needed to manage storage space
- The app uses the `tessdata_fast` versions of language files for faster download and processing
