package mods.summary_chest_rules;

import haxe.Timer;
import openfl.display.Sprite;
import openfl.filters.GlowFilter;
import openfl.text.TextField;
import openfl.text.TextFormat;

/** A small, non-interactive line at the bottom of the screen: what the mod did or why it waits. */
class Notice {
	static inline final SHOW_SECONDS = 4.5;

	static inline final WIDTH = 440.0;

	static inline final HEIGHT = 34.0;

	var box:Sprite;

	var label:TextField;

	var hideAt:Float = 0;

	var width:Float = 0;

	var height:Float = 0;

	public function new(overlay:Sprite, viewWidth:Float, viewHeight:Float) {
		box = new Sprite();
		box.mouseEnabled = false;
		box.mouseChildren = false;
		box.visible = false;

		var background = new Sprite();
		var g = background.graphics;
		g.beginFill(0x120A04, 0.84);
		g.drawRoundRect(0, 0, WIDTH, HEIGHT, 8, 8);
		g.endFill();
		g.lineStyle(1, 0xF2C14E, 0.8);
		g.drawRoundRect(0.5, 0.5, WIDTH - 1, HEIGHT - 1, 8, 8);
		box.addChild(background);

		label = new TextField();
		label.x = 10;
		label.y = 7;
		label.width = WIDTH - 20;
		label.height = 20;
		label.selectable = false;
		label.mouseEnabled = false;
		label.multiline = false;
		label.wordWrap = false;
		label.defaultTextFormat = new TextFormat("_sans", 14, 0xFFF1D0, true);
		label.filters = [new GlowFilter(0x000000, 1, 4, 4, 4)];
		box.addChild(label);

		overlay.addChild(box);
		resize(viewWidth, viewHeight);
	}

	public function show(text:String):Void {
		label.text = text;
		box.visible = true;
		hideAt = Timer.stamp() + SHOW_SECONDS;
	}

	public function hide():Void {
		box.visible = false;
		hideAt = 0;
	}

	public function tick():Void {
		if (box.visible && hideAt > 0 && Timer.stamp() > hideAt)
			hide();
	}

	public function resize(viewWidth:Float, viewHeight:Float):Void {
		width = viewWidth;
		height = viewHeight;
		box.x = 16;
		box.y = viewHeight > HEIGHT + 32 ? viewHeight - HEIGHT - 18 : 16;
		if (viewWidth > 0 && viewWidth < WIDTH + 32)
			box.scaleX = box.scaleY = (viewWidth - 32) / WIDTH;
		else
			box.scaleX = box.scaleY = 1;
	}

	public function dispose():Void {
		if (box != null && box.parent != null)
			box.parent.removeChild(box);
		box = null;
		label = null;
	}
}