@tool
extends EditorPlugin
## Adds the in-app review AAR and Google's review library to Android exports that use the Gradle
## build (the "Google Play" preset); the USB debug preset is left as it was. The game calls it
## through app/review_prompt.gd (the "InappReviewPlugin" singleton). Dino Duel, 2026-10-28.

const PLUGIN_NAME: String = "InappReviewPlugin"
const ANDROID_DEPENDENCIES: Array = ["com.google.android.play:review:2.0.2"]

var android_export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	android_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(android_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(android_export_plugin)
	android_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not _gradle_build():
			return PackedStringArray()
		return PackedStringArray(["inapp_review/bin/%s/InappReviewPlugin-%s.aar" % ["debug" if debug else "release",
				"debug" if debug else "release"]])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(ANDROID_DEPENDENCIES) if _gradle_build() else PackedStringArray()

	func _get_name() -> String:
		return PLUGIN_NAME

	func _gradle_build() -> bool:
		var preset := get_export_preset()
		return preset != null and bool(preset.get_or_env("gradle_build/use_gradle_build", ""))
