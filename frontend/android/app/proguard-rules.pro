-keepattributes SourceFile,LineNumberTable
-renamesourcefileattribute SourceFile

# Flutter engine and plugin entry points.
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-keep class io.flutter.plugins.** { *; }

# Keep Android TV launcher/activity classes reachable by manifest.
-keep class com.movieapp.tv.MainActivity { *; }

# Keep models used reflectively by platform plugins if any plugin adds reflection.
-keep class com.google.android.gms.** { *; }
-dontwarn com.google.android.gms.**
