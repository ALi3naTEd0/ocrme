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

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# Keep all native libraries
-keepattributes *Annotation*
-dontwarn org.bytedeco.**
-dontwarn org.tensorflow.**
-dontwarn com.google.mlkit.**
