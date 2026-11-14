package mods.summary_chest_rules;

import distributedObjects.DistributedDungeonSummary;
import facade.DBFacade;
import haxe.Json;
import mods.api.Context;
import mods.api.Mod;
import mods.api.settings.Flag;
import mods.api.settings.Slider;
import openfl.events.Event;
import openfl.system.Capabilities;
import sys.FileSystem;
import sys.io.File;

/**
 * At the victory summary, keeps or discards the four reward chests according to their rarity.
 *
 * It uses the same server calls as the KEEP and DROP buttons; it only does the clicking.
 *
 * Configure it from Ajustes → ADVANCED → Summary Chest Rules.
 */
@:privateAccess
class Main extends Mod {
	/** How long a KEEP may wait for the account answer before the summary is left alone. */
	static inline final KEEP_TIMEOUT_DEFAULT = 10000.0;

	var ctx:Context;

	var facade:DBFacade;

	var summary:DistributedDungeonSummary;

	var paused:Bool = false;

	var pauseReason:String = "";

	var cooldown:Float = 0;

	var keepSince:Float = 0;

	var keepCount:Int = 0;

	/** One diagnostic line per second while a summary exists, to see what gate stops the run. */
	var traceAt:Float = 0;

	// API 1.3 settings (shown in Ajustes → ADVANCED → Summary Chest Rules)
	// El mod está siempre activo; no hay switch de Enabled.
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

		// Declarar opciones en el menú del juego (Ajustes → ADVANCED)
		flagKeepRare = ctx.settings.flag("keepRare", "Keep RARE", "Rare chests are kept; otherwise discarded.", true);
		flagKeepLegendary = ctx.settings.flag("keepLegendary", "Keep LEGENDARY", "Legendary chests are kept; otherwise discarded.", true);
		flagKeepItemBox = ctx.settings.flag("keepItemBox", "Keep item boxes", "Small and royal item boxes are kept.", true);
		flagKeepUncommon = ctx.settings.flag("keepUncommon", "Keep UNCOMMON", "Uncommon chests are kept; otherwise discarded.", true);
		flagKeepCommon = ctx.settings.flag("keepCommon", "Keep COMMON", "Common chests are kept; otherwise discarded.", true);
		sliderTimeout = ctx.settings.slider("keepTimeout", "Keep timeout", "Seconds to wait for the server to confirm KEEP.", 5, 30, 1, KEEP_TIMEOUT_DEFAULT / 1000, 0);

		// Volcar valores previos del settings.json propio (si lo había de la versión con hub)
		loadLegacySettings();

		// Reaccionar a cambios: reanudar si estaba pausado (storage full, timeout)
		flagKeepRare.onChange(function() { resume(); });
		flagKeepLegendary.onChange(function() { resume(); });
		flagKeepItemBox.onChange(function() { resume(); });
		flagKeepUncommon.onChange(function() { resume(); });
		flagKeepCommon.onChange(function() { resume(); });
		sliderTimeout.onChange(function() { resume(); });

		ctx.core.onObjectReady(function(object) {
			if (object == null)
				return;
			var className = "";
			try {
				className = Type.getClassName(Type.getClass(object));
			} catch (error:Dynamic) {}
			if (className == "distributedObjects.DistributedDungeonSummary") {
				summary = cast object;
				paused = false;
				pauseReason = "";
				cooldown = 0;
				keepSince = 0;
				keepCount = 0;
				Log.write("summary ready");
			}
		});
		ctx.core.onObjectGone(function(object) {
			if (object == summary) {
				summary = null;
				paused = false;
				pauseReason = "";
				keepSince = 0;
			}
		});
		ctx.overlay.addEventListener(Event.ENTER_FRAME, tick);
		Log.write("init always-on");
	}

	override public function ready(context:Context):Void {
		facade = context.core.facade;
	}

	override public function dispose():Void {
		if (ctx != null && ctx.overlay != null)
			ctx.overlay.removeEventListener(Event.ENTER_FRAME, tick);
		summary = null;
	}

	function loadLegacySettings():Void {
		var path = ctx.data + "/settings.json";
		try {
			if (FileSystem.exists(path)) {
				var content = File.getContent(path);
				if (content.charCodeAt(0) == 0xFEFF)
					content = content.substr(1);
				var data:Dynamic = Json.parse(content);
				if (data.keepRare != null)
					flagKeepRare.value = data.keepRare == true;
				if (data.keepLegendary != null)
					flagKeepLegendary.value = data.keepLegendary == true;
				if (data.keepItemBox != null)
					flagKeepItemBox.value = data.keepItemBox == true;
				if (data.keepUncommon != null)
					flagKeepUncommon.value = data.keepUncommon == true;
				if (data.keepCommon != null)
					flagKeepCommon.value = data.keepCommon == true;
				if (data.keepTimeout != null)
					sliderTimeout.value = Std.parseFloat(Std.string(data.keepTimeout));
			}
		} catch (error:Dynamic) {
			Log.write("could not read legacy settings.json: " + Std.string(error));
		}
	}

	function tick(_:Event):Void {
		if (summary == null)
			return;
		var now = Date.now().getTime();
		if (now - traceAt > 1000) {
			traceAt = now;
			trace(now);
		}
		if (summary.mChestTransactionFailedPopup != null) {
			// The server rejected the last transaction. Retrying it opens the same chest again and
			// can leave the summary in a bad state, so stop and leave the chest for the player.
			pause("transaction_failed");
			return;
		}
		if (facade == null || paused)
			return;
		if (!ctx.core.alive)
			return;
		if (summary.mLeaving)
			return;
		if (summary.mRevealState != 12 || summary.mTownHeader == null)
			return;

		// The summary opens the first chest's KEEP/DROP popup by itself. That popup is what makes
		// waiting for "no dialogs" deadlock: dismiss it and handle the slot directly instead.
		if (summary.mTreasureFoundPopup != null) {
			try {
				summary.closeKeyChestPopup();
				Log.write("closed treasure popup");
			} catch (error:Dynamic) {
				Log.write("could not close treasure popup: " + Std.string(error));
				pause("popup_failed");
				return;
			}
		}

		var count = summary.mItemCount;
		var keepTimeoutMs = sliderTimeout.value * 1000;
		if (keepSince > 0) {
			if (count != keepCount) {
				keepSince = 0;
			} else if (now - keepSince > keepTimeoutMs) {
				pause("keep_timeout");
				return;
			} else {
				return;
			}
		}
		if (count <= 0)
			return;
		if (now < cooldown)
			return;
		if (dialogsOpen())
			return;

		var slot = -1;
		var dooberId = 0;
		var report = summary.mDungeonReport;
		var row:Dynamic = report == null ? null : cast report[0];
		if (row != null) {
			var i = 0;
			while (i < 4 && slot < 0) {
				var value:Dynamic = Reflect.field(row, "chest_type_" + Std.string(i + 1));
				if (value != null && Std.int(value) != 0) {
					slot = i;
					dooberId = Std.int(value);
				}
				i++;
			}
		}
		if (slot < 0) {
			pause("missing_chest");
			return;
		}

		var doober:Dynamic = facade.gameMaster.dooberById.itemFor(dooberId);
		if (doober == null) {
			pause("missing_data");
			return;
		}
		var chestId = Std.int(Reflect.field(doober, "ChestId"));
		var gmChest:Dynamic = facade.gameMaster.chestsById.itemFor(chestId);
		if (gmChest == null) {
			pause("missing_data");
			return;
		}
		var gmId = Std.int(Reflect.field(gmChest, "Id"));
		var rarity = Std.string(Reflect.field(gmChest, "Rarity"));
		var keep = keepFor(rarity);

		if (keep)
			keepChest(slot, gmChest, rarity, count, now);
		else
			drop(slot, gmChest, rarity, now);
	}

	function trace(now:Float):Void {
		var report = summary.mDungeonReport;
		var first = "row=null";
		if (report != null) {
			try {
				var row:Dynamic = cast report[0];
				if (row != null)
					first = "valid=" + Reflect.field(row, "valid") + " c1=" + Reflect.field(row, "chest_type_1")
						+ " c2=" + Reflect.field(row, "chest_type_2") + " c3=" + Reflect.field(row, "chest_type_3")
						+ " c4=" + Reflect.field(row, "chest_type_4");
			} catch (error:Dynamic) {
				first = "row error=" + Std.string(error);
			}
		}
		Log.write("tick always-on paused=" + paused + " alive=" + ctx.core.alive + " leave=" + summary.mLeaving
			+ " reveal=" + summary.mRevealState + " header=" + (summary.mTownHeader != null) + " items=" + summary.mItemCount
			+ " dialogs=" + dialogsText() + " keep=" + keepSince + " cooldown=" + Std.int(cooldown - now) + " " + first);
	}

	function dialogsText():String {
		var out = "";
		if (summary.mInfoPopup != null)
			out += "mInfoPopup";
		if (summary.mTreasureFoundPopup != null)
			out += (out == "" ? "" : ",") + "mTreasureFoundPopup";
		if (summary.mChestRevealPopUp != null)
			out += (out == "" ? "" : ",") + "mChestRevealPopUp";
		if (summary.mStorageFullPopUp != null)
			out += (out == "" ? "" : ",") + "mStorageFullPopUp";
		if (summary.mChestTransactionFailedPopup != null)
			out += (out == "" ? "" : ",") + "mChestTransactionFailedPopup";
		if (summary.mAbandonChestPopUp != null)
			out += (out == "" ? "" : ",") + "mAbandonChestPopUp";
		if (summary.mChestBuyKeysPopUp != null)
			out += (out == "" ? "" : ",") + "mChestBuyKeysPopUp";
		if (summary.mUIInventory != null)
			out += (out == "" ? "" : ",") + "mUIInventory";
		return out == "" ? "none" : out;
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

	function keepChest(slot:Int, gmChest:Dynamic, rarity:String, count:Int, now:Float):Void {
		var storage = facade.dbAccountInfo.inventoryInfo;
		var oldLimit = storage.mStorageLimitWeapon;
		var raised = false;
		try {
			var gmId = Std.int(Reflect.field(gmChest, "Id"));
			if (!storage.hasRoomForChest(gmId)) {
				if (Type.resolveClass("mods.full_inventory.Main") != null) {
					// Full Inventory raises the client storage limit while its keep callbacks run.
					// Apply the same allowance to this direct keep so it stays compatible.
					storage.mStorageLimitWeapon = oldLimit + 10000;
					raised = true;
					Log.write("full inventory: raised storage limit for slot=" + slot);
				} else {
					// Let the game show its own storage-full popup instead of sending TakeChest and
					// getting a transaction error. The player can free a slot or abandon the chest.
					summary.mSelectedItemSlot = cast slot;
					summary.mSelectedGMChest = cast gmChest;
					summary.keepChestCallback();
					cooldown = now + 900;
					Log.write("storage full; native prompt slot=" + slot + " chest=" + gmId);
					return;
				}
			}
			summary.mSelectedGMChest = cast gmChest;
			summary.keepChestFromInventory(cast slot, true);
			keepSince = now;
			keepCount = count;
			cooldown = now + 900;
			Log.write("keep slot=" + slot + " rarity=" + rarity + " chest=" + gmId);
		} catch (error:Dynamic) {
			Log.write("keep failed: " + Std.string(error));
			pause("keep_failed");
		}
		if (raised)
			storage.mStorageLimitWeapon = oldLimit;
	}

	function drop(slot:Int, gmChest:Dynamic, rarity:String, now:Float):Void {
		try {
			summary.mNetworkComponent.send_DropChest(facade.dbAccountInfo.id, cast slot);
			summary.removeItemFromSlot(cast slot);
			cooldown = now + 450;
			Log.write("drop slot=" + slot + " rarity=" + rarity + " chest=" + Std.int(Reflect.field(gmChest, "Id")));
		} catch (error:Dynamic) {
			Log.write("drop failed: " + Std.string(error));
			pause("drop_failed");
		}
	}

	function dialogsOpen():Bool {
		return summary.mInfoPopup != null || summary.mTreasureFoundPopup != null || summary.mChestRevealPopUp != null
			|| summary.mStorageFullPopUp != null || summary.mChestTransactionFailedPopup != null
			|| summary.mAbandonChestPopUp != null || summary.mChestBuyKeysPopUp != null || summary.mUIInventory != null;
	}

	function pause(reason:String):Void {
		paused = true;
		pauseReason = reason;
		Log.write("pause: " + reason);
	}

	/** A settings change is a good moment to retry after a pause (storage full, timeout). */
	function resume():Void {
		paused = false;
		pauseReason = "";
	}
}
