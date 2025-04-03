# Keep OCR-related classes intact
-keep class androidx.camera.** { *; }
-keep class org.bytedeco.** { *; }
-keep class org.tensorflow.lite.** { *; }
-keep class com.google.mlkit.** { *; }

# Preserve Flutter assets
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Keep Tesseract OCR plugin
-keep class io.paratoner.flutter_tesseract_ocr.** { *; }

# Keep ML Kit related classes
-keep class com.google.mlkit.** { *; }
-keep class com.google_mlkit_** { *; }

# Keep Google Play Core libraries
-keep class com.google.android.play.core.** { *; }
-keep class com.google.android.play.core.splitcompat.** { *; }
-keep class com.google.android.play.core.splitinstall.** { *; }
-keep class com.google.android.play.core.tasks.** { *; }

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Prevent R8 from stripping interface information
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# Keep all native libraries
-keepattributes *Annotation*
-dontwarn org.bytedeco.**
-dontwarn org.tensorflow.**
-dontwarn com.google.mlkit.**
-dontwarn org.xmlpull.v1.**
-dontwarn kotlin.**
-dontwarn okio.**

# Ignore warnings for Google Play Core on non-Google Play devices
-dontwarn com.google.android.play.core.**
