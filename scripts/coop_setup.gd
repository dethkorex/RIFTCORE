extends RefCounted

const UI := preload("res://scripts/rift_ui.gd")
const STEAM_HELP := "https://help.steampowered.com/en/faqs/view/4B8B-9697-2338-40EC"

static func build(parent: VBoxContainer, back: Callable) -> void:
	UI.label(parent, "CO-OP SETUP GUIDE", 28, UI.CYAN)
	UI.label(parent, "Use the same RIFTCORE build", 20, UI.WHITE)
	UI.label(parent, "Both players should open the RIFTCORE launcher and install the same available update.", 17, UI.MUTED)
	UI.label(parent, "Connect with a room code", 20, UI.WHITE)
	UI.label(parent, "Open Online Room from the title. One player selects Create Room and shares the code. The other enters the code and selects Join Room. The relay handles the connection without port forwarding.", 17, UI.MUTED)
	UI.label(parent, "Add RIFTCORE to Steam  /  Optional", 20, UI.WHITE)
	UI.label(parent, "In Steam, open Games → Add a Non-Steam Game to My Library. Browse to the installed RIFTCORE launcher and confirm. Choose RIFTCORE.exe on Windows or the RIFTCORE launcher on Linux. Use the launcher so updates work through the same shortcut.", 17, UI.MUTED)
	UI.label(parent, "The shortcut launches RIFTCORE from your library. Steam invites and co-op missions are still in development.", 16, UI.MUTED)
	UI.button(parent, "Steam shortcut help", func(): OS.shell_open(STEAM_HELP))
	UI.button(parent, "Back", back, true).grab_focus()
