# Keep Flutter / plugin / FFI entry points for R8.
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-keep class org.opentorrent.open_torrent.** { *; }
-keepclassmembers class * {
    @android.webkit.JavascriptInterface <methods>;
}
-dontwarn javax.annotation.**
-dontwarn org.bouncycastle.**
# Flutter deferred components reference Play Core (not shipped for sideload APKs).
-dontwarn com.google.android.play.core.**
-dontwarn com.google.android.play.core.splitcompat.**
-dontwarn com.google.android.play.core.splitinstall.**
-dontwarn com.google.android.play.core.tasks.**
