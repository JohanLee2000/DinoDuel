# Godot calls the plugin's @UsedByGodot methods by name, so R8/ProGuard in the app must keep them.
-keep class com.dinoduelstudios.inappreview.** { *; }
