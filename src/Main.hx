package mods.summary_chest_rules;

import facade.DBFacade;
import haxe.Timer;
import mods.api.Context;
import mods.api.Mod;
import mods.api.settings.Flag;
import mods.api.settings.Slider;
import openfl.display.DisplayObjectContainer;
import openfl.events.Event;

/**
 * At the victory summary, keeps or discards the four reward chests according to their rarity.
 *
 * It uses the same server calls as the KEEP and DROP buttons; it only does the clicking. The summary
 * is read through `Reflect`, so a game update that renames one of its fields disables the mod instead
 * of breaking the whole mod batch.
 *
 * Configure it from Settings -> MODS.
 */
@:privateAccess
class Main extends Mod {
	/** How long a KEEP may wait for the account answer before that chest is left to the player. */
	static inline final KEEP_TIMEOUT_DEFAULT = 10.0;

	/** How long the report must stay clean before a paused run resumes. */
	static inline final RECOVER_DELAY = 0.5;

	var ctx:Context;

	var facade:DBFacade;

	/** The live summary, read through Reflect. */
	var summary:Dynamic;

	/** A field or method this game build does not have: the mod stays out of the way. */
	var disabled:Bool = false;

	var paused:Bool = false;

	var pauseReason:String = "";

	var recoverAt:Float = -1;

	var cooldown:Float = 0;

	var waitingSince:Float = -1;

	var waitingSlot:Int = -1;

	/** Slots left to the player after a rejected keep or a timeout. */
	var leaveSlots:Array<Int> = [];

	/** Rejected keeps allowed before the whole summary is paused. */
	var skips:Int = 0;

	var kept:Int = 0;

	var dropped:Int = 0;

	var noticed:Bool = false;

	/** The native treasure prompt was restored after a full storage; do it once. */
	var nativeRestored:Bool = false;

	var notice:Notice;

	// API settings (Settings → MODS → Summary Chest Rules)
	var flagKeepRare:Flag;
	var flagKeepLegendary:Flag;
	var flagKeepItemBox:Flag;
	var flagKeepUncommon:Flag;
	var flagKeepCommon:Flag;
	var sliderTimeout:Slider;

	override public function init(context:Context):Void {
		ctx = context;
		try {
			Log.start(ctx.data);
		} catch (error:Dynamic) {}

		flagKeepRare = ctx.settings.flag("keepRare", "Keep RARE", "Rare chests are kept; otherwise discarded.", true);
		flagKeepLegendary = ctx.settings.flag("keepLegendary", "Keep LEGENDARY", "Legendary chests are kept; otherwise discarded.", true);
		flagKeepItemBox = ctx.settings.flag("keepItemBox", "Keep item boxes", "Small and royal item boxes are kept.", true);
		flagKeepUncommon = ctx.settings.flag("keepUncommon", "Keep UNCOMMON", "Uncommon chests are kept; otherwise discarded.", true);
		flagKeepCommon = ctx.settings.flag("keepCommon", "Keep COMMON", "Common chests are kept; otherwise discarded.", true);
		sliderTimeout = ctx.settings.slider("keepTimeout", "Keep timeout", "Seconds to wait for the server to confirm KEEP.", 5, 30, 1,
			KEEP_TIMEOUT_DEFAULT, 0);

		flagKeepRare.onChange(function(_) resume());
		flagKeepLegendary.onChange(function(_) resume());
		flagKeepItemBox.onChange(function(_) resume());
		flagKeepUncommon.onChange(function(_) resume());
		flagKeepCommon.onChange(function(_) resume());
		sliderTimeout.onChange(function(_) resume());

		ctx.core.onObjectReady(function(object) {
			if (className(object) == "distributedObjects.DistributedDungeonSummary") {
				summary = object;
				resetSummary();
				checkSummary();
				Log.write("summary ready");
			}
		});
		ctx.core.onObjectGone(function(object) {
			if (object == summary) {
				summary = null;
				paused = false;
				pauseReason = "";
				waitingSince = -1;
				waitingSlot = -1;
				if (notice != null)
					notice.hide();
			}
		});
		ctx.overlay.addEventListener(Event.ENTER_FRAME, tick);
		Log.write("init");
	}

	override public function ready(context:Context):Void {
		facade = context.core.facade;
		notice = new Notice(ctx.overlay, ctx.viewWidth, ctx.viewHeight);
	}

	override public function dispose():Void {
		if (ctx != null && ctx.overlay != null)
			ctx.overlay.removeEventListener(Event.ENTER_FRAME, tick);
		if (notice != null) {
			notice.dispose();
			notice = null;
		}
		Log.flush();
		summary = null;
		facade = null;
	}

	function resetSummary():Void {
		paused = false;
		pauseReason = "";
		recoverAt = -1;
		cooldown = 0;
		waitingSince = -1;
		waitingSlot = -1;
		leaveSlots = [];
		skips = 0;
		kept = 0;
		dropped = 0;
		noticed = false;
		nativeRestored = false;
	}

	/** Refuses to work with a summary whose fields or actions this build does not have. */
	function checkSummary():Void {
		var missing:Array<String> = [];
		for (name in ["mRevealState", "mItemCount", "mLeaving", "mChestMovieClips"]) {
			if (Reflect.hasField(summary, name) == false && field(name) == null)
				missing.push(name);
		}
		for (name in ["closeKeyChestPopup", "keepChestFromInventory", "removeItemFromSlot"]) {
			if (!Reflect.isFunction(field(name)))
				missing.push(name);
		}
		if (missing.length > 0) {
			disabled = true;
			Log.write("incompatible summary, missing: " + missing.join(", "));
			showNotice("Summary Chest Rules: incompatible game version");
		}
	}

	static function className(object:Dynamic):String {
		if (object == null)
			return "";
		try {
			return Type.getClassName(Type.getClass(object));
		} catch (error:Dynamic) {
			return "";
		}
	}

	function field(name:String):Dynamic {
		return summary == null ? null : Reflect.field(summary, name);
	}

	function has(name:String):Bool {
		return field(name) != null;
	}

	function number(name:String):Int {
		var value = field(name);
		return value == null ? 0 : Std.int(value);
	}

	function call(name:String, args:Array<Dynamic>):Dynamic {
		var method = field(name);
		if (!Reflect.isFunction(method))
			throw "summary." + name + " is missing";
		return Reflect.callMethod(summary, method, args);
	}

	function tick(_:Event):Void {
		if (notice != null) {
			notice.tick();
			if (notice.width <= 0 && ctx.viewWidth > 0)
				notice.resize(ctx.viewWidth, ctx.viewHeight);
		}
		if (summary == null || disabled || !ctx.core.alive || facade == null)
			return;
		try {
			step(Timer.stamp());
		} catch (error:Dynamic) {
			disabled = true;
			Log.write("disabled after error: " + Std.string(error));
			showNotice("Summary Chest Rules: incompatible game version");
		}
	}

	function step(now:Float):Void {
		if (paused) {
			recover(now);
			if (paused)
				return;
		}
		if (field("mLeaving") == true)
			return;
		if (number("mRevealState") != 12 || field("mTownHeader") == null)
			return;

		// The game itself opens the first chest's native prompt: handle it, don't wait for it to close.
		if (has("mTreasureFoundPopup"))
			closeTreasurePrompt();

		if (has("mChestTransactionFailedPopup")) {
			// The popup stays for 1.5 s after the game handles the failure. Mark our slot once,
			// then wait for it to go away instead of pausing on every frame.
			if (waitingSlot >= 0)
				transactionFailed(now);
			return;
		}
		if (has("mStorageFullPopUp")) {
			pause("storage_full");
			return;
		}

		if (waitingSince >= 0) {
			if (chestAt(waitingSlot) == 0 && !has("mInfoPopup")) {
				kept++;
				waitingSince = -1;
				waitingSlot = -1;
			} else if (now - waitingSince > sliderTimeout.value) {
				if (waitingSlot >= 0 && leaveSlots.indexOf(waitingSlot) < 0)
					leaveSlots.push(waitingSlot);
				waitingSince = -1;
				waitingSlot = -1;
				cooldown = now + 0.8;
				Log.write("keep timeout: slot left to the player");
				return;
			} else {
				return;
			}
		}

		if (dialogsOpen())
			return;
		if (now < cooldown)
			return;
		if (number("mItemCount") <= 0) {
			showFinalNotice();
			return;
		}
		if (!artReady())
			return;

		var empty = true;
		var slot = -1;
		var i = 0;
		while (i < 4) {
			if (chestAt(i) != 0) {
				empty = false;
				if (slot < 0 && leaveSlots.indexOf(i) < 0)
					slot = i;
			}
			i++;
		}
		if (slot < 0) {
			if (empty || allLeft())
				showFinalNotice();
			else
				pause("missing_chest");
			return;
		}

		var dooberId = chestAt(slot);
		var doober:Dynamic = facade.gameMaster.dooberById.itemFor(dooberId);
		if (doober == null) {
			pause("missing_data");
			return;
		}
		var chestId = Std.int(Reflect.field(doober, "ChestId"));
		var chest:Dynamic = facade.gameMaster.chestsById.itemFor(chestId);
		if (chest == null) {
			pause("missing_data");
			return;
		}
		var gmId = Std.int(Reflect.field(chest, "Id"));
		var rarity = Std.string(Reflect.field(chest, "Rarity"));
		if (keepFor(rarity))
			keepChest(slot, chest, gmId, rarity, now);
		else
			dropChest(slot, chest, rarity, now);
	}

	function closeTreasurePrompt():Void {
		try {
			call("closeKeyChestPopup", []);
			Log.write("closed treasure prompt");
		} catch (error:Dynamic) {
			Log.write("could not close treasure prompt: " + Std.string(error));
			pause("popup_failed");
		}
	}

	/** A rejected keep: leave that slot to the player and try the rest once. */
	function transactionFailed(now:Float):Void {
		var slot = waitingSlot;
		waitingSince = -1;
		waitingSlot = -1;
		if (slot >= 0 && skips < 1) {
			skips++;
			if (leaveSlots.indexOf(slot) < 0)
				leaveSlots.push(slot);
			cooldown = now + 1.6;
			Log.write("transaction rejected: slot " + slot + " left to the player");
			return;
		}
		pause("transaction_failed");
	}

	/** A previous failure must not hold the run forever: resume once the native summary is clean. */
	function recover(now:Float):Void {
		if (!cleanReport()) {
			recoverAt = -1;
			return;
		}
		if (recoverAt < 0) {
			recoverAt = now;
			return;
		}
		if (now - recoverAt < RECOVER_DELAY)
			return;
		paused = false;
		pauseReason = "";
		recoverAt = -1;
		cooldown = now + 0.4;
		nativeRestored = false;
		Log.write("summary is clean: resumed");
	}

	function cleanReport():Bool {
		if (summary == null || field("mLeaving") == true)
			return false;
		if (number("mRevealState") != 12 || field("mTownHeader") == null)
			return false;
		if (number("mItemCount") != 0)
			return false;
		var i = 0;
		while (i < 4) {
			if (chestAt(i) != 0)
				return false;
			i++;
		}
		return !dialogsOpen();
	}

	function dialogsOpen():Bool {
		for (name in ["mBoosterPopup", "mInfoPopup", "mTreasureFoundPopup", "mChestRevealPopUp", "mChestBuyKeysPopUp",
			"mStorageFullPopUp", "mChestTransactionFailedPopup", "mAbandonChestPopUp", "mUIInventory", "mDRFriendBlockPopup",
			"mDRReportPlayerPopup"]) {
			if (has(name))
				return true;
		}
		return false;
	}

	/** Every expected chest has its art loaded, so removing one cannot leave a half-built reveal. */
	function artReady():Bool {
		var clips = field("mChestMovieClips");
		if (clips == null)
			return false;
		var local = clips[0];
		if (local == null)
			return true;
		var expected = 0;
		var i = 0;
		while (i < 4) {
			if (chestAt(i) != 0)
				expected++;
			i++;
		}
		if (expected == 0)
			return true;
		var loaded = 0;
		i = 0;
		while (i < 4) {
			var holder:DisplayObjectContainer = cast local[i];
			if (holder != null && holder.numChildren > 0)
				loaded++;
			i++;
		}
		return loaded >= expected;
	}

	function chestAt(slot:Int):Int {
		if (slot < 0 || slot > 3)
			return 0;
		var report = field("mDungeonReport");
		var row:Dynamic = report == null ? null : report[0];
		if (row == null)
			return 0;
		var value:Dynamic = Reflect.field(row, "chest_type_" + Std.string(slot + 1));
		return value == null ? 0 : Std.int(value);
	}

	function allLeft():Bool {
		var i = 0;
		while (i < 4) {
			if (chestAt(i) != 0 && leaveSlots.indexOf(i) < 0)
				return false;
			i++;
		}
		return true;
	}

	function keepFor(rarity:String):Bool {
		if (rarity == "COMMON")
			return flagKeepCommon.value;
		if (rarity == "UNCOMMON")
			return flagKeepUncommon.value;
		if (rarity == "RARE")
			return flagKeepRare.value;
		if (rarity == "LEGENDARY")
			return flagKeepLegendary.value;
		if (rarity == "CONSUMABLE_SMALL" || rarity == "CONSUMABLE_ROYAL")
			return flagKeepItemBox.value;
		// The summary only carries chests; keep anything unexpected rather than lose it.
		return true;
	}

	function keepChest(slot:Int, chest:Dynamic, gmId:Int, rarity:String, now:Float):Void {
		try {
			var storage = facade.dbAccountInfo.inventoryInfo;
			var fullInventory = ctx.isActive("full_inventory");
			if (!fullInventory && !storage.hasRoomForChest(gmId)) {
				if (!nativeRestored) {
					nativeRestored = true;
					try {
						call("loadNextChestPopUp", []);
					} catch (error:Dynamic) {
						Log.write("could not restore the native prompt: " + Std.string(error));
					}
				}
				pause("storage_full");
				return;
			}
			Reflect.setField(summary, "mSelectedGMChest", chest);
			call("keepChestFromInventory", [slot, true]);
			waitingSince = now;
			waitingSlot = slot;
			cooldown = now + 0.3;
			Log.write("keep slot=" + slot + " rarity=" + rarity + " chest=" + gmId + " fullInventory=" + fullInventory);
		} catch (error:Dynamic) {
			Log.write("keep failed: " + Std.string(error));
			pause("keep_failed");
		}
	}

	function dropChest(slot:Int, chest:Dynamic, rarity:String, now:Float):Void {
		try {
			Reflect.setField(summary, "mTookLastItem", false);
			var network = field("mNetworkComponent");
			var send = network == null ? null : Reflect.field(network, "send_DropChest");
			if (!Reflect.isFunction(send))
				throw "summary.mNetworkComponent.send_DropChest is missing";
			Reflect.callMethod(network, send, [facade.dbAccountInfo.id, slot]);
			call("removeItemFromSlot", [slot]);
			dropped++;
			cooldown = now + 0.35;
			Log.write("drop slot=" + slot + " rarity=" + rarity + " chest=" + Std.int(Reflect.field(chest, "Id")));
		} catch (error:Dynamic) {
			Log.write("drop failed: " + Std.string(error));
			pause("drop_failed");
		}
	}

	/** How many chests of the current summary each rule handled. */
	function showFinalNotice():Void {
		if (noticed)
			return;
		noticed = true;
		reconcileLeft();
		if (kept + dropped == 0 && leaveSlots.length == 0)
			return;
		var text = "Chest rules: " + kept + " kept, " + dropped + " dropped";
		if (leaveSlots.length > 0)
			text += ", " + leaveSlots.length + " for you";
		showNotice(text);
	}

	/** A slot left to the player after a timeout may have resolved on its own: stop counting it. */
	function reconcileLeft():Void {
		var i = leaveSlots.length - 1;
		while (i >= 0) {
			if (chestAt(leaveSlots[i]) == 0)
				leaveSlots.splice(i, 1);
			i--;
		}
	}

	function pause(reason:String):Void {
		if (paused && pauseReason == reason)
			return;
		paused = true;
		pauseReason = reason;
		recoverAt = -1;
		Log.write("pause: " + reason);
		var text = "Chest rules paused";
		if (reason == "storage_full")
			text += ": storage full";
		else if (reason == "transaction_failed" || reason == "keep_failed" || reason == "drop_failed")
			text += ": the server rejected a chest";
		else if (reason == "missing_data" || reason == "missing_chest")
			text += ": reward data is incomplete";
		else if (reason == "popup_failed")
			text += ": the chest prompt could not be closed";
		showNotice(text);
	}

	/** A settings change is a good moment to retry after a pause. */
	function resume():Void {
		paused = false;
		pauseReason = "";
		recoverAt = -1;
		cooldown = 0;
		waitingSince = -1;
		waitingSlot = -1;
		nativeRestored = false;
	}

	function showNotice(text:String):Void {
		if (notice == null)
			return;
		notice.show(text);
	}
}