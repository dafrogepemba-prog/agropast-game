# ============================================================
# ProGuard / R8 — AgroPast-Game
# ============================================================

# ── Flutter core ─────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.app.** { *; }
-keep class io.flutter.plugin.** { *; }
-keep class io.flutter.util.** { *; }
-keep class io.flutter.view.** { *; }
-keep class io.flutter.embedding.** { *; }
-dontwarn io.flutter.**

# ── Flutter plugins générés ──────────────────────────────────
-keep class **.GeneratedPluginRegistrant { *; }
-keep class io.flutter.plugins.** { *; }

# ── Google Mobile Ads (AdMob) ─────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.android.gms.common.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.**
-dontwarn com.google.ads.**

# ── audioplayers ─────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ── shared_preferences ───────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }
-keep class androidx.datastore.** { *; }

# ── flutter_svg ──────────────────────────────────────────────
-dontwarn com.caverock.**
-keep class com.caverock.** { *; }

# ── Kotlin ───────────────────────────────────────────────────
-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keep class kotlin.Metadata { *; }
-keep class kotlinx.** { *; }
-dontwarn kotlinx.coroutines.**

# ── JSON / sérialisation ─────────────────────────────────────
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}
-keepattributes Signature
-keepattributes *Annotation*
-keepattributes EnclosingMethod

# ── Prévenir crash sur réflexion ─────────────────────────────
-keepclassmembers class * implements java.io.Serializable {
    static final long serialVersionUID;
    private static final java.io.ObjectStreamField[] serialPersistentFields;
    private void writeObject(java.io.ObjectOutputStream);
    private void readObject(java.io.ObjectInputStream);
    java.lang.Object writeReplace();
    java.lang.Object readResolve();
}

# ── Garder les traces de stack lisibles en debug ─────────────
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable

# ── Supprimer les logs verbeux en production ─────────────────
-assumenosideeffects class android.util.Log {
    public static int v(...);
    public static int d(...);
}
