package mods.summary_chest_rules;

import haxe.Json;
import sys.FileSystem;
import sys.io.File;

/** The keep/drop rules, kept in the mod's data folder. */
class Settings {
	static inline final FILE = "settings.json";

	public var enabled:Bool = false;

	public var keepCommon:Bool = false;

	public var keepUncommon:Bool = false;

	public var keepRare:Bool = true;

	public var keepLegendary:Bool = true;

	public var keepItemBox:Bool = true;

	/** "pause" or "drop" when the chest storage is full and a chest should be kept. */
	public var whenFull:String = "pause";

	var path:String;

	var log:String->Void;

	public function new(folder:String, log:String->Void) {
		path = folder + "/" + FILE;
		this.log = log;
		load();
	}

	public function save():Void {
		var data = {
			enabled: enabled,
			keepCommon: keepCommon,
			keepUncommon: keepUncommon,
			keepRare: keepRare,
			keepLegendary: keepLegendary,
			keepItemBox: keepItemBox,
			whenFull: whenFull
		};
		try {
			File.saveContent(path, Json.stringify(data, null, "\t"));
		} catch (error:Dynamic) {
			log("could not save " + FILE + ": " + error);
		}
	}

	function load():Void {
		if (!FileSystem.exists(path))
			return;
		try {
			var content = File.getContent(path);
			if (content.charCodeAt(0) == 0xFEFF)
				content = content.substr(1);
			var data:Dynamic = Json.parse(content);
			if (data.enabled != null)
				enabled = data.enabled == true;
			if (data.keepCommon != null)
				keepCommon = data.keepCommon == true;
			if (data.keepUncommon != null)
				keepUncommon = data.keepUncommon == true;
			if (data.keepRare != null)
				keepRare = data.keepRare == true;
			if (data.keepLegendary != null)
				keepLegendary = data.keepLegendary == true;
			if (data.keepItemBox != null)
				keepItemBox = data.keepItemBox == true;
			if (data.whenFull != null)
				whenFull = Std.string(data.whenFull) == "drop" ? "drop" : "pause";
		} catch (error:Dynamic) {
			log("could not read " + FILE + ", the defaults apply: " + error);
		}
	}
}
