package mods.summary_chest_rules;

import sys.io.File;

/** What the mod decided, kept in its data folder. Buffered: only actions and state changes are logged. */
class Log {
	static inline final LIMIT = 10000;

	static inline final WRITES_PER_FLUSH = 10;

	static var path:String = null;

	static var buffer:String = "";

	static var writes:Int = 0;

	public static function start(folder:String):Void {
		path = folder + "/last.log";
		buffer = "";
		writes = 0;
		write("start");
		flush();
	}

	public static function write(message:String):Void {
		buffer += message + "\n";
		if (buffer.length > LIMIT)
			buffer = buffer.substr(buffer.length - Std.int(LIMIT / 2));
		writes++;
		if (writes >= WRITES_PER_FLUSH)
			flush();
	}

	public static function flush():Void {
		writes = 0;
		if (path == null)
			return;
		try {
			File.saveContent(path, buffer);
		} catch (error:Dynamic) {}
	}
}