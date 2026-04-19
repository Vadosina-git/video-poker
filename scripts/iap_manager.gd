extends Node
## Autoload IapManager — facade over the in-app-purchase backend.
##
## Backends:
##   STUB       — local dev / desktop / editor. Instant credit, no real IAP.
##   REVENUECAT — production. Uses the godotx_revenue_cat plugin (Engine singleton
##                "GodotxRevenueCat"), which wraps RC iOS SDK 5.67.2 + Android SDK 10.1.2.
##
## Backend auto-selects at runtime: if the plugin singleton exists we use
## RevenueCat; otherwise we fall back to STUB. This lets the same code path
## run in editor (stub) and on device (real IAP).
##
## Signals:
##   purchase_success(product_id, chips_awarded)
##   purchase_failed(product_id, error)
##   purchase_canceled(product_id)
##   products_fetched(products) — Array of {id, price_string, title, description}
##
## Shop flow:
##   1. ShopOverlay opens → calls IapManager.fetch_products(ids) → receives
##      products_fetched with localized prices for button labels.
##   2. User taps pack → ShopOverlay calls IapManager.purchase(product_id).
##   3. IapManager triggers platform dialog (or grants instantly on stub).
##   4. On success, emits purchase_success → ShopOverlay animates reward.
##
## IMPORTANT: do NOT hard-code API keys here. This file is committed.
## Keys are read from env at build-time (see scripts/build_android_release.sh)
## or set via Project Settings > Application > IapManager > revenuecat_api_key_*.

signal purchase_success(product_id: String, chips_awarded: int)
signal purchase_failed(product_id: String, error: String)
signal purchase_canceled(product_id: String)
signal products_fetched(products: Array)

enum Backend { STUB, REVENUECAT }

# API keys injected at build time. Leave empty here so repo stays clean.
# scripts/build_*_release.sh reads .keystore.env / .revenuecat.env and
# populates via sed before export.
const RC_API_KEY_IOS := ""
const RC_API_KEY_ANDROID := ""

var backend: Backend = Backend.STUB
var _rc: Object = null  # Engine.get_singleton("GodotxRevenueCat") or null
var _pending_product: String = ""


func _ready() -> void:
	_detect_backend()


func _detect_backend() -> void:
	if Engine.has_singleton("GodotxRevenueCat"):
		_rc = Engine.get_singleton("GodotxRevenueCat")
		var key := _api_key_for_platform()
		if key == "":
			push_warning("IapManager: no RevenueCat API key configured — staying on STUB backend. "
				+ "Set RC_API_KEY_IOS / RC_API_KEY_ANDROID before release build.")
			return
		_rc.customer_info_changed.connect(_on_customer_info_changed)
		_rc.purchase_result.connect(_on_rc_purchase_result)
		_rc.products.connect(_on_rc_products)
		_rc.initialize(key, "", false)  # (api_key, app_user_id, debug_logs)
		backend = Backend.REVENUECAT
		print("IapManager: RevenueCat backend active")
	else:
		# Editor / desktop / non-mobile build — plugin singleton absent.
		backend = Backend.STUB


func _api_key_for_platform() -> String:
	match OS.get_name():
		"iOS":
			return RC_API_KEY_IOS
		"Android":
			return RC_API_KEY_ANDROID
		_:
			return ""


## Shop opens → prewarm products so Buy buttons can show localized prices.
func fetch_products(product_ids: Array) -> void:
	match backend:
		Backend.REVENUECAT:
			_rc.fetch_products(product_ids)
		Backend.STUB:
			# Stub returns the chip amounts from config as "prices" for dev UI.
			var items: Array = []
			for pid in product_ids:
				var chips := _lookup_chips(str(pid))
				items.append({
					"id": pid,
					"price_string": "FREE",
					"title": pid,
					"description": "%d chips" % chips,
				})
			products_fetched.emit(items)


## Initiate a purchase. Product must be registered in App Store Connect / Play
## Console with matching id and in the RevenueCat dashboard offering.
func purchase(product_id: String) -> void:
	if _pending_product != "":
		return
	_pending_product = product_id
	match backend:
		Backend.STUB:
			_purchase_stub(product_id)
		Backend.REVENUECAT:
			_rc.purchase(product_id)


func _purchase_stub(product_id: String) -> void:
	var chips := _lookup_chips(product_id)
	if chips <= 0:
		_pending_product = ""
		purchase_failed.emit(product_id, "unknown_product")
		return
	SaveManager.add_credits(chips)
	SaveManager.save_game()
	var pid := _pending_product
	_pending_product = ""
	purchase_success.emit(pid, chips)


## App Store policy: shops MUST expose a "Restore Purchases" button.
## For consumables it's mostly a no-op (nothing to restore), but the button
## being present is what reviewers check.
func restore_purchases() -> void:
	match backend:
		Backend.REVENUECAT:
			_rc.restore_purchases()
		Backend.STUB:
			# No-op on stub; still emit a dummy event for UI feedback.
			products_fetched.emit([])


# --- RevenueCat callbacks ---------------------------------------------------

func _on_rc_purchase_result(data: Dictionary) -> void:
	var pid := _pending_product
	_pending_product = ""
	if data.get("success", false):
		var chips := _lookup_chips(pid)
		SaveManager.add_credits(chips)
		SaveManager.save_game()
		purchase_success.emit(pid, chips)
	elif data.get("userCancelled", false) or str(data.get("error", "")).findn("cancel") >= 0:
		purchase_canceled.emit(pid)
	else:
		purchase_failed.emit(pid, str(data.get("error", "unknown")))


func _on_rc_products(data: Dictionary) -> void:
	# Normalize iOS Array vs Android JavaObject into a plain Array of Dicts.
	var raw: Variant = data.get("products", null)
	var out: Array = []
	if raw is Array:
		for p in raw:
			out.append({
				"id": str(p.get("id", "")),
				"price_string": str(p.get("price", "")),
				"title": str(p.get("title", "")),
				"description": str(p.get("description", "")),
			})
	elif raw is JavaObject:
		var count: int = int(raw.call("size"))
		for i in count:
			var p: Variant = raw.call("get", i)
			out.append({
				"id": str(p.get("id", "")),
				"price_string": str(p.get("price", "")),
				"title": str(p.get("title", "")),
				"description": str(p.get("description", "")),
			})
	products_fetched.emit(out)


func _on_customer_info_changed(_data: Dictionary) -> void:
	# Hook for future use — e.g. subscription lifecycle, cross-device sync.
	# For consumables only, nothing to do here.
	pass


# --- Helpers ----------------------------------------------------------------

func _lookup_chips(product_id: String) -> int:
	var items: Array = ConfigManager.get_shop_items()
	for item in items:
		if str(item.get("id", "")) == product_id:
			return int(item.get("chips", 0)) + int(item.get("bonus_chips", 0))
	return 0
