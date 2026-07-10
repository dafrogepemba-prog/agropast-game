# ============================================================
# ProGuard / R8 — AgroPast-Game
# ============================================================

# ── Flutter ──────────────────────────────────────────────────
-keep class io.flutter.** { *; }
-keep class io.flutter.plugins.** { *; }
-dontwarn io.flutter.**

# ── Google Mobile Ads (AdMob) ─────────────────────────────────
-keep class com.google.android.gms.ads.** { *; }
-keep class com.google.ads.** { *; }
-dontwarn com.google.android.gms.**

# ── audioplayers ─────────────────────────────────────────────
-keep class xyz.luan.audioplayers.** { *; }
-dontwarn xyz.luan.audioplayers.**

# ── shared_preferences ───────────────────────────────────────
-keep class io.flutter.plugins.sharedpreferences.** { *; }

# ── JSON / Dart → empêcher R8 de supprimer les champs ────────
# Les classes Flutter passant par dart2java ou JNI
-keepclassmembers class * {
    @com.google.gson.annotations.SerializedName <fields>;
}

# ── Kotlin coroutines / réflexion ─────────────────────────────
-dontwarn kotlin.**
-keep class kotlin.** { *; }
-keep class kotlinx.** { *; }

# ── Classes générées par Flutter ──────────────────────────────
-keep class **.GeneratedPluginRegistrant { *; }

# ── Sécurité : ne pas exposer les traces de stack en prod ─────
-renamesourcefileattribute SourceFile
-keepattributes SourceFile,LineNumberTable
