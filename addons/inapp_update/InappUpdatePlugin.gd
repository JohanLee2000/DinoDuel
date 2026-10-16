@tool
extends EditorPlugin
## Adds the in-app update AAR and Google's Play library to Android exports that use the Gradle
## build (the "Google Play" preset). The USB debug preset doesn't use Gradle, so it's left as it
## was. From InappUpdate by icecube092 (MIT, see LICENSE); Dino Duel experiment, 2026-10-16.

const PLUGIN_NAME: String = "InappUpdatePlugin"

# Google Play dependencies pulled into the app's gradle build on export.
const ANDROID_DEPENDENCIES: Array = [
	"com.google.android.play:app-update:2.1.0",
	"com.google.android.play:app-update-ktx:2.1.0",
]

var android_export_plugin: AndroidExportPlugin


func _enter_tree() -> void:
	android_export_plugin = AndroidExportPlugin.new()
	add_export_plugin(android_export_plugin)


func _exit_tree() -> void:
	remove_export_plugin(android_export_plugin)
	android_export_plugin = null


class AndroidExportPlugin extends EditorExportPlugin:
	var _plugin_name = PLUGIN_NAME

	func _supports_platform(platform: EditorExportPlatform) -> bool:
		return platform is EditorExportPlatformAndroid

	func _get_android_libraries(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		if not _gradle_build():
			return PackedStringArray()
		if debug:
			return PackedStringArray(["inapp_update/bin/debug/InappUpdatePlugin-debug.aar"])
		else:
			return PackedStringArray(["inapp_update/bin/release/InappUpdatePlugin-release.aar"])

	func _get_android_dependencies(platform: EditorExportPlatform, debug: bool) -> PackedStringArray:
		return PackedStringArray(ANDROID_DEPENDENCIES) if _gradle_build() else PackedStringArray()

	func _get_name() -> String:
		return _plugin_name

	func _gradle_build() -> bool:
		var preset := get_export_preset()
		return preset != null and bool(preset.get_or_env("gradle_build/use_gradle_build", ""))
