class_name Share
extends RefCounted
## Opens the phone's share sheet with a file (a pull image, an exported save) and a line of
## text. On Android this calls the
## platform directly from GDScript (Godot's AndroidRuntime + JavaClassWrapper): androidx's
## FileProvider turns the saved PNG into a content:// link (Godot's library already declares one
## for the whole files folder), and ShareCompat builds the share intent. No plugin needed.
## On a PC it just opens the image (or shows the file in Explorer), enough for checking it.

const AUTHORITY_SUFFIX := ".fileprovider"


## `path` is a user:// PNG. Returns false if sharing isn't possible here.
static func image(path: String, text: String) -> bool:
	return file(path, "image/png", text, "Share your dino")


## Any file under user:// (Godot's FileProvider covers the whole files folder).
static func file(path: String, mime_type: String, text: String, chooser_title: String) -> bool:
	var os_path := ProjectSettings.globalize_path(path)
	if OS.get_name() != "Android":
		if mime_type.begins_with("image/"):
			OS.shell_open(os_path)
		else:
			OS.shell_show_in_file_manager(os_path)
		return true
	if not Engine.has_singleton("AndroidRuntime"):
		push_warning("Share: AndroidRuntime isn't available")
		return false
	var runtime: Object = Engine.get_singleton("AndroidRuntime")
	var activity: Object = runtime.getActivity()
	var open_sheet := func() -> void:
		var uri: Object = _content_uri(activity, os_path)
		if uri == null:
			push_warning("Share: couldn't make a content link for %s" % os_path)
			return
		var builder_class: Object = JavaClassWrapper.wrap("androidx.core.app.ShareCompat$IntentBuilder")
		var builder: Object = builder_class.from(activity)
		builder.setType(mime_type)
		builder.setStream(uri)
		builder.setText(text)
		builder.setChooserTitle(chooser_title)
		builder.startChooser()
	activity.runOnUiThread(runtime.createRunnableFromGodotCallable(open_sheet))
	return true


static func _content_uri(activity: Object, os_path: String) -> Object:
	var file_class: Object = JavaClassWrapper.wrap("java.io.File")
	var file: Object = file_class.File(os_path)
	if file == null:
		return null
	var provider: Object = JavaClassWrapper.wrap("androidx.core.content.FileProvider")
	var authority: String = str(activity.getPackageName()) + AUTHORITY_SUFFIX
	return provider.getUriForFile(activity, authority, file)
