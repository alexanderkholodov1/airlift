class_name GameLocale
extends RefCounted

const SETTINGS_PATH := "user://display_settings.cfg"
const _SECTION := "locale"
const _KEY := "language"

static var language: String = "es"


static func load_language() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		language = str(cfg.get_value(_SECTION, _KEY, "es"))


static func save_language(lang: String) -> void:
	language = lang
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value(_SECTION, _KEY, lang)
	cfg.save(SETTINGS_PATH)


static func t(key: String) -> String:
	var table: Dictionary = _EN if language == "en" else _ES
	return table.get(key, key)


const _ES: Dictionary = {
	"settings.title": "AJUSTES",
	"settings.subtitle": "Configuración básica",
	"settings.fullscreen": "PANTALLA COMPLETA",
	"settings.language": "IDIOMA: Español",
	"settings.back": "VOLVER",
	"arch.enter": "Cambiar plano",
	"arch.enter_foreground": "Regresar",
	"arch.exit": "Salir del arco",
	"arch.button": "[Click Der.]",
	"menu.play": "Jugar",
	"menu.credits": "Creditos",
	"menu.settings": "Ajustes",
	"menu.exit": "Salir",
	"death.title": "ALMA CONDENADA",
	"death.cause_prefix": "CAUSA",
	"death.reason_default": "Te consumió la oscuridad",
	"death.reason.health_depleted": "Salud agotada",
	"death.retry": "REINTENTAR [R]",
	"death.exit": "VOLVER AL MENÚ [ESC]",
	"death.hint": "EL GRAFO MUESTRA TU RASTRO MORAL RECIENTE",
	"ending.title_prefix": "TIPO DE FINAL",
	"ending.cause_prefix": "FINAL",
	"ending.view_credits": "VER CRÉDITOS",
	"ending.main_menu": "MENÚ PRINCIPAL [ESC]",
	"ending.hint": "TU RASTRO MORAL HA SIDO REGISTRADO",
	"heart.title": "Corazón de Moralidad",
	"heart.ira": "Ira",
	"heart.pereza": "Pereza",
	"heart.gula": "Gula",
	"heart.soberbia": "Soberbia",
}

const _EN: Dictionary = {
	"settings.title": "SETTINGS",
	"settings.subtitle": "Basic settings",
	"settings.fullscreen": "FULLSCREEN",
	"settings.language": "LANGUAGE: English",
	"settings.back": "BACK",
	"arch.enter": "Change plane",
	"arch.enter_foreground": "Return",
	"arch.exit": "Exit arch",
	"arch.button": "[RMB]",
	"menu.play": "Play",
	"menu.credits": "Credits",
	"menu.settings": "Settings",
	"menu.exit": "Exit",
	"death.title": "CONDEMNED SOUL",
	"death.cause_prefix": "CAUSE",
	"death.reason_default": "Darkness consumed you",
	"death.reason.health_depleted": "Health depleted",
	"death.retry": "RETRY [R]",
	"death.exit": "BACK TO MENU [ESC]",
	"death.hint": "THE GRAPH SHOWS YOUR RECENT MORAL TRAIL",
	"ending.title_prefix": "ENDING",
	"ending.cause_prefix": "ENDING",
	"ending.view_credits": "VIEW CREDITS",
	"ending.main_menu": "MAIN MENU [ESC]",
	"ending.hint": "YOUR MORAL TRAIL HAS BEEN RECORDED",
	"heart.title": "Heart of Morality",
	"heart.ira": "Wrath",
	"heart.pereza": "Sloth",
	"heart.gula": "Gluttony",
	"heart.soberbia": "Pride",
}
