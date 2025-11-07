# ProGuard Rules for Premium Bank Super App
# These rules are applied during the Android release build process
# to obfuscate and optimize the code.

# ============================================================================
# Flutter Configuration
# ============================================================================

# Keep Flutter framework classes
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }

# ============================================================================
# Annotations
# ============================================================================

# Keep annotations for reflection
-keepattributes *Annotation*
-keepattributes Signature
-keepattributes InnerClasses
-keepattributes EnclosingMethod

# Keep source file and line numbers for debugging stack traces
-keepattributes SourceFile,LineNumberTable

# Rename source file attribute to hide internal structure
-renamesourcefileattribute SourceFile

# ============================================================================
# Reflection
# ============================================================================

# Keep classes used via reflection
-keepclassmembers class * {
    @retrofit2.http.* <methods>;
}

# Keep enums
-keepclassmembers enum * {
    public static **[] values();
    public static ** valueOf(java.lang.String);
}

# ============================================================================
# Serialization
# ============================================================================

# Keep Gson classes
-keep class com.google.gson.** { *; }
-keep class com.google.gson.stream.** { *; }

# Keep model classes for JSON serialization
-keep class com.premiumbank.**.models.** { *; }
-keep class com.premiumbank.**.entities.** { *; }

# Prevent obfuscation of classes with @SerializedName
-keepclassmembers,allowobfuscation class * {
  @com.google.gson.annotations.SerializedName <fields>;
}

# ============================================================================
# Networking
# ============================================================================

# Dio HTTP client
-keep class io.flutter.plugins.** { *; }

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Retrofit
-keep class retrofit2.** { *; }
-keepclasseswithmembers class * {
    @retrofit2.* <methods>;
}

# ============================================================================
# Security
# ============================================================================

# Keep cryptography classes
-keep class javax.crypto.** { *; }
-keep class java.security.** { *; }

# Keep secure storage
-keep class io.flutter.plugins.flutter_secure_storage.** { *; }

# ============================================================================
# Native Methods
# ============================================================================

# Keep native methods
-keepclasseswithmembernames class * {
    native <methods>;
}

# ============================================================================
# Parcelable
# ============================================================================

# Keep Parcelable implementations
-keep class * implements android.os.Parcelable {
    public static final android.os.Parcelable$Creator *;
}

# ============================================================================
# R8 Specific
# ============================================================================

# R8 full mode configuration
-allowaccessmodification
-repackageclasses

# ============================================================================
# Remove Logging
# ============================================================================

# Remove all logging in release builds
-assumenosideeffects class android.util.Log {
    public static boolean isLoggable(java.lang.String, int);
    public static int v(...);
    public static int d(...);
    public static int i(...);
    public static int w(...);
    public static int e(...);
}

# Remove print statements
-assumenosideeffects class java.io.PrintStream {
    public void println(%);
    public void println(**);
}

# ============================================================================
# Firebase (if using)
# ============================================================================

# Uncomment if using Firebase
# -keep class com.google.firebase.** { *; }
# -keep class com.google.android.gms.** { *; }

# ============================================================================
# Custom Application Classes
# ============================================================================

# Keep Application class
-keep class com.premiumbank.super_app.MainActivity { *; }
-keep class com.premiumbank.super_app.MainApplication { *; }

# ============================================================================
# Optimization Settings
# ============================================================================

# Number of optimization passes
-optimizationpasses 5

# Don't preverify (improves build time)
-dontpreverify

# Optimize for Android
-optimizations !code/simplification/arithmetic,!field/*,!class/merging/*,!code/allocation/variable

# ============================================================================
# Warnings
# ============================================================================

# Suppress warnings for missing classes
-dontwarn javax.annotation.**
-dontwarn org.conscrypt.**
-dontwarn org.bouncycastle.**
-dontwarn org.openjsse.**

# ============================================================================
# End of ProGuard Rules
# ============================================================================
