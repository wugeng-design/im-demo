# Flutter Wrapper
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.**  { *; }
-keep class io.flutter.util.**  { *; }
-keep class io.flutter.view.**  { *; }
-keep class io.flutter.**  { *; }
-keep class io.flutter.plugins.**  { *; }

# Kotlin Coroutines
-keepnames class kotlinx.coroutines.internal.MainDispatcherFactory {}
-keepnames class kotlinx.coroutines.CoroutineExceptionHandler {}
-keepclassmembers class kotlinx.coroutines.** {
    volatile <fields>;
}

# Sqlite3
-keep class org.sqlite.** { *; }
-keep class org.sqlite.database.** { *; }

# Image Compress
-keep class com.flutter_image_compress.** { *; }

# Video Player
-keep class com.google.android.exoplayer2.** { *; }
-dontwarn com.google.android.exoplayer2.**

# OkHttp
-dontwarn okhttp3.**
-dontwarn okio.**
-keep class okhttp3.** { *; }
-keep interface okhttp3.** { *; }

# Retrofit
-dontwarn retrofit2.**
-keep class retrofit2.** { *; }
-keepattributes Signature
-keepattributes Exceptions

# Gson
-keepattributes Signature
-keepattributes *Annotation*
-keep class com.google.gson.** { *; }
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# Connectivity Plus
-keep class com.linusu.flutter_connectivity.** { *; }

# Path Provider
-keep class io.flutter.plugins.pathprovider.** { *; }

# Image Picker
-keep class io.flutter.plugins.imagepicker.** { *; }

# File Picker
-keep class com.mr.flutter.plugin.filepicker.** { *; }

# Cached Network Image
-keep class com.baseflow.permissionhandler.** { *; }

# Just Audio
-keep class com.ryanheise.just_audio.** { *; }

# Share Plus
-keep class dev.fluttercommunity.plus.share.** { *; }

# Whixp/XMPP
-keep class org.jivesoftware.smack.** { *; }
-keep class org.jxmpp.** { *; }
-dontwarn org.jivesoftware.smack.**
-dontwarn org.jxmpp.**

# Keep native methods
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}

-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Keep custom exceptions
-keep public class * extends java.lang.Exception

# Keep annotations
-keepattributes *Annotation*
-keepattributes RuntimeVisibleAnnotations
-keepattributes RuntimeInvisibleAnnotations
-keepattributes RuntimeVisibleParameterAnnotations
-keepattributes RuntimeInvisibleParameterAnnotations

# Optimization rules
-optimizations !code/simplification/arithmetic,!code/simplification/cast,!field/*,!class/merging/*
-optimizationpasses 5
-allowaccessmodification
-dontpreverify
