extends RefCounted

const UI := preload("res://scripts/rift_ui.gd")
const STEAM_HELP := "https://help.steampowered.com/en/faqs/view/4B8B-9697-2338-40EC"

static func build(parent: VBoxContainer, back: Callable) -> void:
	UI.label(parent, "CO-OP SETUP GUIDE", 28, UI.CYAN)
	UI.label(parent, "Use the same RIFTCORE build", 20, UI.WHITE)
	UI.label(parent, "Both players should open the RIFTCORE launcher and install the same available update.", 17, UI.MUTED)
	UI.label(parent, "Connect with a room code", 20, UI.WHITE)
	UI.label(parent, "Open Social at the station. One player selects Create Room and shares the code. The other enters the code and selects Join Room. When both players are connected, the host selects Deploy Co-op to start Neon Factory Defense. The relay handles the connection without port forwarding.", 17, UI.MUTED)
	if not RiftRelay.available:
		UI.label(parent, RiftRelay.RELAY_UNAVAILABLE, 16, UI.MUTED)
	UI.label(parent, "Add RIFTCORE to Steam  /  Optional", 20, UI.WHITE)
	UI.label(parent, "In Steam, open Games → Add a Non-Steam Game to My Library. Browse to the installed RIFTCORE launcher and confirm. Choose RIFTCORE.exe on Windows. On Linux, browse to ~/.local/share/riftcore/RIFTCORE, or choose the RIFTCORE file inside the extracted folder. Leave Steam Play compatibility disabled so it launches the native Linux build.", 17, UI.MUTED)
	UI.label(parent, "A library shortcut launches RIFTCORE. Steam friends and invites require an official RIFTCORE Steam App ID and a signed-in Steam account.", 16, UI.MUTED)
	UI.button(parent, "Steam shortcut help", func(): OS.shell_open(STEAM_HELP))
	UI.button(parent, "Back", back, true).grab_focus()
