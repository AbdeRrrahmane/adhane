# === flutter_local_notifications ===
-keep class com.dexterous.flutterlocalnotifications.** { *; }

# === GSON (مستخدم داخليًا في بعض المكتبات) ===
-keep class com.google.gson.** { *; }
-keepattributes Signature
-keepattributes *Annotation*
-keep class * extends com.google.gson.TypeAdapter
-keep class * implements com.google.gson.TypeAdapterFactory
-keep class * implements com.google.gson.JsonSerializer
-keep class * implements com.google.gson.JsonDeserializer

# === audioplayers ===
-keep class xyz.luan.audioplayers.** { *; }

# === dio (يعتمد على OkHttp) ===
-dontwarn okhttp3.**
-keep class okhttp3.** { *; }

# === geolocator ===
-keep class com.baseflow.geolocator.** { *; }

# === flutter_background_service ===
-keep class dev.fluttercommunity.plus.backgroundservice.** { *; }

# === workmanager ===
-keep class be.tramckrijte.workmanager.** { *; }

# === shared_preferences ===
-keep class androidx.preference.** { *; }

# === حماية عامة للـ reflection ===
-keep class sun.misc.Unsafe { *; }
-keepclassmembers class ** {
    public <init>(...);
}
-keepnames class * {
    public <methods>;
}
