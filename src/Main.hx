package mods.summary_chest_rules;

import distributedObjects.DistributedDungeonSummary;
import facade.DBFacade;
import mods.api.Context;
import mods.api.Mod;
import mods.mod_hub_api.Hub;
import mods.mod_hub_api.HubChoice;
import mods.mod_hub_api.HubEntry;
import mods.mod_hub_api.HubSetting;
import openfl.events.Event;

/**
 * At the victory summary, keeps or discards the four reward chests according to their rarity.
 *
 * It uses the same server calls as the KEEP and DROP buttons; it only does the clicking.
 */
@:privateAccess
class Main extends Mod {
	/** How long a KEEP may wait for the account answer before the summary is left alone. */
	static inline final KEEP_TIMEOUT = 10000.0;

	var ctx:Context;

	var facade:DBFacade;

	var settings:Settings;

	var summary:DistributedDungeonSummary;

	var paused:Bool = false;

	var pauseReason:String = "";

	var cooldown:Float = 0;

	var keepSince:Float = 0;

	var keepCount:Int = 0;

	/** One diagnostic line per second while a summary exists, to see what gate stops the run. */
	var traceAt:Float = 0;

	override public function init(context:Context):Void {
		ctx = context;
		try {
			Log.start(ctx.data);
		} catch (error:Dynamic) {}
		settings = new Settings(ctx.data, ctx.log);
		register();
		Hub.onLanguageChanged(languageChanged);
		ctx.core.onObjectReady(function(object) {
			if (Std.isOfType(object, DistributedDungeonSummary)) {
				summary = cast object;
				paused = false;
				pauseReason = "";
				cooldown = 0;
				keepSince = 0;
				keepCount = 0;
				Log.write("summary ready");
				Hub.notifyChanged();
			}
		});
		ctx.core.onObjectGone(function(object) {
			if (object == summary) {
				summary = null;
				paused = false;
				pauseReason = "";
				keepSince = 0;
				Hub.notifyChanged();
			}
		});
		ctx.overlay.addEventListener(Event.ENTER_FRAME, tick);
		Log.write("init enabled=" + settings.enabled);
	}

	override public function ready(context:Context):Void {
		facade = context.core.facade;
	}

	override public function dispose():Void {
		Hub.unregister("summary_chest_rules");
		Hub.offLanguageChanged(languageChanged);
		if (ctx != null && ctx.overlay != null)
			ctx.overlay.removeEventListener(Event.ENTER_FRAME, tick);
		summary = null;
	}

	function register():Void {
		var list:Array<HubSetting> = [
			boolSetting("enabled", tr("Enabled", "Activo"), tr("Processes the chests at the end of a run.", "Procesa los cofres al terminar la partida."), function() {
				return settings.enabled;
			}, function(value:Bool) {
				settings.enabled = value;
				settings.save();
				resume();
			}),
			boolSetting("keepRare", tr("Keep RARE", "Guardar RARO"), tr("Rare chests are kept; otherwise discarded.", "Los cofres raros se guardan; si no, se descartan."), function() {
				return settings.keepRare;
			}, function(value:Bool) {
				settings.keepRare = value;
				settings.save();
				resume();
			}),
			boolSetting("keepLegendary", tr("Keep LEGENDARY", "Guardar LEGENDARIO"), tr("Legendary chests are kept; otherwise discarded.", "Los legendarios se guardan; si no, se descartan."), function() {
				return settings.keepLegendary;
			}, function(value:Bool) {
				settings.keepLegendary = value;
				settings.save();
				resume();
			}),
			boolSetting("keepItemBox", tr("Keep item boxes", "Guardar item boxes"), tr("Small and royal item boxes are kept.", "Las cajas de objetos (small y royal) se guardan."), function() {
				return settings.keepItemBox;
			}, function(value:Bool) {
				settings.keepItemBox = value;
				settings.save();
				resume();
			}),
			boolSetting("keepUncommon", tr("Keep UNCOMMON", "Guardar POCO COMÚN"), tr("Uncommon chests are kept; otherwise discarded.", "Los poco comunes se guardan; si no, se descartan."), function() {
				return settings.keepUncommon;
			}, function(value:Bool) {
				settings.keepUncommon = value;
				settings.save();
				resume();
			}),
			boolSetting("keepCommon", tr("Keep COMMON", "Guardar COMÚN"), tr("Common chests are kept; otherwise discarded.", "Los comunes se guardan; si no, se descartan."), function() {
				return settings.keepCommon;
			}, function(value:Bool) {
				settings.keepCommon = value;
				settings.save();
				resume();
			}),
			choiceSetting("whenFull", tr("When storage is full", "Si no hay hueco"), tr("What to do when a kept chest does not fit.", "Qué hacer si un cofre no cabe."), function() {
				return settings.whenFull;
			}, function(value:String) {
				settings.whenFull = value == "drop" ? "drop" : "pause";
				settings.save();
				resume();
			}, [
				{id: "pause", label: tr("Pause", "Pausar")},
				{id: "drop", label: tr("Discard", "Descartar")}
			])
		];
		var entry:HubEntry = {
			id: "summary_chest_rules",
			name: tr("Summary Chests", "Cofres del resumen"),
			description: tr("Keeps or discards victory chests by rarity.", "Guarda o descarta los cofres de la victoria."),
			category: "Inventario",
			order: 20,
			status: function():String {
				return statusText();
			},
			settings: list
		};
		if (!Hub.register(entry))
			Log.write("could not register in Mod Hub");
		else
			Log.write("register language=" + Hub.language + " name=" + entry.name);
	}

	function boolSetting(id:String, label:String, description:String, get:Void->Bool, apply:Bool->Void):HubSetting {
		return {
			id: id,
			label: label,
			description: description,
			type: "bool",
			get: function():Dynamic {
				return get();
			},
			set: function(value:Dynamic):Void {
				Log.write("setting " + id + "=" + Std.string(value));
				apply(value == true);
			}
		};
	}

	function choiceSetting(id:String, label:String, description:String, get:Void->String, apply:String->Void,
			choices:Array<HubChoice>):HubSetting {
		return {
			id: id,
			label: label,
			description: description,
			type: "choice",
			get: function():Dynamic {
				return get();
			},
			set: function(value:Dynamic):Void {
				Log.write("setting " + id + "=" + Std.string(value));
				apply(Std.string(value));
			},
			choices: choices
		};
	}

	function statusText():String {
		if (!settings.enabled)
			return tr("Disabled", "Desactivado");
		if (paused)
			return tr("Paused: ", "Pausado: ") + pauseText(pauseReason);
		if (summary != null)
			return tr("Processing the summary", "Procesando el resumen");
		return tr("Waiting for a summary", "Esperando un resumen");
	}

	function pauseText(key:String):String {
		if (key == "keep_timeout")
			return tr("the server did not confirm KEEP", "el servidor no confirmó el KEEP");
		if (key == "missing_chest")
			return tr("the pending chest was not found", "no encuentro el cofre pendiente");
		if (key == "missing_data")
			return tr("the chest is not in the game data", "el cofre no está en los datos del juego");
		if (key == "storage_full")
			return tr("chest storage is full", "inventario de cofres lleno");
		if (key == "keep_failed")
			return tr("KEEP failed", "KEEP falló");
		if (key == "drop_failed")
			return tr("DROP failed", "DROP falló");
		if (key == "popup_failed")
			return tr("the chest popup could not be closed", "no pude cerrar el popup del cofre");
		return key;
	}

	function tr(en:String, es:String):String {
		return Hub.language == "es" ? es : en;
	}

	function languageChanged():Void {
		Log.write("language=" + Hub.language);
		register();
	}

	function tick(_:Event):Void {
		if (summary == null)
			return;
		var now = Date.now().getTime();
		if (now - traceAt > 1000) {
			traceAt = now;
			trace(now);
		}
		if (facade == null || !settings.enabled || paused)
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
		if (keepSince > 0) {
			if (count != keepCount) {
				keepSince = 0;
			} else if (now - keepSince > KEEP_TIMEOUT) {
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

		if (keep && !facade.dbAccountInfo.inventoryInfo.hasRoomForChest(gmId)) {
			if (settings.whenFull == "drop") {
				drop(slot, gmChest, rarity, now);
			} else {
				pause("storage_full");
			}
			return;
		}
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
		Log.write("tick enabled=" + settings.enabled + " paused=" + paused + " alive=" + ctx.core.alive + " leave=" + summary.mLeaving
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
			return settings.keepCommon;
		if (rarity == "UNCOMMON")
			return settings.keepUncommon;
		if (rarity == "RARE")
			return settings.keepRare;
		if (rarity == "LEGENDARY")
			return settings.keepLegendary;
		if (rarity == "CONSUMABLE_SMALL" || rarity == "CONSUMABLE_ROYAL")
			return settings.keepItemBox;
		// The summary only carries chests; keep anything unexpected rather than lose it.
		return true;
	}

	function keepChest(slot:Int, gmChest:Dynamic, rarity:String, count:Int, now:Float):Void {
		try {
			summary.mSelectedGMChest = cast gmChest;
			summary.keepChestFromInventory(cast slot, true);
			keepSince = now;
			keepCount = count;
			cooldown = now + 900;
			Log.write("keep slot=" + slot + " rarity=" + rarity + " chest=" + Std.int(Reflect.field(gmChest, "Id")));
		} catch (error:Dynamic) {
			Log.write("keep failed: " + Std.string(error));
			pause("keep_failed");
		}
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
		Hub.notifyChanged();
	}

	/** A settings change is a good moment to retry after a pause (storage full, timeout). */
	function resume():Void {
		paused = false;
		pauseReason = "";
	}
}
