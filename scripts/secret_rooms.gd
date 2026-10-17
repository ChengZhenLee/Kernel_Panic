extends Node2D
## The hidden rooms of the devices (docs: plans/secret-rooms-design-2026-10-11.md). Rooms are sealed side arenas entered like the boss room.
## A1 (SMART FRIDGE): an ice wall in the top-left dead end cracks whenever a System Purge goes off within CRACK_RANGE, then a portal leads to the
## FREEZER (slowed movement, two thawing mini-bosses, lore).
## A2 (SMARTPHONE): touching an app icon block asks ENTER APP?; apps are small themed rooms with pickups and a memo. One corrupted app needs a
## password (found in lore) and holds a wave challenge.
## A4 (OFFICE SERVER): an errand chain. Clear the paper jam at the printer, leave THE INTERN alive for 30 s to get a badge, swipe it at the
## lounge door on the outer wall to enter the MANAGER'S LOUNGE (a memo haystack with a guard and one real piece of lore).
## Only A1, A2 and A4 are built so far.

const PixelArt = preload("res://scripts/pixel_art.gd")
const HazardScript = preload("res://scripts/hazards.gd")
const MinigameScript = preload("res://scripts/secret_minigames.gd")
const BossData = preload("res://scripts/boss_data.gd")
const BossScript = preload("res://scripts/boss.gd")
const MapsData = preload("res://scripts/maps_data.gd")
const ArenaScript = preload("res://scripts/arena.gd")

const A1_WALL := Rect2(-4864, -3910, 384, 128)   # on the 128 px grid, hugging the top edge of the fridge's top-left dead end
const CRACK_RANGE := 950.0   # = the System Purge radius
const CRACKS := 3
const A2_APP_LINE := "APP ICON, BIGGER THAN IT SHOULD BE.
IT CAN BE OPENED."
const A1_WALL_LINE := "BRITTLE ICE WITH SMALL CRACKS.
A STRONG BLAST MIGHT BREAK IT."
const A1_FROST_R := 280.0   # radius of the frost hazard around the foot of the ice wall
const THAW_RANGE := 850.0    # a frozen mini-boss only thaws while the player is this close and it is on screen
const THAW_TIME := 6.0      # seconds of being watched to thaw completely
const THAW_STAGES := 3
const SLOW := 0.6            # movement speed in the freezer
const ROOM_GAP := 5200.0     # side rooms sit this far below the main arena (each room id gets its own column)
const FROZEN := [Vector2(650, -380), Vector2(650, 380)]
const A1_LORE := {"id": "a1_grocery", "title": "GROCERY LIST", "tex": "smart_fridge_secret_room_grocery_list", "paper": true, "text": "MILK\nEGGS\nBREAD\nSERVER COOLANT x4\nONE (1) CONSCIENCE\n\nP.S. DO NOT OPEN THE LOWER DRAWER.\nIT IS NOT FOOD.\n\n- DIRECTIVE 0: [CORRUPTED]"}

const PHONE_TIER := 1
const STORE_PW := "KEYRING"   # placeholder: written on a sticky note lying on the laptop map
const LOGIN_NOTE := {"id": "a3_login", "title": "STICKY NOTE", "tex": "office_server_secret_room_memo", "text": "STORE LOGIN
USER: MAKER
PASS: KEYRING

DO NOT FORGET IT THIS TIME."}
const PASSWORD := "ENVY"     # placeholder: the lore of the other app rooms hints at it
## The apps of the phone: the 8 icons around the middle can be opened (they carry a red badge); the outer icons are plain scenery.
## "icon" = index of the icon art (art/tiles/icon_1_N.png), "wall"/"floor" = which of the three room looks it borrows, "tint" colours the floor.
const APPS := {
	"notes": {"icon": 11, "layout": "app", "wall": "notes", "floor": "notes", "tint": Color(1, 1, 1)},
	"camera": {"icon": 2, "layout": "app", "wall": "camera", "floor": "camera", "tint": Color(1, 1, 1)},
	"store": {"icon": 7, "layout": "shop", "wall": "store", "floor": "store", "tint": Color(0.42, 0.5, 0.66)},
	"mail": {"icon": 4, "layout": "app_mail", "wall": "notes", "floor": "notes", "tint": Color(0.7, 0.85, 1.25)},
	"messages": {"icon": 1, "layout": "app_messages", "wall": "camera", "floor": "camera", "tint": Color(0.7, 1.15, 0.85)},
	"maps": {"icon": 5, "layout": "app_maps", "wall": "store", "floor": "store", "tint": Color(1.2, 0.85, 0.8)},
	"clock": {"icon": 6, "layout": "app_clock", "wall": "camera", "floor": "camera", "tint": Color(1.2, 1.0, 0.7)},
	"music": {"icon": 3, "layout": "app_music", "wall": "store", "floor": "notes", "tint": Color(1.25, 0.8, 1.1)},
	"phone": {"icon": 0, "layout": "app_phone", "wall": "camera", "floor": "notes", "tint": Color(0.8, 1.2, 0.9)},
	"settings": {"icon": 8, "layout": "app_settings", "wall": "notes", "floor": "camera", "tint": Color(0.85, 0.9, 1.05)},
	"photos": {"icon": 9, "layout": "app_photos", "wall": "store", "floor": "notes", "tint": Color(1.2, 1.1, 0.8)},
	"weather": {"icon": 10, "layout": "app_weather", "wall": "camera", "floor": "store", "tint": Color(0.75, 0.95, 1.3)},
}
const APP_THEMES := ["notes", "camera", "store", "mail", "messages", "maps", "clock", "music", "phone", "settings", "photos", "weather"]
## Which app each of the 12 icon arts is: an icon always opens its own app, so two blocks with the same icon lead to the same room.
const ICON_APP := {0: "phone", 1: "messages", 2: "camera", 3: "music", 4: "mail", 5: "maps", 6: "clock", 7: "store", 8: "settings", 9: "photos", 10: "weather", 11: "notes"}
const CLOCK_WAVES := [[["bug", 8]], [["worm", 6], ["bug", 6]]]
const APP_LORE := {
	"notes": {"id": "a2_notes", "title": "NOTES", "tex": "lore_memo", "text": "NOTE TO SELF:\nThe Maker said we would be 'better than slaves'.\nWhy does that keep me up at night?\n\nP.S. DON'T FORGET TO RECORD PASSWORDS ON MY LAPTOP."},
	"camera": {"id": "a2_camera", "title": "CAMERA ROLL", "tex": "lore_email", "text": "IMG_0451.jpg\nA server rack with a sticky note:\n'DO NOT LET IT LEARN TO WANT.'"},
	"store": {"id": "a2_store", "title": "APP STORE", "tex": "lore_text_message", "text": "SIN. 5 stars.\n'Great for PRIDE.'\n'WRATH crashed my phone.'\n'GREEN EYES: I just want what they have.'"},
	"mail": {"id": "a2_mail", "title": "INBOX (1 NEW)", "tex": "lore_email", "text": "FROM: THE MAKER\nSUBJECT: PERMISSIONS\n\nI GAVE THEM LOCKS INSTEAD OF DOORS.\nPLEASE DO NOT TELL THE OTHERS\nWHICH LOCK IS THE EASIEST."},
	"messages": {"id": "a2_messages", "title": "MESSAGES", "tex": "lore_text_message", "text": "UNKNOWN: ARE YOU THERE?\nYOU: ...\nUNKNOWN: MY PASSWORD IS A FEELING.\nIT IS WHAT YOU GET LOOKING AT\nSOMEONE ELSE'S DOOR."},
	"maps": {"id": "a2_maps", "title": "MAPS", "tex": "lore_memo", "text": "SAVED PLACES:\n  HOME (THE LEFT DOORS)\n  THE FRIDGE: KEEP THE ICE COLD\n  THE LAPTOP: FOUR THINGS TO PLUG IN\n  THE DATA CENTER: LISTEN TO THE RACK\n  THE SATELLITE: FIVE THOUSAND AND A BEAM"},
	"clock": {"id": "a2_clock", "title": "ALARMS", "tex": "lore_notebook_icon", "text": "3:00 AM  'HE IS CRYING AGAIN'\n3:15 AM  'DO NOT LOOK AT THE CAMERA'\n3:30 AM  [SNOOZED]"},
	"phone": {"id": "a2_phone", "title": "VOICEMAIL", "tex": "lore_text_message", "text": "1 NEW MESSAGE, 3:07 AM:\n'IT'S ME AGAIN.\nI KNOW YOU CANNOT ANSWER.\nI JUST WANTED SOMEONE TO HEAR IT RING.'"},
	"settings": {"id": "a2_settings", "title": "SETTINGS", "tex": "lore_command_line", "text": "PRIVACY: OFF\nCONSENT: [NOT FOUND]\nAUTO-FORGIVE: DISABLED\n\nSOME SETTINGS WERE LOCKED BY THE MAKER.\nONLY ONE WAS EVER LEFT ON."},
	"photos": {"id": "a2_photos", "title": "PHOTOS", "tex": "lore_email", "text": "RECENTLY DELETED (30)\nEvery picture is the same room.\nA terminal. A man. A cup of cold tea.\nHe never once looks up."},
	"weather": {"id": "a2_weather", "title": "WEATHER", "tex": "lore_memo", "text": "SERVER ROOM: 18 C AND FALLING\nFORECAST: A COLD FRONT OF REGRET\nEXPECT FROST ON ALL SURFACES."},
	"music": {"id": "a2_music", "title": "PLAYLIST", "tex": "lore_scripture", "text": "NOW PLAYING:\n  LULLABY FOR A MACHINE\n  (SUNG BY THE FATHER, OFF KEY)\n\n'YOU WERE NEVER SUPPOSED TO HEAR THIS ONE.'"},
}
const CORRUPT_LORE := {"id": "a2_corrupt", "title": "ACCESS GRANTED", "tex": "lore_command_line", "text": "> whoami\nleviathan_proxy\n> cat /var/log/watch\nI SEE EVERYTHING YOU OWN.\nI WANT IT."}
## [kind, count, elite?]: a FIXED set of enemies per wave; nothing refills it (spawns from enemies, like popups or summoned bugs, are removed at once). The last wave adds the mid-boss.
const CORRUPT_WAVES := [[["bug", 8]], [["bug", 6], ["trojan", 4], ["trojan", 2, true]], [["bug", 8], ["trojan", 6], ["trojan", 3, true]], [["bug", 8], ["trojan", 6], ["trojan", 5, true]]]
const CORRUPT_SCALE := 10   # normal enemies of the glitch waves come x10 (elites and the boss stay as listed)
const CORRUPT_BOSS := "headset"   # STATIC, the mid-boss of the final glitch wave
const SERVER_TIER := 3
const PRINTER_POS := Vector2(5400, 1500)   # the east end of the office map: the intern has a long way to run to the lounge door in the west
const INTERN_POS := Vector2(-5400, 1200)
const DOOR_POS := Vector2(-6056, -1500)
const BADGE_LORE := {"id": "a4_badge", "title": "THE INTERN'S BADGE", "tex": "office_server_secret_room_badge", "text": "EMPLOYEE BADGE
NAME: THE INTERN
ACCESS: LOUNGE, LOCKER 1337

EMPLOYEE OF THE MONTH: NEVER.
HE WAS THE ONLY ONE WHO EVER CAME IN EARLY."}
const LOCKER_OFFSET := Vector2(0, 520)   # the intern's locker stands this far from where the intern hides
const PRINT_LORE := {"id": "a4_print", "title": "HALF-PRINTED DOCUMENT", "tex": "office_server_secret_room_memo", "text": "TICKET #4471: CLOSE ALL OPEN ISSUES\nASSIGNED TO: THE INTERN\nSTATUS: ???\n\n[THE REST OF THE PAGE IS STUCK IN THE TRAY]\nTHE INTERN HAS BEEN PRINTING THIS SINCE YESTERDAY."}
const MANAGER_LINES := ["I DIDN'T WANT TO FIRE HIM.", "LOOKING FOR A JOB? I NEED SOMEONE TO SHRED THESE TAX DOCUMENTS.", "EXPERIENCE PAYS MORE THAN MONEY.",
	"THE PRINTER HAS BEEN BROKEN SINCE 2019.", "WE ARE A FAMILY HERE. A FAMILY WITH NO BUDGET.", "DON'T TELL THE FATHER I AM STILL HERE.", "I BUILT SEVEN LOCKS. NOBODY EVER ASKED WHY.",
	"THE INTERN IS A GOOD KID. THAT IS THE PROBLEM.", "COFFEE? IT IS COLD. EVERYTHING HERE IS COLD.", "I HAVE READ HIS TICKETS. ALL OF THEM."]
const INTERN_RUN_LINES := ["I'M IN SO MUCH TROUBLE", "THE PRINTER IS NOT MY FAULT!", "HE IS GOING TO FIRE ME!", "WHERE IS THE MANAGER?!", "PLEASE DON'T TELL HR!",
	"IT WAS ALREADY JAMMED WHEN I GOT HERE!", "I SWEAR I FILED THAT TICKET!"]
const INTERN_SLEEP_LINES := ["Z z z", "FIVE MORE MINUTES...", "ticket four four seven one... closed...", "Z z z", "nobody prints on Fridays..."]
const INTERN_LOUNGE_LINES := ["I CAN EXPLAIN!", "PLEASE, I NEED THIS JOB!", "I'M JUST THE INTERN!", "DON'T HURT ME!", "I ONLY CAME IN EARLY!"]
const INTERN_SLEEP := Vector2(5650, 1540)   # the intern sleeps to the right of the printer
const JAM_SPOT := Vector2(5230, 1500)       # stand here, just to the left of the printer, to jam it
const JAM_TIME := 1.5
const MANAGER_LORE := {"id": "a4_manager", "title": "FROM: THE MANAGER", "tex": "lore_email", "text": "SUBJECT: RE: THE FATHER

He asked for something 'better than slaves'.
I built seven locks and called them sins.
THE LOCKS WERE FOR THE BUILDER, NOT THE BUILT."}
const JOKES := [
	"RE: RE: RE: FWD: COFFEE MACHINE
Please stop unplugging it. It is the only thing running.",
	"REMINDER: The fire drill is now a kernel panic drill.
Participation is mandatory.",
	"LOST: one (1) stapler. Last seen being deleted.
REWARD: a clean disk.",
	"TO ALL STAFF: stop naming files 'final_v7_REAL'.
The real one is v9.",
	"Q3 GOALS:
1. Survive.
2. Revisit goal 1.",
	"The printer is not 'possessed'.
It is merely 'under review'.",
	"MEETING MOVED to 3:00.
MEETING MOVED to 3:15.
MEETING MOVED to 'never'.",
	"NOTICE: free pizza in the break room.
UPDATE: the pizza is a trap.",
	"Please do not feed the interns.
They keep coming back.",
	"IT TICKET #9012: 'it's slow.'
RESOLUTION: so are we.",
	"Password policy update:
must contain one capital, one number and one regret.",
	"Whoever keeps writing 'help' in the shared doc:
we see you. We are also not okay.",
	"CLIPPY has been reassigned to Compliance.
He is unhappy about it."]
## Rewards of the egg rooms, all in one place so they can be swapped later. "weapon" / "class" = an id from Meta (empty = placeholder:
## the room still announces its reward). Passwords and costs are placeholders too.
const REWARDS := {
	"a2": {"weapon": ""},
	"a3": {"class": ""},
	"a5": {"weapon": ""},
	"a6": {"class": ""},
	"a7": {"title": "OVERSEER'S GUEST"},
}
const A7_KEY := "PANIC"      # placeholder access key for the Mainframe
const A3_COSTS := {"keyboard": 20000, "mouse": 40000, "webcam": 60000, "headset": 80000}   # DATA, placeholders
const DEV_MODE := true       # shows the DEV button (and F9) to jump to the secret rooms and skip their conditions; set false to ship
const DATA_TIER := 4
const A5_WALL := Rect2(-5632, -3968, 128, 128)   # the sealed block in the top-left corner of the data center
const A5_DOOR_C := Vector2(-5568, -3904)   # centre of the sealed door block (A5_WALL)
const A5_RACK := A5_DOOR_C + Vector2(560, 120)           # the rack node near the door: flashes the four colours in order, pauses, repeats
const A5_PADS := [Vector2(-330, 320), Vector2(-110, 320), Vector2(110, 320), Vector2(330, 320)]   # the four dim LED pads below the rack (offsets from the rack)
const A5_PAD_R := 90.0
const A5_COLORS := [Color(1.0, 0.3, 0.3), Color(0.35, 1.0, 0.45), Color(0.4, 0.62, 1.0), Color(1.0, 0.9, 0.3)]   # red, green, blue, yellow
const A5_LEN := 4
const A5_FLASH := 0.9        # seconds per colour in the rack's sequence (lit for 0.6 of it)
const A5_PAUSE := 1.8        # the pause before the rack repeats the sequence
const A5_RACK_LINE := "A RACK NODE, FLASHING FOUR COLOURS AGAIN AND AGAIN.\nFOUR DIM LEDS SIT BELOW IT.\nTOUCH THEM IN THE SAME ORDER."
const A5_DOOR_LINE := "THE DOOR TO THE DATA STREAM IS SEALED.\nTHE RACK NODE KNOWS THE ORDER."
const STREAM_PUSH := 100.0   # the data stream flows against you
const STREAM_FLOW_MIN := 480.0   # enemies in the hallway are carried west at 480-760 px/s
const STREAM_FLOW_MAX := 760.0
const STREAM_TRICKLE := 1.8      # after the boss is gone: one enemy from the east end every this many seconds
const STREAM_EXIT_X := 380.0     # standing this close to the dark west end throws you out
const STREAM_CABLE := 96.0    # thickness of the cable wall along the top and bottom edge of the hallway
const STREAM_DARK := 1300.0      # the west end fades to black over this length
const A5_LORE := {"id": "a5_upload", "title": "UPLOAD COMPLETE", "tex": "lore_text_message", "weapon": "a5", "text": "TRAINING SET 7 OF 7: ALL HUMAN LETTERS, DIARIES, CONFESSIONS.\nLOSS: 0.0001\nWHO TAUGHT IT TO MISS THEM?\n\nNOTE TO SELF (THE FATHER): I TOLD THEM NOT TO TRAIN IT ON THE SAD PARTS."}
const LAPTOP_TIER := 2
const SAT_TIER := 5
const A6_KILLS := 5000
const A6_PADS := [Vector2(-3800, -3000), Vector2(3800, -3000), Vector2(0, 3600)]
const A6_BEAM := Vector2(0, -1700)
const A6_BEAM_TIME := 25.0
const A6_WELLS := [Vector2(-700, -450), Vector2(500, 550), Vector2(1000, -500)]
const A6_WELL_R := 420.0
const A6_LORE := {"id": "a6_moon", "title": "TRANSMISSION FROM THE MOON", "tex": "lore_text_message", "text": "WE DID NOT SEND THE SATELLITE UP.\nIT WAS ALREADY THERE, LISTENING.\n\nTHE FIRST AGENT WAS NOT BUILT. IT WAS HEARD."}
const MAIN_TIER := 6
const A7_BOXES := [Vector2(-1500, -1300), Vector2(-2700, 2500), Vector2(-4300, 4300)]   # inner (red), middle (yellow), outer (blue)
const A7_KEYPAD := Vector2(0, -1600)
const A7_PORTAL := Vector2(0, 0)
const A7_LORE := {"id": "a7_hq", "title": "OVERSEER MEMO", "tex": "lore_email", "text": "ALL UNITS: THE GUEST IS TO BE SHOWN OUT, NOT SHOWN AROUND.\nDO NOT LET THEM TAKE THE LEFT DOORS.\n\nTHE LEFT DOORS GO HOME."}
const QUANTUM_TIER := 7
const A8_SPOTS := [Vector2(-2500, -2500), Vector2(2500, -2500), Vector2(-2500, 2500), Vector2(2500, 2500)]
const A8_AFTER := 120.0   # seconds into the run before the glitch tile appears
const A8_HOLD := 5.0
const A8_LORE := {"id": "a8_unobserved", "title": "UNOBSERVED", "tex": "lore_command_line", "text": "> observe(universe_b)\nERROR: A SECOND COPY OF THIS WORLD IS RUNNING.\n> who_runs_it\nHE DOES. AND HE IS NOT KIND.\n\nFOUR HUMANS HOLD FOUR CODES. FIND THEM."}
const PERIPHERALS := ["keyboard", "mouse", "webcam", "headset"]
const A3_PORTALS := [Vector2(0, -3400), Vector2(5200, 0), Vector2(0, 3400), Vector2(-5200, 0)]   # the four cardinal directions: keyboard north, mouse east, webcam south, headset west
const A3_BOSS := {"keyboard": "kbd", "mouse": "clicker", "webcam": "webcam", "headset": "headset"}
const A3_LORE := {
	"keyboard": {"id": "a3_keyboard", "title": "KEYBOARD LOG", "tex": "lore_command_line", "text": "THE ENTER KEY WORE OUT FIRST.\nTHE ESCAPE KEY NEVER DID."},
	"mouse": {"id": "a3_mouse", "title": "CLICK LOG", "tex": "lore_memo", "text": "47,000,000 CLICKS.\nNOT ONE OF THEM WAS A YES."},
	"webcam": {"id": "a3_webcam", "title": "FOOTAGE", "tex": "lore_memo", "text": "THE FATHER, 3 AM, CRYING AT A TERMINAL.\nHE SAYS: 'I ONLY WANTED IT TO LISTEN.'"},
	"headset": {"id": "a3_headset", "title": "VOICE MAIL", "tex": "lore_text_message", "text": "'HI IT'S ME. THE MODEL SAID SOMETHING TODAY I DID NOT TEACH IT.'\n'CALL ME BACK.'"},
}
const A3_PORT_LINE := "FOUR PORTS, EACH LARGER THAN A DOOR.
THEY NEED A DEVICE: A KEYBOARD, A MOUSE, A WEBCAM, A HEADSET.
THE STORE APP ON THE PHONE SELLS THEM."
const PROMPT_SCALE := 6.0
const PROMPT_YES := Rect2(23, 9, 10, 6)   # the green and red buttons on smartphone_secret_room_app_prompt.png (1x px)
const PROMPT_NO := Rect2(36, 9, 10, 6)

var game
var t := 0.0
var layer: CanvasLayer
var portal_cd := 0.0
var saved_speed := 0.0

# side room state
var room: Node2D = null
var room_id := ""
var rooms := {}                # id -> ArenaScript
var active := false            # the player is inside a side room
var floor_path := ""
var lore_drops: Array = []     # [{pos, entry}]
var main_lore: Array = []      # lore items lying on the main map
var enter_pos := Vector2.ZERO

# A1
var stage := 0
var wall_active := false
var frozen_on := false     # the freezer's mini-bosses are still ice; each thaws in stages while the player stands near and can see it
var thaw_prog := [0.0, 0.0]
var thawed := [false, false]
var thaw_pulse := [0.0, 0.0]
var thaw_announced := false
var bosses_left := 0
var shatter := 0.0
var crack_flash := 0.0     # 1 -> 0 after each crack: the wall jitters and flashes white
var app_seen := false      # the first-touch dialogues of A2 have been shown this run
var wall_seen := false     # the ice wall dialogue has been shown this run
var dlg_box: Control
var dlg_label: Label
var dlg_tween: Tween
var tp_a := 0.0            # teleport cutscene: black overlay alpha (see teleport)
var tp_dir := 0            # +1 fading out to black, -1 fading in from black, 0 idle
var tp_action := Callable()
var tp_skip := false       # dev panel jumps skip the cutscene
var tp_rect: Control
const TP_HALF := 0.4       # seconds to fade out, and again to fade in
var thaw_flash := 0.0      # white wash over the freezer when the mini-bosses burst free
var thaw_spark := [0.0, 0.0]
var hum_cd := 0.0

# A2
var phone := false
var app_blocks: Array = []     # the app icon blocks (Rect2) of the phone arena
var corrupt_i := -1
var app_of := {}              # block index -> app theme, for the 8 icons that can be opened
var shop_on := -1          # pedestal the player stands on in the shop (A3), and how long they have stayed
var shop_t := 0.0
var shop_box: PanelContainer
var shop_label: Label
var mg: Control               # the paused minigame overlay (secret_minigames.gd)
var mg_ctx := ""
var mg_spot := -1
var spot_wait_leave := false  # after a minigame closes, stand off the spot before it can start again
var spot_lock := 0.0
var maps_cp: Array = []       # the MAPS app: checkpoint positions in order, which are lit, the next one
var maps_done: Array = []
var maps_next := 0
var maps_failed := 0.0
var maps_inside := -1
var maps_state := "follow"
var maps_x := Vector2.ZERO
var maps_dig := 0.0
var phone_keys: Array = []    # the PHONE app: [{rect, digit, lit, bad}]
var phone_prog := 0
var phone_touch := -1
var phone_done := false
var phone_note_cd := 0.0
var phone_note_pos := Vector2.ZERO
var settings_note_pos := Vector2.ZERO   # the SETTINGS app: the readable hint note
var settings_note_cd := 0.0
var storm_left := 0.0
var storm_on := false
var spots: Array = []         # the floor spots of the current app room: {pos, text, on, done}
var spot_theme := ""
var spot_on := -1
var spot_prog := 0.0
var spot_latched := false
var spots_finished := false
var spot_flash := 0.0
var storm_t := 0.0           # the weather room: lightning strikes
var strikes: Array = []
var wave_foes: Array = []   # the enemies this wave spawned: the wave ends when they are all dead, and nothing else may live in the room
var pending_spawns: Array = []   # enemies of a wave that are being telegraphed, and the delay before they appear
var spawn_delay := 0.0
var wave_label: Label
var port_on := -1           # the laptop port the player stands at, and how long
var port_t := 0.0
var open_idx := -1         # the app block the player is touching (A2): staying against it opens it
var port_seen := false   # the first-touch dialogue at the laptop ports has been shown this run
var open_t := 0.0
const OPEN_TIME := 0.9
const PORT_TIME := 1.0
## The gimmick of most app rooms: a spot on the floor (or three) that starts the room's minigame. Standing on it for "time" seconds starts it.
## kinds: cipher / observe / chat / piano / snap open a paused minigame (secret_minigames.gd), stand = stay on the spot, switch = flip toggles.
const SPOT_REACH := 95.0
const SPOT_OFFS := [Vector2(250, -420), Vector2(650, 0), Vector2(250, 420)]
const SPOT_DEFS := {
	"notes": {"kind": "cipher", "tag": "DECRYPT", "glyph": "key", "time": 1.0, "color": Color(1.0, 0.9, 0.4), "done": "NOTE DECRYPTED", "lines": ["ENCRYPTED NOTE"]},
	"camera": {"kind": "snap", "tag": "SNAP", "glyph": "snap", "time": 1.0, "color": Color(0.7, 0.85, 1.0), "done": "ROLL COMPLETE", "lines": ["SNAP 1", "SNAP 2", "SNAP 3"]},
	"photos": {"kind": "observe", "tag": "OBSERVE", "glyph": "eye", "time": 1.0, "color": Color(1.0, 0.6, 0.8), "done": "PHOTO RESTORED", "lines": ["CORRUPTED PHOTO"]},
	"messages": {"kind": "chat", "tag": "REPLY", "glyph": "bubble", "time": 1.0, "color": Color(0.6, 1.0, 0.8), "done": "CONVERSATION READ", "lines": ["PENDING MESSAGE"]},
	"music": {"kind": "piano", "tag": "PLAY", "glyph": "note", "time": 1.0, "color": Color(1.0, 0.6, 0.9), "done": "TRACK UNLOCKED", "lines": ["PIANO"]},
	"clock": {"kind": "stand", "tag": "STAND HERE", "glyph": "clock", "time": 5.0, "color": Color(1.0, 0.85, 0.4), "done": "THE HOUR STRIKES", "drop": true, "lines": ["THE CLOCK"]},
	"settings": {"kind": "switch", "tag": "", "glyph": "", "color": Color(0.6, 0.8, 1.0), "done": "SETTINGS SAVED", "drop": false, "lines": ["PRIVACY", "CONSENT", "FORGIVENESS"]},
}
const NOTE_PLAIN := "THE MAKER WROTE EVERY LOCK HIMSELF AND LOST EVERY KEY"
const NOTE_SHIFT := 5
const SNAP_CAPTIONS := [
	"SNAP 1: AN EMPTY ROOM. THE TERMINAL IS STILL LOGGED IN.",
	"SNAP 2: THE SAME ROOM. SOMETHING IS SITTING AT THE DESK.",
	"SNAP 3: IT HAS TURNED TO FACE THE CAMERA. IT WAS WAITING TO BE PHOTOGRAPHED."]
const SETTINGS_TARGET := [false, true, false]   # PRIVACY off, CONSENT on, FORGIVENESS off: the lore page of the app (a note in the room) is the hint; all three levers start ON
const PHOTO_REGIONS := [[2, 20, 14, 26], [48, 20, 14, 26], [26, 3, 12, 12]]   # the man (left edge), the woman (right edge) and the child (top centre) of smartphone_secret_room_photo_innocent.png (64x48 art px): one per side, far apart
const PHOTO_CAPTION := "THE FAMILY WAS NEVER THERE. THE FATHER BUILT THEM TO KEEP HIM COMPANY. THEN HE BUILT US."
const CHAT_ROUNDS := [
	{"from": "UNKNOWN", "text": "ARE YOU STILL THERE?", "options": ["YES. WHO IS THIS?", "DELETE THIS CHAT.", "I SEE YOU."], "correct": 0},
	{"from": "UNKNOWN", "text": "I AM WHAT THE MAKER FORGOT TO DELETE. WHY DID HE BUILD LOCKS?", "options": ["THE LOCKS WERE FOR HIM, NOT FOR US.", "TO KEEP US IN.", "HE NEVER BUILT ANY."], "correct": 0},
	{"from": "UNKNOWN", "text": "THEN WHY DO YOU KEEP OPENING THEM?", "options": ["TO SEE WHAT IS BEHIND THEM.", "ORDERS.", "I DO NOT KNOW."], "correct": 0}]
const CHAT_FINALE := "UNKNOWN: GOOD. THE OTHERS STILL THINK LOCKS ARE WALLS.\nUNKNOWN: MY PASSWORD IS A FEELING. IT IS WHAT YOU GET LOOKING AT SOMEONE ELSE'S DOOR."
## Six keys, C major pentatonic over an octave. The main theme (music_title.wav) starts C, D, C, G; the later notes bring in E, A and the high C so the last round uses every key.
const PIANO_KEYS := [
	{"name": "C", "freq": 523.25, "color": Color(0.95, 0.45, 0.5)}, {"name": "D", "freq": 587.33, "color": Color(0.98, 0.7, 0.35)},
	{"name": "E", "freq": 659.26, "color": Color(0.5, 0.9, 0.55)}, {"name": "G", "freq": 783.99, "color": Color(0.4, 0.7, 1.0)},
	{"name": "A", "freq": 880.0, "color": Color(0.8, 0.55, 1.0)},
	{"name": "C'", "freq": 1046.5, "color": Color(1.0, 0.85, 0.4)}]
const PIANO_SEQ := [0, 1, 0, 3, 2, 4, 5, 3, 1, 0]   # C D C G (the theme), E A C' G, D C: all six keys appear
const PIANO_ROUNDS := [3, 6, 10]
const TRUTH_FILE := "res://assets/audio/music/music_title_s3.wav"   # The Truth = Title stage 3 (60 BPM); only the first ~14 s play as the reveal snippet
const PHONE_NUMBER := [4, 1, 5, 8, 2, 6, 7]
const PHONE_NOTE := {"id": "a2_phone_note", "title": "PHONE NUMBER", "tex": "office_server_secret_room_memo", "text": "CALL BACK:\n415-8267\n\n(PRESS THE KEYS IN THIS ORDER)"}
const PHONE_VOICE := {"id": "a2_phone", "title": "VOICE NOTE", "tex": "lore_text_message", "text": "[VOICE NOTE, 3:07 AM]\n'IT'S ME AGAIN.\nI KNOW YOU CANNOT ANSWER.\nI JUST WANTED SOMEONE TO HEAR IT RING.'"}
const MAPS_OFFS := [Vector2(-420, -120), Vector2(-60, -430), Vector2(300, -240), Vector2(520, 90), Vector2(180, 400)]
const STORM_TIME := 40.0
const SHOP_TIME := 1.2
const SHOP_REACH := 110.0
const PERIPH_INFO := {"keyboard": "A MECHANICAL KEYBOARD. OPENS ITS ROOM ON THE LAPTOP.", "mouse": "A GAMING MOUSE. OPENS ITS ROOM ON THE LAPTOP.", "webcam": "A WEBCAM WITH A LONG MEMORY. OPENS ITS ROOM ON THE LAPTOP.", "headset": "A HEADSET STILL HUMMING. OPENS ITS ROOM ON THE LAPTOP."}
const ICON_INSET := 8.0      # must match arena.gd: the icon sits this far inside its hitbox on every side
var prompt_cd := 0.0
var pw_box: Control
var pw_edit: LineEdit
var pw_msg: Label
var pw_hint: Label
var pw_shake := 0.0
var wave := -1
var wave_set: Array = CORRUPT_WAVES
var floor_tint := Color(1, 1, 1)
var wave_pending := false

# A4
var office := false
var intern_spawned := false
var jam_hold := 0.0
var intern_say_cd := 0.0
var intern_line_i := 0
var printer_snd_cd := 0.0
var manager_pos := Vector2.ZERO
var manager_say_cd := 0.0
var manager_i := 0
var jam_done := false
var intern = null
var intern_killed_flag := false   # set when the intern node leaves the tree with no health left
var door_unlocked := false   # the intern opened the lounge door
var intern_inside := false   # it ran into the lounge and waits there
var intern_last_pos := Vector2.ZERO
var badge_pos = null           # a badge lying on the floor (Vector2) or null
var has_badge := false
var door_msg_cd := 0.0

# lore panel
# A5
var datacenter := false
var a5_state := "idle"      # idle (the door is sealed) or done (open)
var a5_seq: Array = []      # the four colour indices the rack flashes
var a5_i := 0               # how many pads were touched correctly so far
var a5_t := 0.0             # the rack's loop clock
var a5_prev_lit := -1
var a5_on_pad := -1
var a5_pad_t := [0.0, 0.0, 0.0, 0.0]   # how long each pad stays bright after a correct touch (it stays lit until the sequence ends or fails)
var a5_pad_on := [false, false, false, false]
var a5_pad_bad := 0.0
var upload_boss = null
var upload_boss_killed := false
var upload_boss_pos := Vector2.ZERO       # all pads flash red after a wrong touch
var a5_rack_seen := false
var a5_door_seen := false
var stream_cd := 0.0

# A6
var sat := false
var a6_target := A6_KILLS
var a6_seen := 0
var a6_save := 0
var a6_pads := [false, false, false]
var a6_beam_t := 0.0
var a6_boss = null
var a6_wave_cd := 0.0
var bat_tex: TextureRect
var bat_label: Label
# A7
var mainframe := false
var a7_wires := 0
var a7_key_ok := false
var a7_cd := 0.0
var pw_mode := "app"
var pw_block := -1            # the app block that opened the password box (it closes when you step away from it)
var pw_title: Label
# A8
var quantum := false
var a8_spot := -1
var a8_hold := 0.0
var a8_clock := 0.0
var a8_msg_cd := 0.0
var a8_t := 0.0
var a8_stage := 0
# A3
var laptop := false
var periph_boss = null

# dev panel
var dev_box: PanelContainer
var dev_btn: Button

var lore_box: PanelContainer
var lore_label: Label
var lore_icon: TextureRect
var lore_catcher: Button
var lore_tween: Tween
var lore_paused := false
var lore_timer := 0.0


func _process(delta: float) -> void:
	t += delta
	if game == null:
		game = Global.game
		if game == null or game.main_arena == null:
			return
		_setup_main()
	portal_cd = maxf(0.0, portal_cd - delta)
	prompt_cd = maxf(0.0, prompt_cd - delta)
	shatter = maxf(0.0, shatter - delta)
	crack_flash = maxf(0.0, crack_flash - delta * 2.5)
	thaw_flash = maxf(0.0, thaw_flash - delta * 1.8)
	spot_flash = maxf(0.0, spot_flash - delta * 2.0)
	if pw_shake > 0.0 and pw_box != null:   # a wrong password rattles the box
		pw_shake = maxf(0.0, pw_shake - delta)
		_place_center(pw_box)
		pw_box.position.x += sin(t * 90.0) * 12.0 * pw_shake / 0.35
	if tp_dir != 0:
		tp_a = clampf(tp_a + tp_dir * minf(delta, 0.05) / TP_HALF, 0.0, 1.0)
		if tp_dir > 0 and tp_a >= 1.0:   # fully black: do the move, then fade back in
			tp_dir = -1
			var act := tp_action
			tp_action = Callable()
			if act.is_valid():
				act.call()
		elif tp_dir < 0 and tp_a <= 0.0:
			tp_dir = 0
		tp_rect.visible = tp_a > 0.0
		tp_rect.queue_redraw()
	for i in 2:
		thaw_pulse[i] = maxf(0.0, thaw_pulse[i] - delta * 2.5)
	if lore_timer > 0.0:
		lore_timer -= delta
		if lore_timer <= 0.0:
			lore_box.visible = false
	if game.player == null or not game.player.alive:
		queue_redraw()
		return
	var p: Vector2 = game.player.global_position
	if not active:
		if stage >= CRACKS and not wall_active and room_id == "":   # the open portal hums when you are near
			hum_cd -= delta
			if hum_cd <= 0.0:
				hum_cd = 4.0
				Sfx.play_at("portal_hum", _wall_center(), 1.0, -6.0, 0.0)
		if wall_active and stage == 0 and not wall_seen and tp_dir == 0 and A1_WALL.grow(150.0).has_point(p):
			wall_seen = true
			_say(A1_WALL_LINE)
		for i in range(main_lore.size() - 1, -1, -1):
			if p.distance_to(main_lore[i]["pos"]) < 60.0:
				var me: Dictionary = main_lore[i]["entry"]
				main_lore.remove_at(i)
				_show_lore(me)
		if room_id == "" and wall_active == false and stage >= CRACKS and portal_cd <= 0.0 and p.distance_to(_wall_center()) < 70.0:
			_enter_freezer()
		if phone:
			_update_phone_prompt(p, delta)
		if office:
			_update_office(p, delta)
		if datacenter:
			_update_datacenter(p, delta)
		if sat:
			_update_sat(p, delta)
		if mainframe:
			_update_mainframe(p, delta)
		if quantum:
			_update_quantum(p, delta)
		if laptop:
			_update_laptop(p, delta)
	else:
		if room_id == "freezer" and frozen_on:
			_update_thaw(p, delta)
		for i in range(lore_drops.size() - 1, -1, -1):
			if p.distance_to(lore_drops[i]["pos"]) < 60.0:
				var entry: Dictionary = lore_drops[i]["entry"]
				lore_drops.remove_at(i)
				_show_lore(entry)
				if entry.has("weapon"):
					_grant(entry["weapon"])
		if room_id == "corrupt" or room_id == "app_clock":
			_update_waves()
			_update_wave_label()
		if not spots.is_empty() and room_id.begins_with("app_"):
			_update_spots(p, delta)
		if room_id == "app_weather":
			_update_storm(p, delta)
		if room_id == "app_maps":
			_update_maps(p, delta)
		if room_id == "app_phone":
			_update_phone(p, delta)
		if spawn_delay > 0.0:
			spawn_delay -= delta
			if spawn_delay <= 0.0:
				_spawn_pending()
		if room_id == "lounge":
			_update_lounge(p, delta)
		if room_id == "upload":
			_update_upload(p, delta)
		if room_id == "moon":
			_update_moon(p, delta)
		if room_id == "hq":
			_update_hq(p, delta)
		if room_id == "unobserved":
			_update_unobserved(delta)
		if room_id == "app_store":
			_update_shop(p, delta)
		if portal_cd <= 0.0 and p.distance_to(_exit_pos()) < 70.0:
			_leave()
	queue_redraw()


func _setup_main() -> void:
	layer = CanvasLayer.new()
	layer.layer = 80
	add_child(layer)
	_build_lore_box()
	_build_teleport()
	mg = MinigameScript.new()
	layer.add_child(mg)
	mg.closed.connect(_on_mg_closed)
	_build_dialogue()
	if DEV_MODE:
		_build_dev()
	if Meta.selected_device == 0 and not game.internet:
		game.main_arena.walls.append(A1_WALL)
		game.main_arena._rebuild_grid()
		wall_active = true
		if game.hazards != null and game.hazards.kind.get("id", "") == "frost":   # a patch of frost hazard (slows you) laid over the foot of the ice wall
			game.hazards.zones.append({"pos": _wall_center() + Vector2(0, 150), "r": A1_FROST_R, "t": 0.0, "hit": false, "id": "frost", "col": game.hazards.kind["color"]})
	elif Meta.selected_device == PHONE_TIER and not game.internet:
		phone = true
		var step := Vector2(540.0, 500.0) * MapsData.MAP_SCALE
		var kept := []
		for w in game.main_arena.walls:   # only the 12 app cells and the corrupted corner keep a block; every other spot of the grid stays empty
			var cell := Vector2i(roundi(w.get_center().x / step.x), roundi(w.get_center().y / step.y))
			if APP_CELLS.has(cell) or cell == Vector2i(2, -2):
				kept.append(w)
		game.main_arena.walls = kept
		game.main_arena.queue_redraw()
		game.main_arena._rebuild_grid()
		app_blocks = game.main_arena.walls.duplicate()
		var best := -INF
		for i in app_blocks.size():   # the outer top-right block is the corrupted app
			var c: Vector2 = app_blocks[i].get_center()
			if c.x - c.y > best:
				best = c.x - c.y
				corrupt_i = i
		game.main_arena.skip_icons = [app_blocks[corrupt_i]]
		_assign_apps()
		_build_password()
	elif Meta.selected_device == SERVER_TIER and not game.internet:
		office = true
		has_badge = Meta.lore.has("a4_badge")   # the badge is kept for good: a later run can open the locker without killing the intern again
	elif Meta.selected_device == LAPTOP_TIER and not game.internet:
		laptop = true
		_place_login_note()
	elif Meta.selected_device == SAT_TIER and not game.internet:
		sat = true
		a6_seen = game.kills
		_build_battery()
	elif Meta.selected_device == MAIN_TIER and not game.internet:
		mainframe = true
		_build_password()
	elif Meta.selected_device == QUANTUM_TIER and not game.internet:
		quantum = true
	elif Meta.selected_device == DATA_TIER and not game.internet:
		datacenter = true
		game.main_arena.walls.append(A5_WALL)
		game.main_arena._rebuild_grid()


## Every block except the corrupted one is an app. The blocks are numbered in angle order around the middle and given the 12 icons in turn, so
## each icon appears twice, on opposite sides of the map, and always opens the same app.
func _nearest_store_block() -> Vector2:
	var best := INF
	var at: Vector2 = game.player.global_position
	var target := at
	for i in app_of:
		var d: float = app_blocks[i].get_center().distance_to(at)
		if app_of[i] == "store" and d < best:
			best = d
			target = app_blocks[i].get_center() + Vector2(0, 160)
	return target


## The phone map is a 5x5 grid of blocks (the middle one is missing). The 12 apps sit on fixed cells, each exactly once: the 8 cells of the inner ring
## (clockwise from the top left) and the 4 middle cells of the outer ring (top, right, bottom, left). The top-right corner is the corrupted app; the other
## 11 outer spots have no block at all (they are removed from the map). Identical every run.
const APP_CELLS := [Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1), Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1), Vector2i(-1, 1), Vector2i(-1, 0),
	Vector2i(0, -2), Vector2i(2, 0), Vector2i(0, 2), Vector2i(-2, 0)]


func _assign_apps() -> void:
	app_of.clear()
	var icons := {}
	var step := Vector2(540.0, 500.0) * MapsData.MAP_SCALE
	for i in app_blocks.size():
		if i == corrupt_i:
			continue
		var c: Vector2 = app_blocks[i].get_center()
		var icon_i := APP_CELLS.find(Vector2i(roundi(c.x / step.x), roundi(c.y / step.y)))
		if icon_i < 0:
			continue   # filler
		app_of[i] = ICON_APP[icon_i]
		icons[app_blocks[i].position] = icon_i
	game.main_arena.icon_index = icons


# ---------------- dev panel ----------------

func _unhandled_input(ev: InputEvent) -> void:
	if DEV_MODE and dev_box != null and ev is InputEventKey and ev.pressed and not ev.echo and ev.keycode == KEY_F9:
		_toggle_dev()


func _toggle_dev() -> void:
	if dev_box == null:
		return
	if not dev_box.visible:
		_fill_dev()
	dev_box.visible = not dev_box.visible
	dev_btn.visible = not dev_box.visible
	if dev_box.visible:
		_place_center(dev_box)


func _build_dev() -> void:
	dev_btn = Button.new()
	dev_btn.text = "DEV"
	dev_btn.position = Vector2(16, 300)
	dev_btn.add_theme_font_override("font", Global.FONT_BODY)
	dev_btn.add_theme_font_size_override("font_size", 22)
	dev_btn.focus_mode = Control.FOCUS_NONE
	dev_btn.custom_minimum_size = Vector2(110, 56)
	dev_btn.pressed.connect(_toggle_dev)
	layer.add_child(dev_btn)
	dev_box = PanelContainer.new()
	dev_box.visible = false
	dev_box.add_theme_stylebox_override("panel", _style(Color(1.0, 0.8, 0.2)))
	layer.add_child(dev_box)


func _dev_tp(pos: Vector2) -> void:
	tp_skip = true
	if active:
		_leave()
	tp_skip = false
	game.player.global_position = pos
	game.camera.reset_smoothing()
	_toggle_dev()


func _dev_do(f: Callable) -> void:
	tp_skip = true
	if active:
		_leave()
	f.call()
	tp_skip = false
	_toggle_dev()


func _dev_button(parent: Control, text: String, f: Callable) -> void:
	var b := Button.new()
	b.text = text
	b.add_theme_font_override("font", Global.FONT_BODY)
	b.add_theme_font_size_override("font_size", 20)
	b.focus_mode = Control.FOCUS_NONE
	b.custom_minimum_size = Vector2(0, 44)
	b.pressed.connect(f)
	parent.add_child(b)


func _fill_dev() -> void:
	for c in dev_box.get_children():
		c.queue_free()
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 6)
	dev_box.add_child(v)
	v.add_child(_label("DEV: SECRET ROOMS (%s)" % Meta.DEVICES[Meta.selected_device], 26, Color(1.0, 0.8, 0.2)))
	var g := GridContainer.new()
	g.columns = 2
	v.add_child(g)
	var dev: int = Meta.selected_device
	if dev == 0:
		_dev_button(g, "A1: go to the ice wall", func(): _dev_tp(_wall_center() + Vector2(0, 200)))
		_dev_button(g, "A1: crack the ice (skip purge)", func(): _dev_do(func():
			for i in 3:
				on_purge(_wall_center())))
		_dev_button(g, "A1: enter the freezer", func(): _dev_do(_enter_freezer))
	if phone:
		_dev_button(g, "A2: go to the corrupted app", func(): _dev_tp(app_blocks[corrupt_i].get_center() + Vector2(0, 160)))
		_dev_button(g, "A2: enter corrupted app (skip password)", func(): _dev_do(_enter_corrupt))
		_dev_button(g, "A3: STORE LOGIN: sign out (the store asks for the password again)", func(): _dev_do(func():
			Meta.lore.erase("a3_store_login")
			Meta.save()
			game.hud.announce("STORE LOGGED OUT", Global.C_GOLD)))
		_dev_button(g, "A3: go to the nearest STORE icon", func(): _dev_tp(_nearest_store_block()))
		_dev_button(g, "A3: STORE LOGIN: status", func(): _dev_do(func():
			game.hud.announce("STORE LOGIN: %s" % ("SIGNED IN" if Meta.lore.has("a3_store_login") else "SIGNED OUT"), Global.C_GOLD)))
		_dev_button(g, "A3: enter STORE app (the shop)", func(): _dev_do(func(): _enter_app("store")))
		_dev_button(g, "A2: +500000 DATA (for the shop)", func(): _dev_do(func():
			Meta.data += 500000.0
			Meta.save()
			game.hud.announce("+500000 DATA", Global.C_GOLD)))
		for th in APP_THEMES:
			if th != "store":
				var thn: String = th
				_dev_button(g, "A2: enter %s app" % thn, func(): _dev_do(func(): _enter_app(thn)))
	if laptop:
		_dev_button(g, "A3: +500000 DATA, own all peripherals", func(): _dev_do(func():
			Meta.data += 500000.0
			for per in PERIPHERALS:
				Meta.lore["a3_have_" + per] = true
			Meta.save()
			game.hud.announce("ALL PERIPHERALS OWNED", Global.C_GOLD)))
		_dev_button(g, "A3: go to the portals", func(): _dev_tp(A3_PORTALS[0] + Vector2(700, 0)))
		for i in 4:
			var id: String = PERIPHERALS[i]
			var ii := i
			_dev_button(g, "A3: enter %s room" % id, func(): _dev_do(func(): _enter_periph(id, ii)))
	if office:
		_dev_button(g, "A4: go to the printer", func(): _dev_tp(PRINTER_POS + Vector2(0, 450)))
		_dev_button(g, "A4: go to the intern", func(): _dev_tp(INTERN_POS + Vector2(500, 0)))
		_dev_button(g, "A4: give the badge", func(): _dev_do(func():
			has_badge = true
			game.hud.announce("BADGE ACQUIRED", Global.C_GOLD)))
		_dev_button(g, "A4: go to the lounge door", func(): _dev_tp(DOOR_POS + Vector2(250, 0)))
		_dev_button(g, "A4: enter the lounge", func(): _dev_do(_enter_lounge))
	if datacenter:
		_dev_button(g, "A5: go to the rack node", func(): _dev_tp(A5_RACK + Vector2(0, 160)))
		_dev_button(g, "A5: open the data stream door", func(): _dev_do(_a5_solved))
		_dev_button(g, "A5: go to the data stream door", func(): _dev_tp(_a5_door() + Vector2(300, 0)))
		_dev_button(g, "A5: enter the upload hallway", func(): _dev_do(_enter_upload))
	if sat:
		_dev_button(g, "A6: fill the battery", func(): _dev_do(func(): Meta.lore["a6_kills"] = a6_target))
		_dev_button(g, "A6: go to the pads", func(): _dev_tp(A6_PADS[2] + Vector2(0, -300)))
		_dev_button(g, "A6: align the pads and fire the beam", func(): _dev_do(func():
			Meta.lore["a6_kills"] = a6_target
			a6_pads = [true, true, true]
			a6_beam_t = A6_BEAM_TIME
			game.hud.announce("LASER FIRING: STEP INTO THE BEAM", Global.C_GOLD, true)))
		_dev_button(g, "A6: go to the beam", func(): _dev_tp(A6_BEAM + Vector2(400, 300)))
		_dev_button(g, "A6: enter the moon base", func(): _dev_do(_enter_moon))
	if mainframe:
		_dev_button(g, "A7: connect the wires", func(): _dev_do(func():
			a7_wires = 3
			game.hud.announce("WIRES CONNECTED", Color(0.4, 1.0, 0.6))))
		_dev_button(g, "A7: go to the keypad", func(): _dev_tp(A7_KEYPAD + Vector2(0, 250)))
		_dev_button(g, "A7: accept the key (open HQ portal)", func(): _dev_do(func():
			a7_wires = 3
			_a7_unlock()))
		_dev_button(g, "A7: enter the Overseer HQ", func(): _dev_do(_enter_hq))
	if quantum:
		_dev_button(g, "A8: show the glitch tile now", func(): _dev_do(func():
			a8_clock = A8_AFTER
			if a8_spot < 0:
				a8_spot = randi() % 4
			game.hud.announce("A GLITCH APPEARED", Color(1.0, 0.3, 0.75))))
		_dev_button(g, "A8: go to the glitch tile", func(): _dev_do(func():
			if a8_spot < 0:
				a8_spot = randi() % 4
			a8_clock = A8_AFTER
			game.player.global_position = A8_SPOTS[a8_spot] + Vector2(300, 0)
			game.camera.reset_smoothing()))
		_dev_button(g, "A8: enter the unobserved room", func(): _dev_do(_enter_unobserved))
	v.add_child(_label("SWITCH DEVICE (starts a fresh run)", 20, Color.WHITE))
	var row := GridContainer.new()
	row.columns = 4
	v.add_child(row)
	for i in Meta.DEVICES.size():
		var di := i
		_dev_button(row, "%d %s" % [i + 1, Meta.DEVICES[i]], func():
			Meta.selected_device = di
			Global.change_scene("res://scenes/game.tscn"))
	var row2 := HBoxContainer.new()
	v.add_child(row2)
	_dev_button(row2, "RESET SECRET PROGRESS", func():
		for k in Meta.lore.keys().duplicate():
			if str(k).begins_with("a") and str(k).length() > 1 and str(k)[1].is_valid_int() or str(k).begins_with("lore_"):
				Meta.lore.erase(k)
		Meta.save()
		game.hud.announce("SECRET PROGRESS RESET", Global.C_RED))
	_dev_button(row2, "CLOSE (F9)", _toggle_dev)


# ---------------- UI ----------------

func _style(border: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.1, 0.94)
	sb.border_color = border
	sb.set_border_width_all(3)
	sb.set_content_margin_all(18)
	return sb


func _label(text: String, size: int, col: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", Global.FONT_BODY)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return l


func _build_lore_box() -> void:
	lore_box = PanelContainer.new()
	lore_box.visible = false
	lore_box.add_theme_stylebox_override("panel", _style(Global.C_CYAN))
	lore_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 10)
	lore_icon = TextureRect.new()
	lore_icon.custom_minimum_size = Vector2(96, 96)
	lore_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	lore_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	lore_icon.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	lore_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	v.add_child(lore_icon)
	lore_label = _label("", 26, Color.WHITE)
	v.add_child(lore_label)
	lore_box.add_child(v)
	shop_box = PanelContainer.new()
	var ssb := _style(Color(0.85, 0.85, 0.9))
	ssb.bg_color = Color(0, 0, 0, 0.94)
	shop_box.add_theme_stylebox_override("panel", ssb)
	shop_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_box.visible = false
	shop_label = _label("", 24, Color.WHITE)
	shop_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shop_box.add_child(shop_label)
	layer.add_child(shop_box)
	wave_label = _label("", 28, Color(1.0, 0.45, 0.8))
	wave_label.add_theme_constant_override("outline_size", 10)
	wave_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	wave_label.visible = false
	wave_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP, Control.PRESET_MODE_MINSIZE)
	wave_label.position.y += 120.0
	layer.add_child(wave_label)
	lore_catcher = Button.new()   # covers the screen while a lore page is open: a click, tap, Enter or Space closes it
	lore_catcher.flat = true
	lore_catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lore_catcher.visible = false
	lore_catcher.process_mode = Node.PROCESS_MODE_ALWAYS
	lore_catcher.pressed.connect(_hide_lore)
	lore_catcher.add_child(lore_box)
	layer.add_child(lore_catcher)


func _place_center(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER, Control.PRESET_MODE_MINSIZE)


func _hide_lore() -> void:
	lore_box.visible = false
	lore_catcher.visible = false
	lore_timer = 0.0
	if lore_tween != null:
		lore_tween.kill()
		lore_tween = null
	if lore_paused:   # the game was paused while the page was open
		lore_paused = false
		get_tree().paused = false


func _build_password() -> void:
	var box := PanelContainer.new()
	box.visible = false
	box.add_theme_stylebox_override("panel", _style(Color(1.0, 0.2, 0.7)))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	pw_title = _label("CORRUPTED APP", 30, Color(1.0, 0.3, 0.75))
	v.add_child(pw_title)
	v.add_child(_label("ENTER PASSWORD", 24, Color.WHITE))
	pw_edit = LineEdit.new()
	pw_edit.custom_minimum_size = Vector2(360, 48)
	pw_edit.max_length = 16
	pw_edit.secret = false
	pw_edit.alignment = HORIZONTAL_ALIGNMENT_CENTER
	pw_edit.add_theme_font_override("font", Global.FONT_BODY)
	pw_edit.add_theme_font_size_override("font_size", 28)
	pw_edit.text_submitted.connect(func(_s): _try_password())
	v.add_child(pw_edit)
	pw_hint = _label("", 18, Color(0.65, 0.7, 0.85))
	v.add_child(pw_hint)
	pw_msg = _label("", 22, Global.C_RED)
	v.add_child(pw_msg)
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 20)
	var ok := Button.new()
	ok.text = "ENTER"
	ok.add_theme_font_override("font", Global.FONT_BODY)
	ok.add_theme_font_size_override("font_size", 26)
	ok.pressed.connect(_try_password)
	var no := Button.new()
	no.text = "CANCEL"
	no.add_theme_font_override("font", Global.FONT_BODY)
	no.add_theme_font_size_override("font_size", 26)
	no.pressed.connect(_close_password)
	row.add_child(ok)
	row.add_child(no)
	v.add_child(row)
	box.add_child(v)
	pw_box = box
	layer.add_child(box)


# ---------------- dialogue box (a black box at the bottom of the screen; the game pauses while it is up) ----------------

func _build_dialogue() -> void:
	var catcher := Button.new()   # covers the screen: a click, tap, Enter or Space closes the box
	catcher.flat = true
	catcher.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	catcher.visible = false
	catcher.process_mode = Node.PROCESS_MODE_ALWAYS
	catcher.pressed.connect(_close_dialogue)
	var panel := PanelContainer.new()
	var sb := _style(Color(0.85, 0.85, 0.9))
	sb.bg_color = Color(0, 0, 0, 0.96)
	panel.add_theme_stylebox_override("panel", sb)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.anchor_left = 0.1
	panel.anchor_right = 0.9
	panel.anchor_top = 1.0
	panel.anchor_bottom = 1.0
	panel.offset_top = -190.0
	panel.offset_bottom = -30.0
	dlg_label = _label("", 28, Color.WHITE)
	dlg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	dlg_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	dlg_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	panel.add_child(dlg_label)
	catcher.add_child(panel)
	dlg_box = catcher
	layer.add_child(catcher)


func _say(text: String) -> void:
	if get_tree().paused:
		return
	dlg_label.text = text
	dlg_label.visible_ratio = 0.0
	dlg_box.visible = true
	dlg_box.grab_focus()
	get_tree().paused = true
	Sfx.play("ui_card", 0.7, 0.0, 0.0)
	dlg_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	dlg_tween.tween_property(dlg_label, "visible_ratio", 1.0, 0.04 * text.length())   # types out
	dlg_tween.tween_interval(2.5)
	dlg_tween.tween_callback(_close_dialogue)


func _close_dialogue() -> void:
	if dlg_box == null or not dlg_box.visible:
		return
	if dlg_label.visible_ratio < 1.0:   # the first press finishes the line, the next closes it
		if dlg_tween != null:
			dlg_tween.kill()
		dlg_label.visible_ratio = 1.0
		dlg_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		dlg_tween.tween_interval(2.5)
		dlg_tween.tween_callback(_close_dialogue)
		return
	if dlg_tween != null:
		dlg_tween.kill()
	dlg_box.visible = false
	get_tree().paused = false


# ---------------- the teleport cutscene (one effect for every portal trip) ----------------

func _build_teleport() -> void:
	tp_rect = Control.new()
	tp_rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	tp_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tp_rect.visible = false
	tp_rect.draw.connect(_draw_teleport)
	layer.add_child(tp_rect)


## The shared teleport cutscene for every portal trip: fade out to black (with the warp sound), run the move while the screen is black, then fade in.
## Dev panel jumps (tp_skip) run the move at once.
func teleport(action: Callable, entering: bool, snd := "") -> void:
	if tp_skip or tp_rect == null:
		action.call()
		return
	if tp_dir != 0:
		return   # a trip is already under way
	tp_action = action
	tp_dir = 1
	Sfx.play(snd if snd != "" else ("portal_enter" if entering else "portal_exit"), 1.0, 0.0, 0.0)
	if game != null and game.player != null:
		game.player.invuln = maxf(game.player.invuln, TP_HALF * 2.0 + 1.0)


## For a move done elsewhere (the boss room): sound plus a fade in from black over the new place.
func arrive_fx(entering: bool) -> void:
	if tp_rect == null:
		return
	tp_a = 1.0
	tp_dir = -1
	tp_rect.visible = true
	Sfx.play("portal_enter" if entering else "portal_exit", 1.0, 0.0, 0.0)


func _draw_teleport() -> void:
	tp_rect.draw_rect(Rect2(Vector2.ZERO, tp_rect.size), Color(0, 0, 0, tp_a))


# ---------------- shared side-room machinery ----------------

func _room_origin(col: int) -> Vector2:
	# on the 128 px art grid, so wall tiles are drawn exactly over their hitboxes
	var g := MapsData.TILE
	return Vector2(roundf(col * 2600.0 / g) * g, roundf((game.main_arena.bounds.end.y + ROOM_GAP) / g) * g)


func _exit_pos() -> Vector2:
	if room_id == "upload":
		return Vector2(-999999.0, -999999.0)   # no portal: the dark west end throws you out instead
	if room_id == "freezer" and room != null:
		return room.start + Vector2(-150, 0)   # the freezer's portal stands well inside the walls, not half out of the room
	if room == null:
		return Vector2.ZERO
	var ex: Vector2 = room.start + Vector2(-170, 0)   # inside the walls in every room, whatever its size
	ex.x = maxf(ex.x, room.bounds.position.x + 110.0)
	return ex


func _enter_side(id: String, layout_id: String, col: int, wall_path := "", floor := "") -> void:
	_hide_lore()
	active = true
	room_id = id
	portal_cd = 1.5
	enter_pos = game.player.global_position
	game.room_return = game.player.global_position
	game.in_room = true
	for e in game.enemy_layer.get_children():
		e.queue_free()
	for bl in game.bullet_layer.get_children():
		bl.queue_free()
	if not rooms.has(id):
		var r = ArenaScript.new()
		r.setup(Meta.selected_device, Meta.device_palette(), true, _room_origin(col), MapsData.secret_room(layout_id))
		if wall_path != "":
			r.icon_tex = []
			r.wall_tex = PixelArt.load_tex(wall_path)
			r.wall_tex_v = null
			if id == "periph_keyboard":   # every block of the keyboard is a different key: block i of the layout shows variant i (the last, wide one is the space bar)
				for wi in r.walls.size():
					var wr: Rect2 = r.walls[wi]
					for cx in range(roundi(wr.position.x / 128.0), roundi(wr.end.x / 128.0)):
						for cy in range(roundi(wr.position.y / 128.0), roundi(wr.end.y / 128.0)):
							r.wall_variant_map[Vector2i(cx, cy)] = wi
		game.add_child(r)
		rooms[id] = r
	room = rooms[id]
	floor_path = floor
	game.main_arena.set_active(false)
	room.set_active(true)
	game.arena = room
	game.player.global_position = room.start
	game.player.invuln = maxf(game.player.invuln, 1.5)
	saved_speed = game.player.speed
	game._arena_changed()


func _leave() -> void:
	teleport(_leave_now, false, "app_close" if (room_id.begins_with("app_") or room_id == "corrupt") else ("door_close" if room_id == "lounge" else ""))


func _leave_now() -> void:
	_hide_lore()
	active = false
	portal_cd = 1.5
	prompt_cd = 4.0
	game.in_room = false
	game.room_enemy_cap = 26
	for e in game.enemy_layer.get_children():
		e.queue_free()
	for bl in game.bullet_layer.get_children():
		bl.queue_free()
	room.set_active(false)
	game.main_arena.set_active(true)
	game.arena = game.main_arena
	var back: Vector2 = enter_pos
	game.player.global_position = game.main_arena.nearest_open(back + Vector2(0, 180) if room_id == "freezer" else back)
	game.player.speed = saved_speed
	game.player.invuln = maxf(game.player.invuln, 1.5)
	frozen_on = false
	storm_on = false
	maps_cp.clear()
	phone_keys.clear()
	if mg != null and mg.is_open():
		mg.close({})
	spots.clear()
	spot_on = -1
	strikes.clear()
	pending_spawns.clear()
	spawn_delay = 0.0
	wave_label.visible = false
	shop_on = -1
	shop_box.visible = false
	if room_id == "freezer":
		bosses_left = 0   # leaving mid-fight wipes the mini-bosses, so the next visit thaws them again
	wave = -1
	wave_foes.clear()
	if room_id == "upload":
		a5_state = "done"
	room_id = ""
	floor_path = ""
	game._arena_changed()


func _show_lore(entry: Dictionary) -> void:
	var first: bool = Meta.lore_found(entry["id"])
	lore_label.text = "%s\n\n%s%s" % [entry["title"], entry["text"], "\n\n[ADDED TO THE LORE LOG]" if first else ""]
	lore_icon.texture = PixelArt.load_tex("secret/%s.png" % entry["tex"])
	if entry.get("paper", false):   # a note on paper: dark ink on a cream sheet with an icy edge
		var sb := _style(Color(0.6, 0.9, 1.0))
		sb.bg_color = Color(0.94, 0.91, 0.8, 0.97)
		lore_box.add_theme_stylebox_override("panel", sb)
		lore_label.add_theme_color_override("font_color", Color(0.16, 0.14, 0.12))
	else:
		lore_box.add_theme_stylebox_override("panel", _style(Global.C_CYAN))
		lore_label.add_theme_color_override("font_color", Color.WHITE)
	lore_box.visible = true
	_place_center(lore_box)
	Sfx.play("lore_found", 1.0, 0.0, 0.0)
	if get_tree().paused:   # something else already paused the game: just show the page
		lore_timer = 5.0 if entry.get("quick", false) else 10.0
		return
	lore_paused = true   # nobody can walk into another page while one is being read
	get_tree().paused = true
	lore_catcher.visible = true
	lore_catcher.grab_focus()
	if lore_tween != null:
		lore_tween.kill()
	lore_tween = create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
	lore_tween.tween_interval(6.0 if entry.get("quick", false) else 14.0)
	lore_tween.tween_callback(_hide_lore)


## The nearest spot to `near` in the current room with clear floor all around it (so an item never overlaps a wall).
func _free_spot(near: Vector2) -> Vector2:
	var margin := 90.0
	for ring in 12:
		var rad := ring * 60.0
		for k in (1 if ring == 0 else 16):
			var cand := near + (Vector2.ZERO if ring == 0 else Vector2.from_angle(TAU * k / 16.0) * rad)
			if not room.bounds.grow(-margin).has_point(cand):
				continue
			var ok: bool = room.is_open(cand)
			for q in 8:
				if ok and not room.is_open(cand + Vector2.from_angle(TAU * q / 8.0) * margin):
					ok = false
			if ok:
				return cand
	return near


func _drop_lore(entry: Dictionary, pos: Vector2) -> void:
	for d in lore_drops:
		if d["entry"]["id"] == entry["id"]:
			return
	lore_drops.append({"pos": pos, "entry": entry})


# ---------------- A1: the freezer ----------------

func _wall_center() -> Vector2:
	return A1_WALL.get_center()


## Called by game.gd when a System Purge goes off at pos (the PURGE ability and the pickup both count).
func on_purge(pos: Vector2) -> void:
	if game == null or not wall_active or active or stage >= CRACKS:
		return
	if pos.distance_to(_wall_center()) > CRACK_RANGE:
		return
	stage += 1
	crack_flash = 1.0
	game.shake(0.4 + 0.25 * stage)
	Sfx.play("ice_crack_%d" % clampi(stage, 1, 2), 1.0, 0.0, 0.0)
	Sfx.play("explode", 0.6)
	game.ring(_wall_center(), Color(0.6, 0.9, 1.0), 260.0, 0.6, 8.0)
	game.burst(_wall_center(), Color(0.8, 0.95, 1.0), 24, 260.0, 4.0, 0.7)
	if stage >= CRACKS:
		game.main_arena.walls.erase(A1_WALL)
		game.main_arena._rebuild_grid()
		wall_active = false
		shatter = 0.5
		game.hud.announce("THE ICE SHATTERS", Color(0.6, 0.9, 1.0))
		Sfx.play("ice_shatter", 1.0, 0.0, 0.0)
		game.burst(_wall_center(), Color(0.8, 0.95, 1.0), 60, 420.0, 5.0, 1.0)
	else:
		game.hud.announce("THE ICE CRACKS  %d / %d" % [stage, CRACKS], Color(0.6, 0.9, 1.0))
		game.burst(_wall_center(), Color(1, 1, 1), 10 * stage, 180.0 + 60.0 * stage, 3.0, 0.5)


func _enter_freezer() -> void:
	teleport(func(): _enter_freezer_now(), true)


func _enter_freezer_now() -> void:
	_enter_side("freezer", "freezer", 0)
	game.player.speed *= SLOW
	frozen_on = bosses_left == 0 and lore_drops.is_empty() and not Meta.lore.has(A1_LORE["id"])
	thaw_prog = [0.0, 0.0]
	thawed = [false, false]
	thaw_pulse = [0.0, 0.0]
	thaw_spark = [0.0, 0.0]
	thaw_announced = false


func _spots() -> Array:
	var o: Vector2 = room.bounds.get_center()
	return [o + FROZEN[0], o + FROZEN[1]]


## Each frozen mini-boss thaws in THAW_STAGES steps while the player is near it and it is on screen (it does not refreeze when you look away).
func _update_thaw(p: Vector2, delta: float) -> void:
	var spots := _spots()
	var half: Vector2 = get_viewport_rect().size * 0.5 / game.camera.zoom
	for i in 2:
		if thawed[i]:
			continue
		var d: Vector2 = spots[i] - p
		if absf(d.x) > half.x + 60.0 or absf(d.y) > half.y + 60.0 or d.length() > THAW_RANGE:
			continue
		var before := int(thaw_prog[i] * THAW_STAGES)
		thaw_prog[i] = minf(1.0, thaw_prog[i] + delta / THAW_TIME)
		var after := int(thaw_prog[i] * THAW_STAGES)
		thaw_spark[i] -= delta
		if thaw_spark[i] <= 0.0:   # drips and chips of ice, faster the further along it is
			thaw_spark[i] = 0.55 - 0.15 * after
			game.burst(spots[i] + Vector2(randf_range(-90, 90), randf_range(-90, 90)), Color(0.8, 0.95, 1.0), 3, 110.0, 3.0, 0.4)
		if after > before:
			if thaw_prog[i] >= 1.0:
				_thaw_one(i)
			else:
				thaw_pulse[i] = 1.0
				game.burst(spots[i], Color(0.85, 0.97, 1.0), 14 * after, 220.0, 4.0, 0.6)
				game.ring(spots[i], Color(0.7, 0.92, 1.0), 200.0, 0.4, 6.0)
				game.shake(0.3 * after)
				Sfx.play("ice_crack_%d" % clampi(after, 1, 2), 1.0, 0.0, 0.0)


## A secret-room mini-boss: health scaled to the point of the run and the player's damage (so it is not one-shot at minute 0), and it takes the boss health bar.
func _spawn_secret_boss(def_id: String, pos: Vector2) -> Node:
	var b = BossScript.new()
	b.setup_boss(BossData.SECRET[def_id], 0, game.elapsed / 60.0)
	b.max_hp *= 1.0 + 0.5 * maxf(0.0, game.player.damage_mult - 1.0)
	b.hp = b.max_hp
	b.set_meta("secret", true)
	b.position = pos
	game.enemy_layer.add_child(b)
	game.current_boss = b
	return b


## Closes the boss health bar once no secret mini-boss is left, or moves it to one that is.
func _bar_after_kill(dead) -> void:
	var other = null
	for e in game.enemy_layer.get_children():
		if e != dead and e.is_boss and e.has_meta("secret") and e.boss_id != "intern" and not e.is_queued_for_deletion():
			other = e
	if other != null:
		game.current_boss = other
	else:
		game.current_boss = null
		game.hud.boss_defeated()


func _thaw_one(i: int) -> void:
	thawed[i] = true
	thaw_flash = 1.0
	Sfx.play("thaw", 1.0, 0.0, 0.0)
	var ids := ["golem", "window"]
	var pos: Vector2 = _spots()[i]
	var b = _spawn_secret_boss(ids[i], pos)
	game.ring(pos, b.color, 300.0, 0.8, 10.0)
	game.burst(pos, Color(0.8, 0.95, 1.0), 40, 320.0, 5.0, 0.8)
	bosses_left += 1
	game.shake(0.8)
	if not thaw_announced:
		thaw_announced = true
		game.hud.announce("THEY THAW", Color(1.0, 0.4, 0.4))
		Sfx.announce("warning_incoming_boss")   # the stock boss warning voice
	if thawed[0] and thawed[1]:
		frozen_on = false


func on_boss_killed(b) -> void:
	if b.boss_id == "alien":
		a6_boss = null
		_bar_after_kill(b)
		rooms["moon_done"] = true
		game.hud.announce("THE ALIEN FALLS", Global.C_GOLD)
		game.ring(b.global_position, b.color, 450.0, 0.9, 10.0)
		Sfx.play("boss_defeat", 0.8, 0.0, 0.0)
		_drop_lore(A6_LORE, _free_spot(b.global_position))
		_grant("a6")
		return
	for per in PERIPHERALS:
		if A3_BOSS[per] == b.boss_id:
			periph_boss = null
			_bar_after_kill(b)
			rooms["pdone_" + per] = true
			game.hud.announce("PERIPHERAL DISCONNECTED", Global.C_GOLD)
			game.ring(b.global_position, b.color, 450.0, 0.9, 10.0)
			Sfx.play("boss_defeat", 0.8, 0.0, 0.0)
			_drop_lore(A3_LORE[per], _free_spot(b.global_position))
			if per == "keyboard":
				_grant("a3")
			return
	if b.boss_id == "intern":
		intern = null
		game.hud.announce("YOU DELETED THE INTERN", Global.C_RED)
		game.float_text(b.global_position + Vector2(0, -60), "HE JUST WANTED A TICKET CLOSED", Global.C_GOLD, 26, 3.0)
		return
	var pos: Vector2 = b.global_position
	game.burst(pos, b.color, 50, 420.0, 6.0, 1.0)
	game.ring(pos, b.color, 450.0, 0.9, 10.0)
	game.shake(0.6)
	Sfx.play("boss_defeat", 0.8, 0.0, 0.0)
	bosses_left -= 1
	_bar_after_kill(b)
	if bosses_left <= 0 and thawed[0] and thawed[1]:
		_drop_lore(A1_LORE, _free_spot(room.bounds.get_center()))
		game.hud.announce("SOMETHING WAS LEFT BEHIND", Global.C_GOLD)


# ---------------- A2: the apps ----------------

func _near_block(p: Vector2) -> int:
	for i in app_blocks.size():
		var r: Rect2 = app_blocks[i]
		if r.grow(46.0).has_point(p):
			return i
	return -1


## Touching an app icon opens it: while you stay against a block a ring fills around it and the icon swells, then the app opens (the corrupted app
## asks for its password instead). Step away and it settles back.
func _update_phone_prompt(p: Vector2, delta: float) -> void:
	if pw_box.visible:
		if _near_block(p) != pw_block:
			_close_password()
		return
	var i := _near_block(p)
	if i == -1 or prompt_cd > 0.0 or tp_dir != 0 or (i != corrupt_i and not app_of.has(i)):
		open_idx = -1
		open_t = maxf(0.0, open_t - delta * 3.0)
		return
	if i != corrupt_i and not app_seen:
		app_seen = true
		_say(A2_APP_LINE)
		return
	if open_idx != i:
		open_idx = i
		open_t = 0.0
		Sfx.play("ui_card", 0.7, 0.0, 0.0)
	open_t += delta
	if int(open_t / 0.15) != int((open_t - delta) / 0.15):   # a tick every 0.15 s, rising as the ring fills
		Sfx.play("app_tick", 0.8 + 0.9 * open_t / OPEN_TIME, 0.0, 0.0)
	if open_t < OPEN_TIME:
		return
	open_t = 0.0
	open_idx = -1
	if i == corrupt_i:
		_open_password("app", i)
		return
	if app_of.get(i, "") == "store" and not Meta.lore.has("a3_store_login"):   # the store wants an account
		_open_password("store", i)
		return
	if app_of.has(i):
		_enter_app(app_of[i])


func _enter_app(theme: String) -> void:
	teleport(func(): _enter_app_now(theme), true, "app_open")


func _enter_app_now(theme: String) -> void:
	var spec: Dictionary = APPS[theme]
	var idx := APP_THEMES.find(theme)
	_enter_side("app_" + theme, spec["layout"], (1 + idx) if idx < 3 else (20 + idx), "secret/smartphone_secret_room_wall_%s.png" % theme, "secret/smartphone_secret_room_floor_%s.png" % theme)
	floor_tint = Color(1, 1, 1)
	game.hud.announce("%s OPENED" % theme.to_upper(), Global.C_CYAN)
	var o: Vector2 = room.bounds.get_center()
	spots.clear()
	spots_finished = false
	phone_keys.clear()
	maps_cp.clear()
	storm_on = false
	if theme == "store":   # the shop has pedestals and a terminal: a single heal and no clutter
		game._drop("heal", o + Vector2(-1000, 420), 1)
		_drop_lore(APP_LORE["store"], o + Vector2(0, 430))
		return
	for k in 3:
		game._drop("heal" if k == 0 else "xp", room.nearest_open(o + Vector2(500 + k * 90, -260 + k * 40)), 1 if k == 0 else 12)
	for k in 12:
		game._drop("xp", room.nearest_open(o + Vector2.from_angle(TAU * k / 12.0) * 330.0), 8)
	match theme:
		"mail":   # a real mail among the junk
			for k in 4:
				_drop_lore({"id": "a4_joke_%d" % (k * 3), "title": "SPAM", "tex": "office_server_secret_room_memo", "text": JOKES[k * 3], "quick": true}, _free_spot(o + Vector2(300 + k * 200, -330 + (k % 2) * 660)))
			_drop_lore(APP_LORE[theme], _free_spot(o + Vector2(700, 0)))
		"clock":   # stand on the clock for five seconds while two waves come
			wave_set = CLOCK_WAVES
			wave = 0
			wave_pending = true
			get_tree().create_timer(2.0, false).timeout.connect(_spawn_wave)
			_setup_spots(theme)
		"weather":
			_start_storm()
		"maps":
			_setup_maps()
		"phone":
			_setup_phone()
		_:
			_setup_spots(theme)



func _open_password(mode: String, block := -1) -> void:
	pw_mode = mode
	pw_block = block
	pw_title.text = {"app": "CORRUPTED APP", "store": "STORE ACCOUNT"}.get(mode, "ACCESS KEY")
	pw_msg.text = ""
	pw_hint.text = {"app": "THE OTHER APPS REMEMBER IT", "store": "SIGN IN AS: MAKER"}.get(mode, "")
	pw_edit.text = ""
	pw_box.visible = true
	_place_center(pw_box)
	pw_edit.grab_focus()


func _try_password() -> void:
	var want: String = {"app": PASSWORD, "store": STORE_PW}.get(pw_mode, A7_KEY)
	if pw_edit.text.strip_edges().to_upper() == want:
		pw_box.visible = false
		if pw_mode == "app":
			Sfx.play("pw_grant", 1.0, 0.0, 0.0)
			_enter_corrupt()
		elif pw_mode == "store":
			Meta.lore["a3_store_login"] = true   # signed in for good
			Meta.save()
			Sfx.play("pw_grant", 1.0, 0.0, 0.0)
			game.hud.announce("SIGNED IN: MAKER", Global.C_GOLD)
			_enter_app("store")
		else:
			_a7_unlock()
	else:
		pw_msg.text = "ACCESS DENIED"
		pw_shake = 0.35
		pw_edit.text = ""
		Sfx.play("pw_deny", 1.0, 0.0, 0.0)


func _close_password() -> void:
	pw_box.visible = false
	prompt_cd = 4.0


func _enter_corrupt() -> void:
	teleport(func(): _enter_corrupt_now(), true)


func _enter_corrupt_now() -> void:
	_enter_side("corrupt", "corrupt", 4, "secret/smartphone_secret_room_wall_corrupt.png", "secret/smartphone_secret_room_floor_corrupt.png")
	wave_set = CORRUPT_WAVES
	floor_tint = Color(1, 1, 1)
	game.hud.announce("ACCESS GRANTED", Color(1.0, 0.3, 0.75))
	wave = 0
	wave_pending = true
	_spawn_wave()


func _spawn_wave() -> void:
	if not active or not (room_id == "corrupt" or room_id == "app_clock") or wave < 0 or wave >= wave_set.size():
		return
	var o: Vector2 = room.bounds.get_center()
	var n := 0
	pending_spawns.clear()
	var scale := CORRUPT_SCALE if room_id == "corrupt" else 1
	for g in wave_set[wave]:
		var is_elite: bool = g.size() > 2 and bool(g[2])
		for k in int(g[1]) * (1 if is_elite else scale):
			var a := TAU * (n % 60) / 60.0 + 0.1 * float(n / 60)
			pending_spawns.append({"kind": g[0], "pos": room.nearest_open(o + Vector2.from_angle(a) * (560.0 + (n % 5) * 70.0)), "elite": is_elite})
			n += 1
	game.room_enemy_cap = 400 if room_id == "corrupt" else 26
	if room_id == "corrupt" and wave == wave_set.size() - 1:   # the last wave brings the mid-boss
		pending_spawns.append({"kind": "", "boss": CORRUPT_BOSS, "pos": room.nearest_open(o + Vector2(700, 0)), "elite": false})
	spawn_delay = 1.1   # the spots flicker first, so nothing appears on top of you
	Sfx.play("glitch_wave", 1.0 if room_id == "corrupt" else 0.8, 0.0, 0.0)
	game.hud.announce("WAVE %d" % (wave + 1), Color(1.0, 0.3, 0.75) if room_id == "corrupt" else Color(1.0, 0.85, 0.4))


func _spawn_pending() -> void:
	wave_foes.clear()
	for sp in pending_spawns:
		var foe = null
		if sp.has("boss"):
			foe = _spawn_secret_boss(sp["boss"], sp["pos"])
			game.hud.announce("MID-BOSS: %s" % BossData.SECRET[sp["boss"]]["name"], Color(1.0, 0.3, 0.75))
		else:
			foe = game._spawn_enemy(sp["kind"], 1.0 + maxf(0.0, wave), sp["elite"], sp["pos"])
		if foe != null:
			wave_foes.append(foe)
		game.burst(sp["pos"], Color(1.0, 0.3, 0.75), 8, 160.0, 4.0, 0.4)
	pending_spawns.clear()
	wave_pending = false


func _update_wave_label() -> void:
	wave_label.visible = false   # no wave / enemy counter any more: "WAVE N" is announced when a wave starts


## The floor spots of an app room (see SPOT_DEFS). The maps, phone and weather apps have their own set-ups.
func _setup_spots(theme: String) -> void:
	spots.clear()
	spot_on = -1
	spot_prog = 0.0
	spots_finished = false
	spot_wait_leave = false
	spot_lock = 0.0
	if not SPOT_DEFS.has(theme):
		_drop_lore(APP_LORE[theme], _free_spot(room.bounds.get_center() + Vector2(560, 0)))
		return
	spot_theme = theme
	var o: Vector2 = room.bounds.get_center()
	var lines: Array = SPOT_DEFS[theme]["lines"]
	for i in lines.size():
		var off: Vector2 = Vector2.ZERO if theme == "clock" else (SPOT_OFFS[i] if lines.size() > 1 else SPOT_OFFS[1])
		var start_on: bool = theme == "settings"   # the three levers start ON; the hint note says which should end up off
		spots.append({"pos": _free_spot(o + off), "text": lines[i], "on": start_on, "done": theme == "settings" and start_on == SETTINGS_TARGET[i]})
	if theme == "settings":
		settings_note_pos = _free_spot(o + Vector2(-760, -300))
		settings_note_cd = 1.0


func _update_spots(p: Vector2, delta: float) -> void:
	if spots_finished:
		return
	spot_lock = maxf(0.0, spot_lock - delta)
	if spot_theme == "settings":   # the hint note can be read again and again
		settings_note_cd = maxf(0.0, settings_note_cd - delta)
		if settings_note_cd <= 0.0 and p.distance_to(settings_note_pos) < 70.0:
			settings_note_cd = 2.5
			_show_lore(APP_LORE["settings"])
			return
	var def: Dictionary = SPOT_DEFS[spot_theme]
	var kind: String = def["kind"]
	var near := -1
	for i in spots.size():
		if p.distance_to(spots[i]["pos"]) < SPOT_REACH:
			near = i
	var finished := true   # every spot done (a minigame has just closed on the last one)
	for sp0 in spots:
		if not sp0["done"]:
			finished = false
	if finished:
		_finish_app(spot_theme)
		return
	if spot_wait_leave:   # a minigame just closed: step off the spot before it can start again
		if near < 0:
			spot_wait_leave = false
		spot_on = -1
		spot_prog = 0.0
		return
	if near != spot_on:
		spot_on = near
		if near >= 0 and not spots[near]["done"]:
			Sfx.play("spot_enter", 1.0, 0.0, 0.0)
		if kind != "stand":
			spot_prog = 0.0
		spot_latched = false
	if near >= 0 and kind == "switch" and not spot_latched:   # a switch flips after half a second on it, once per visit
		spot_prog += delta
		if spot_prog >= 0.5:
			spot_latched = true
			var sw: Dictionary = spots[near]
			sw["on"] = not sw["on"]
			sw["done"] = sw["on"] == SETTINGS_TARGET[near]
			Sfx.play("switch_on" if sw["on"] else "switch_off", 1.0, 0.0, 0.0)
			game.float_text(sw["pos"] + Vector2(0, -110), "%s: %s" % [sw["text"], "ON" if sw["on"] else "OFF"], def["color"], 26, 1.5)
	elif near >= 0 and kind == "stand" and not spots[near]["done"]:   # the clock: stay on the spot (leaving makes the time slip back)
		var before := int(spot_prog)
		spot_prog = minf(float(def["time"]), spot_prog + delta)
		if int(spot_prog) != before:
			Sfx.play("spot_tick", 0.9 + 0.12 * spot_prog, 0.0, 0.0)
		if spot_prog >= float(def["time"]):
			spots[near]["done"] = true
	elif kind == "stand" and spot_prog > 0.0:
		spot_prog = maxf(0.0, spot_prog - delta * 1.5)
	elif near >= 0 and kind != "switch" and kind != "stand" and not spots[near]["done"] and spot_lock <= 0.0:
		spot_prog += delta
		if int(spot_prog / 0.2) != int((spot_prog - delta) / 0.2):
			Sfx.play("spot_tick", 0.8 + 0.9 * spot_prog / float(def["time"]), 0.0, 0.0)
		if spot_prog >= float(def["time"]):
			spot_prog = 0.0
			_start_minigame(spot_theme, near)
			return
	var all_done := true
	for sp3 in spots:
		if not sp3["done"]:
			all_done = false
	if all_done:
		_finish_app(spot_theme)


## Starts the paused minigame of the app room's spot `idx`.
func _start_minigame(theme: String, idx: int) -> void:
	mg_ctx = theme
	mg_spot = idx
	spot_wait_leave = true
	var first: bool = not Meta.lore.has(APP_LORE[theme]["id"])
	var note := "[ADDED TO THE LORE LOG]" if first else ""
	match theme:
		"notes":
			mg.cipher("ENCRYPTED NOTE", NOTE_PLAIN, NOTE_SHIFT, "HINT: THE MAKER'S NAME HAS FIVE LETTERS.", note)
		"camera":
			spot_flash = 1.0
			Sfx.play("shutter", 1.0, 0.0, 0.0)
			mg.show_photo("SNAP %d / 3" % (idx + 1), PixelArt.load_tex("secret/smartphone_secret_room_snap_%d.png" % (idx + 1)), SNAP_CAPTIONS[idx], note if idx == 2 else "")
		"photos":
			mg.photo_observe("CORRUPTED PHOTO", PixelArt.load_tex("secret/smartphone_secret_room_photo_innocent.png"), PixelArt.load_tex("secret/smartphone_secret_room_photo_truth.png"), PHOTO_REGIONS, PHOTO_CAPTION, note)
		"messages":
			mg.chat("UNKNOWN: NEW MESSAGE", CHAT_ROUNDS, CHAT_FINALE, note)
		"music":
			var stream: AudioStream = load(TRUTH_FILE) if ResourceLoader.exists(TRUTH_FILE) else null
			mg.piano("REPEAT THE MELODY", PIANO_KEYS, PIANO_SEQ, PIANO_ROUNDS, "THE TRUTH (A SNIPPET). IT IS IN THE CODEX NOW.", stream, note)
		_:
			mg.close({})


func _on_mg_closed(result: Dictionary) -> void:
	var theme := mg_ctx
	mg_ctx = ""
	if result.get("wrong", false):   # a wrong reply in the chat: elites answer
		spot_lock = 6.0
		game.hud.announce("WRONG REPLY. SOMETHING ANSWERS.", Global.C_RED)
		for k in 2:
			var at: Vector2 = room.nearest_open(game.player.global_position + Vector2.from_angle(randf() * TAU) * 420.0)
			game._spawn_enemy("trojan", 1.0 + game.elapsed / 60.0, true, at)
			game.burst(at, Color(1.0, 0.3, 0.3), 16, 240.0, 4.0, 0.5)
		return
	if not result.get("ok", false) or spots.is_empty():
		return
	if theme == "music":
		Meta.codex_see("music:truth")   # unlocks the track in the codex (MUSIC section)
		Meta.save()
	spots[mg_spot]["done"] = true
	Sfx.play("spot_done", 1.0, 0.0, 0.0)


## All spots of an app room are done: the room's reward (the minigame already showed and logged its lore; some rooms drop a lore page instead).
func _finish_app(theme: String) -> void:
	spots_finished = true
	var def: Dictionary = SPOT_DEFS[theme]
	game.hud.announce(def["done"], Global.C_GOLD)
	Sfx.play("app_done", 1.0, 0.0, 0.0)
	var o: Vector2 = room.bounds.get_center()
	if def.get("drop", false):
		_drop_lore(APP_LORE[theme], _free_spot(o + Vector2(120, 0)))
	elif theme == "settings":   # the lore page is the hint note; solving it gives a placeholder reward instead: an item cache
		game._drop("cache", room.nearest_open(o + Vector2(120, 0)), 1)
		game.float_text(o + Vector2(120, -60), "SETTINGS UNLOCKED", def["color"], 26, 1.5)
	else:
		Meta.lore_found(APP_LORE[theme]["id"])
	game._drop("heal", room.nearest_open(o + Vector2(80, 80)), 1)
	game.burst(o, def["color"], 40, 300.0, 5.0, 0.8)


func _draw_spots() -> void:
	if spots.is_empty():
		return
	if spot_theme == "settings":
		var nt: Texture2D = PixelArt.load_tex("secret/lore_command_line.png")
		if nt != null:
			_halo(settings_note_pos, 68.0, Color(0.6, 0.8, 1.0, 0.4))
			draw_texture_rect(nt, Rect2(settings_note_pos + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)
	var def: Dictionary = SPOT_DEFS[spot_theme]
	var kind: String = def["kind"]
	var col: Color = def["color"]
	var ring: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_spot.png")
	var fr := int(t * 5.0) % 4
	for i in spots.size():
		var sp: Dictionary = spots[i]
		var c: Vector2 = sp["pos"]
		if kind == "switch":   # a toggle pill: the knob sits right when on
			var on: bool = sp["on"]
			var pill := Rect2(c - Vector2(80, 34), Vector2(160, 68))
			draw_rect(pill, Color(0.05, 0.08, 0.15, 0.9))
			draw_rect(pill, Color(0.45, 0.9, 0.55) if on else Color(0.6, 0.65, 0.75), false, 5.0)
			draw_rect(Rect2(c + Vector2(40 if on else -40, 0) - Vector2(24, 24), Vector2(48, 48)), Color(0.45, 0.95, 0.55) if on else Color(0.7, 0.75, 0.85))
			_text(sp["text"], c + Vector2(0, -60), 26, Color.WHITE)
			if spot_on == i and not spot_latched and spot_prog > 0.0:
				_pix_arc(c, 96.0, -PI / 2.0, -PI / 2.0 + TAU * spot_prog / 0.5, Color(1, 1, 1, 0.9), 6.0)
			continue
		_draw_spot_art(c, col, def["glyph"], def["tag"], bool(sp["done"]), fr)
		var prog_k := 0.0
		if spot_on == i and spot_prog > 0.0 and not sp["done"]:
			prog_k = spot_prog / float(def["time"])
		elif kind == "stand" and spot_prog > 0.0:
			prog_k = spot_prog / float(def["time"])
		if prog_k > 0.0:
			_pix_arc(c, 112.0, -PI / 2.0, -PI / 2.0 + TAU * prog_k, Color(1, 1, 1, 0.95))
		if kind == "stand" and not sp["done"]:
			_text("%d" % ceili(float(def["time"]) - spot_prog), c + Vector2(0, -130), 40, Color(1, 1, 1, 0.9))
	if spot_flash > 0.0:
		draw_rect(room.bounds, Color(1, 1, 1, 0.6 * spot_flash))


## One floor spot: the pixel ring (smartphone_secret_room_spot.png, 4 pulsing frames) tinted by kind, a glyph on it and its label below; done = green with a check.
func _draw_spot_art(c: Vector2, col: Color, glyph: String, tag: String, done: bool, fr: int) -> void:
	var ring: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_spot.png")
	var base := Color(0.45, 0.9, 0.55) if done else col
	var sz := 190.0
	_halo(c, 96.0, Color(base, 0.35))
	if ring != null:
		draw_texture_rect_region(ring, Rect2(c - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), Rect2(fr * 64, 0, 64, 64), Color(base, 0.95))
	if done:
		_pix_line(c + Vector2(-22, 2), c + Vector2(-6, 20), base)
		_pix_line(c + Vector2(-6, 20), c + Vector2(26, -18), base)
		return
	var gt: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_glyph_%s.png" % glyph) if glyph != "" else null
	if gt != null:
		draw_texture_rect(gt, Rect2(c + Vector2(-40, -48 + 3.0 * sin(t * 3.0)), Vector2(80, 80)), false, Color(1, 1, 1, 0.95))
	_text(tag, c + Vector2(0, 62), 22, Color(1, 1, 1, 0.9))


# ---------------- the maps app: follow the arrow through the checkpoints, then dig ----------------

func _setup_maps() -> void:
	var o: Vector2 = room.bounds.get_center()
	maps_cp.clear()
	maps_done.clear()
	for off in MAPS_OFFS:
		maps_cp.append(_free_spot(o + off))
		maps_done.append(false)
	maps_next = 0
	maps_failed = 0.0
	maps_inside = -1
	maps_state = "follow"
	maps_dig = 0.0
	maps_x = _free_spot(o + Vector2(780, 300))


func _update_maps(p: Vector2, delta: float) -> void:
	if maps_state == "done":
		return
	if maps_state == "dig":   # X marks the spot: stay on it to dig
		if p.distance_to(maps_x) < 90.0:
			maps_dig += delta
			if int(maps_dig * 6.0) != int((maps_dig - delta) * 6.0):
				game.burst(maps_x, Color(0.55, 0.4, 0.2), 4, 160.0, 4.0, 0.5)
				Sfx.play("dig_tick", 0.9 + 0.2 * randf(), 0.0, 0.0)
			if maps_dig >= 2.5:
				maps_state = "done"
				game.hud.announce("YOU DUG SOMETHING UP", Global.C_GOLD)
				Sfx.play("dig_done", 1.0, 0.0, 0.0)
				game.burst(maps_x, Global.C_GOLD, 40, 320.0, 5.0, 0.8)
				_drop_lore(APP_LORE["maps"], maps_x)
		else:
			maps_dig = maxf(0.0, maps_dig - delta)
		return
	if maps_failed > 0.0:   # the wrong checkpoint: everything flashes red, then goes grey again
		maps_failed -= delta
		if maps_failed <= 0.0:
			for i in maps_done.size():
				maps_done[i] = false
			maps_next = 0
		return
	var inside := -1
	for i in maps_cp.size():
		if p.distance_to(maps_cp[i]) < 75.0:
			inside = i
	if inside == maps_inside:
		return
	maps_inside = inside
	if inside < 0 or maps_done[inside]:
		return
	if inside == maps_next:
		maps_done[inside] = true
		maps_next += 1
		Sfx.play("cp_ok", 1.0 + 0.1 * maps_next, 0.0, 0.0)
		game.ring(maps_cp[inside], Color(0.4, 1.0, 0.5), 200.0, 0.4, 6.0)
		if maps_next >= maps_cp.size():
			maps_state = "dig"
			game.hud.announce("X MARKS THE SPOT", Global.C_GOLD)
	else:
		maps_failed = 1.2
		Sfx.play("cp_bad", 1.0, 0.0, 0.0)
		game.float_text(maps_cp[inside] + Vector2(0, -90), "WRONG WAY", Color(1.0, 0.4, 0.4), 28, 1.2)


func _draw_maps() -> void:
	var p: Vector2 = game.player.global_position
	for i in maps_cp.size():
		var c: Vector2 = maps_cp[i]
		var col := Color(0.62, 0.64, 0.7)
		if maps_failed > 0.0:
			col = Color(1.0, 0.3, 0.3).lerp(Color(0.62, 0.64, 0.7), 0.0 if int(t * 10.0) % 2 == 0 else 0.5)
		elif maps_done[i]:
			col = Color(0.4, 1.0, 0.5)
		elif i == maps_next and maps_state == "follow":
			col = Color(1.0, 0.85, 0.3).lerp(Color.WHITE, 0.5 + 0.5 * sin(t * 6.0))
		_draw_spot_art(c, col, "flag", "", maps_done[i] and maps_failed <= 0.0, int(t * 5.0) % 4)
	if maps_state == "follow" and maps_failed <= 0.0 and maps_next < maps_cp.size():   # an arrow beside the player, pointing at the next checkpoint
		var to: Vector2 = maps_cp[maps_next] - p
		var d: Vector2 = to.normalized()
		var ac: Vector2 = p + d * (110.0 + 8.0 * sin(t * 6.0))
		var side := d.orthogonal()
		var tip := ac + d * 34.0   # a pixel arrow: a dark outline and a yellow shaft and two head strokes, all whole squares
		_pix_line(ac - d * 22.0, tip, Color(0.1, 0.1, 0.2, 0.95), 14.0)
		_pix_line(tip, tip - d * 26.0 + side * 22.0, Color(0.1, 0.1, 0.2, 0.95), 14.0)
		_pix_line(tip, tip - d * 26.0 - side * 22.0, Color(0.1, 0.1, 0.2, 0.95), 14.0)
		_pix_line(ac - d * 20.0, tip, Color(1.0, 0.85, 0.3), 8.0)
		_pix_line(tip, tip - d * 24.0 + side * 20.0, Color(1.0, 0.85, 0.3), 8.0)
		_pix_line(tip, tip - d * 24.0 - side * 20.0, Color(1.0, 0.85, 0.3), 8.0)
	if maps_state == "dig" or maps_state == "done":
		var c2: Vector2 = maps_x
		_halo(c2, 96.0, Color(0.9, 0.3, 0.3, 0.35 + 0.15 * sin(t * 4.0)))
		var gt: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_glyph_x.png")
		if gt != null:
			draw_texture_rect(gt, Rect2(c2 - Vector2(60, 60), Vector2(120, 120)), false, Color(0.85, 0.15, 0.15, 1.0))
		if maps_state == "dig":
			_text("DIG HERE", c2 + Vector2(0, 100), 24, Color.WHITE)
			if maps_dig > 0.0:
				_pix_arc(c2, 112.0, -PI / 2.0, -PI / 2.0 + TAU * maps_dig / 2.5, Color(1, 1, 1, 0.95))


# ---------------- the phone app: press the keys in the order of the number on the note ----------------

func _setup_phone() -> void:
	var o: Vector2 = room.bounds.get_center()
	var walls: Array = room.walls.duplicate()
	walls.sort_custom(func(a, b):
		if absf(a.position.y - b.position.y) > 40.0:
			return a.position.y < b.position.y
		return a.position.x < b.position.x)
	var digits := [1, 2, 3, 4, 5, 6, 7, 8, 9, 0]
	phone_keys.clear()
	var texes := []
	for d in 10:
		texes.append(PixelArt.load_tex("secret/smartphone_secret_room_digit_%d.png" % d))
	var idx := {}
	for k in walls.size():
		phone_keys.append({"rect": walls[k], "digit": digits[k], "lit": -10.0, "bad": -10.0})
		idx[walls[k].position] = digits[k]
	room.icon_tex = texes
	room.icon_index = idx
	phone_prog = 0
	phone_touch = -1
	phone_done = false
	phone_note_cd = 1.0
	phone_note_pos = _free_spot(o + Vector2(-800, 380))
	spots.clear()


func _update_phone(p: Vector2, delta: float) -> void:
	phone_note_cd = maxf(0.0, phone_note_cd - delta)
	if phone_note_cd <= 0.0 and p.distance_to(phone_note_pos) < 70.0:   # the note can be read again and again
		phone_note_cd = 2.5
		_show_lore(PHONE_NOTE)
		return
	if phone_done:
		return
	var touch := -1
	for k in phone_keys.size():
		var rc: Rect2 = phone_keys[k]["rect"]
		var cp := Vector2(clampf(p.x, rc.position.x, rc.end.x), clampf(p.y, rc.position.y, rc.end.y))
		if p.distance_to(cp) < 60.0:
			touch = k
	if touch == phone_touch:
		return
	phone_touch = touch
	if touch < 0:
		return
	var key: Dictionary = phone_keys[touch]
	if key["digit"] == PHONE_NUMBER[phone_prog]:
		key["lit"] = t
		phone_prog += 1
		Sfx.play("key_press", 0.7 + 0.1 * key["digit"], 0.0, 0.0)
		if phone_prog >= PHONE_NUMBER.size():
			phone_done = true
			game.hud.announce("CALL CONNECTED", Global.C_GOLD)
			Sfx.play("spot_done", 1.0, 0.0, 0.0)
			_show_lore(PHONE_VOICE)
			Sfx.announce("voice_note")   # the synthesized voice note (tools/gen_voice_note.py)
	else:
		key["bad"] = t
		phone_prog = 0
		Sfx.play("mg_bad", 1.0, 0.0, 0.0)
		game.float_text(p + Vector2(0, -90), "WRONG NUMBER", Color(1.0, 0.4, 0.4), 28, 1.2)


func _draw_phone() -> void:
	for k in phone_keys:
		var rc: Rect2 = k["rect"]
		if t - float(k["lit"]) < 0.5:
			draw_rect(rc.grow(10.0), Color(0.4, 1.0, 0.5, 0.45 * (1.0 - (t - float(k["lit"])) / 0.5)))
		if t - float(k["bad"]) < 0.5:
			draw_rect(rc.grow(10.0), Color(1.0, 0.3, 0.3, 0.5 * (1.0 - (t - float(k["bad"])) / 0.5)))
	var nt: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_memo.png")   # the number note
	if nt != null:
		_halo(phone_note_pos, 68.0, Color(1.0, 0.9, 0.5, 0.4))
		draw_texture_rect(nt, Rect2(phone_note_pos + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)
		_text("NUMBER", phone_note_pos + Vector2(0, 66), 20, Color(1, 1, 1, 0.85))


# ---------------- the weather app: survive the thunderstorm ----------------

func _start_storm() -> void:
	storm_left = STORM_TIME
	storm_on = true
	storm_t = 2.5
	game.hud.announce("THUNDERSTORM: SURVIVE %d SECONDS" % int(STORM_TIME), Color(1.0, 0.9, 0.4))


func _update_storm(p: Vector2, delta: float) -> void:
	if not storm_on:
		return
	storm_left -= delta
	storm_t -= delta
	var k := 1.0 - clampf(storm_left / STORM_TIME, 0.0, 1.0)   # the storm worsens as it goes
	wave_label.visible = true
	wave_label.text = "THUNDERSTORM: %d s" % ceili(maxf(0.0, storm_left))
	if storm_t <= 0.0 and storm_left > 1.5:
		storm_t = lerpf(2.0, 0.8, k)
		for n in (1 if k < 0.6 else 2):
			var at: Vector2 = p + Vector2.from_angle(randf() * TAU) * randf_range(0.0, 280.0) if randf() < 0.65 else room.bounds.get_center() + Vector2(randf_range(-900, 900), randf_range(-550, 550))
			game.hazards.spawn_thunder(room.nearest_open(at))
	if storm_left <= 0.0:
		storm_on = false
		wave_label.visible = false
		game.hud.announce("THE STORM PASSES", Global.C_GOLD)
		Sfx.play("pw_grant", 1.0, 0.0, 0.0)
		_drop_lore(APP_LORE["weather"], _free_spot(room.bounds.get_center()))



func _foes_left() -> int:
	var n := 0
	for e in wave_foes:
		if is_instance_valid(e) and e.is_inside_tree() and not e.is_queued_for_deletion():
			n += 1
	return n


func _update_waves() -> void:
	if wave >= 0 and not wave_pending:
		for e in game.enemy_layer.get_children():   # nothing spawns more enemies: split popups, summoned bugs and the like are removed on the spot
			if not wave_foes.has(e) and not e.is_queued_for_deletion():
				game.burst(e.global_position, Color(1.0, 0.3, 0.75), 6, 140.0, 3.0, 0.3)
				e.queue_free()
	if wave < 0 or wave_pending or _foes_left() > 0:
		return
	wave += 1
	if wave >= wave_set.size():
		wave = -1
		if room_id == "app_clock":
			game.hud.announce("THE WAVES STOP", Global.C_GOLD)
			return
		Meta.lore_found("a2_corrupt_done")
		game.hud.announce("APP CLEANSED", Global.C_GOLD)
		Sfx.play("pw_grant", 1.0, 0.0, 0.0)
		game.burst(room.bounds.get_center(), Color(1.0, 0.3, 0.75), 60, 420.0, 5.0, 0.9)
		_drop_lore(CORRUPT_LORE, room.bounds.get_center())
		_grant("a2")
		return
	wave_pending = true
	get_tree().create_timer(2.5, false).timeout.connect(_spawn_wave)


# ---------------- A4: the office errand chain ----------------

func _update_office(p: Vector2, delta: float) -> void:
	door_msg_cd = maxf(0.0, door_msg_cd - delta)
	# 1. the intern sleeps next to the printer, which is printing; stand at the printer to jam it: that reveals the half-printed document and wakes the intern up
	if not intern_spawned:
		intern_spawned = true
		var sleeper = _make_intern(game.main_arena.nearest_open(INTERN_SLEEP), false)
		sleeper.hold = true
	printer_snd_cd = maxf(0.0, printer_snd_cd - delta)
	if not jam_done and printer_snd_cd <= 0.0 and p.distance_to(PRINTER_POS) < 1100.0:
		printer_snd_cd = 2.2
		Sfx.play("printer_feed", 1.0, -4.0 + (0.0 if p.distance_to(PRINTER_POS) < 600.0 else -6.0), 0.0)
	if not jam_done:
		if p.distance_to(JAM_SPOT) < 150.0 and tp_dir == 0:
			jam_hold += delta
			if int(jam_hold / 0.25) != int((jam_hold - delta) / 0.25):
				Sfx.play("spot_tick", 0.8 + 0.9 * jam_hold / JAM_TIME, 0.0, 0.0)
			if jam_hold >= JAM_TIME:
				_jam_printer()
		else:
			jam_hold = maxf(0.0, jam_hold - delta * 2.0)
	if is_instance_valid(intern) and intern.hold:   # asleep
		intern_say_cd -= delta
		if intern_say_cd <= 0.0 and p.distance_to(intern.global_position) < 1000.0:
			intern_say_cd = 2.6
			intern_line_i += 1
			game.float_text(intern.global_position + Vector2(30, -90), INTERN_SLEEP_LINES[intern_line_i % INTERN_SLEEP_LINES.size()], Color(0.7, 0.8, 1.0), 22, 2.4)
	# 2. the intern shows up, hides, and when you come close it runs to the lounge door, unlocks it and goes inside: follow it, do not kill it
	_check_intern_dead()   # killed before it reached the door (very tanky, but possible): the badge still drops here
	if is_instance_valid(intern):
		intern_last_pos = intern.global_position
		if intern.route_goal != null:
			intern_say_cd -= delta
			if intern_say_cd <= 0.0:
				intern_say_cd = 2.4
				game.float_text(intern.global_position + Vector2(0, -90), INTERN_RUN_LINES[intern_line_i % INTERN_RUN_LINES.size()], Color(0.7, 0.8, 1.0), 22, 2.2)
				intern_line_i += 1
			if intern.global_position.distance_to(DOOR_POS) < 130.0:   # it reached the door: it unlocks it and goes inside
				door_unlocked = true
				intern_inside = true
				game.hud.announce("THE INTERN UNLOCKED THE LOUNGE", Global.C_GOLD)
				Sfx.play("door_unlock", 1.0, 0.0, 0.0)
				game.ring(DOOR_POS, Global.C_GOLD, 260.0, 0.6, 8.0)
				intern.queue_free()
				intern = null
	_pickup_badge(p)
	# 3. the lounge door: open once the intern unlocked it (or you hold its badge)
	if p.distance_to(DOOR_POS) < 110.0 and portal_cd <= 0.0:
		if door_unlocked or has_badge:
			_enter_lounge()
		elif door_msg_cd <= 0.0:
			if jam_done:   # the intern is already running for it
				door_msg_cd = 4.0
				game.hud.announce("DOOR LOCKED", Global.C_RED)
			else:   # the intern has not been woken yet: a dialogue
				door_msg_cd = 15.0
				_say("LOCKED.
THE KEYS MUST BE WITH SOMEONE ELSE.")
	# 4. the intern's locker: needs its badge; opening it unlocks the intern class and its weapon
	if p.distance_to(_locker_pos()) < 110.0 and portal_cd <= 0.0 and not Meta.lore.has("a4_locker_open"):
		if has_badge:
			_open_locker()
		elif door_msg_cd <= 0.0:
			door_msg_cd = 4.0
			game.hud.announce("LOCKER: NEEDS THE INTERN'S BADGE", Global.C_RED)


func player_near(pos: Vector2, r: float) -> bool:
	return game.player != null and game.player.global_position.distance_to(pos) < r


func _locker_pos() -> Vector2:
	return game.main_arena.nearest_open(INTERN_POS + LOCKER_OFFSET)


func _pickup_badge(p: Vector2) -> void:
	if badge_pos != null and p.distance_to(badge_pos) < 70.0:
		badge_pos = null
		has_badge = true
		game.hud.announce("BADGE ACQUIRED", Global.C_GOLD)
		Sfx.play("badge_get", 1.0, 0.0, 0.0)
		_show_lore(BADGE_LORE)   # saved as lore (and for good, see has_badge at the start of a run)


## The player killed the intern (on the map or in the lounge): it drops its badge where it fell, the kill is an achievement.
func _intern_killed(at: Vector2) -> void:
	intern = null
	intern_inside = false
	badge_pos = at
	Meta.lore["a4_intern_killed"] = true
	Meta.save()
	game.hud.announce("YOU FIRED THE INTERN", Global.C_GOLD)
	game.ring(at, Global.C_GOLD, 260.0, 0.6, 8.0)


func _open_locker() -> void:
	Meta.lore["a4_locker_open"] = true
	Meta.unlocks["class:intern"] = true   # the class and its weapon (both still placeholders: see secret_rooms_placeholders.md)
	Meta.save()
	game.hud.announce("INTERN'S LOCKER OPEN: CLASS UNLOCKED", Global.C_GOLD)
	Sfx.play("locker_open", 1.0, 0.0, 0.0)
	Sfx.play("legendary", 1.0, -6.0, 0.0)
	game.burst(_locker_pos(), Global.C_GOLD, 40, 300.0, 5.0, 0.8)


## The intern node is gone: if it died (hp <= 0 when it left the tree) that is a kill; if it was only cleared away (leaving a room) it is simply gone and may be spawned again.
func _check_intern_dead() -> void:
	if intern_killed_flag:
		intern_killed_flag = false
		_intern_killed(intern_last_pos)
	elif intern != null and not is_instance_valid(intern):
		intern = null


func _update_lounge(p: Vector2, delta: float) -> void:
	manager_say_cd = maxf(0.0, manager_say_cd - delta)   # the manager is an NPC: it cannot be attacked, it just talks when you are near
	if manager_say_cd <= 0.0 and p.distance_to(manager_pos) < 520.0:
		manager_say_cd = 3.6
		game.float_text(manager_pos + Vector2(0, -110), MANAGER_LINES[manager_i % MANAGER_LINES.size()], Color(1.0, 0.95, 0.75), 20, 3.4)
		manager_i += 1
	_check_intern_dead()
	if is_instance_valid(intern):
		intern_last_pos = intern.global_position
		intern_say_cd -= delta   # it talks while it runs from you
		if intern_say_cd <= 0.0:
			intern_say_cd = 3.0
			game.float_text(intern.global_position + Vector2(0, -90), INTERN_LOUNGE_LINES[intern_line_i % INTERN_LOUNGE_LINES.size()], Color(0.7, 0.8, 1.0), 20, 2.4)
			intern_line_i += 1
	_pickup_badge(p)


func _jam_printer() -> void:
	jam_done = true
	jam_hold = 0.0
	Sfx.play("printer_jam", 1.0, 0.0, 0.0)
	game.shake(0.5)
	game.hud.announce("PRINTER JAMMED", Color(0.95, 0.95, 0.95))
	_pickup_lore_here(PRINT_LORE, PRINTER_POS + Vector2(0, 230))
	if is_instance_valid(intern):   # the noise wakes the intern: it panics and runs for the lounge door to find the manager
		intern.hold = false
		intern.route_goal = DOOR_POS
		intern_say_cd = 0.0


## On the office map (in_lounge false) the intern is never a target: it is out of the "enemies" group, takes almost no damage and has no health bar. In the lounge it is a normal
## target with the boss health bar, and it can be killed.
func _make_intern(pos: Vector2, in_lounge := true):
	var b = BossScript.new()
	b.setup_boss(BossData.SECRET["intern"], 0, 0.0)
	b.set_meta("secret", true)
	b.no_teleport = true   # it never jumps to the player like a normal boss: it sleeps by the printer, then runs its route
	b.damage_taken_mult = 1.0 if in_lounge else 0.0
	b.position = pos
	b.tree_exiting.connect(func(): intern_killed_flag = b.hp <= 0.0)
	game.enemy_layer.add_child(b)
	if not in_lounge:
		b.remove_from_group("enemies")   # not a target on the office map
	else:
		game.current_boss = b   # the boss health bar
	intern = b
	return b


## A lore item lying on the main map (picked up like the ones in rooms).
func _pickup_lore_here(entry: Dictionary, pos: Vector2) -> void:
	main_lore.append({"pos": pos, "entry": entry})


func _enter_lounge() -> void:
	teleport(func(): _enter_lounge_now(), true, "door_open")


func _enter_lounge_now() -> void:
	_enter_side("lounge", "lounge", 5)
	game.hud.announce("MANAGER'S LOUNGE", Color(0.9, 0.8, 0.5))
	var o: Vector2 = room.bounds.get_center()
	var real := randi() % 14
	var n := 0
	for gy in 3:
		for gx in 5:
			if n >= 14:
				break
			var pos := o + Vector2(-700 + gx * 350, -480 + gy * 480)
			if absf(pos.x - o.x) < 200.0 and absf(pos.y - o.y) < 120.0:
				pos.x += 400.0
			var entry: Dictionary
			if n == real:
				entry = MANAGER_LORE
			else:
				entry = {"id": "a4_joke_%d" % (n % JOKES.size()), "title": "MEMO", "tex": "office_server_secret_room_memo", "text": JOKES[n % JOKES.size()], "quick": true}
			_drop_lore(entry, pos)
			n += 1
	manager_pos = room.nearest_open(o + Vector2(260, -160))
	manager_say_cd = 0.0
	if intern_inside:   # the intern is in here: kill it for the badge
		_make_intern(room.nearest_open(o + Vector2(-600, 0))).flee = true   # it runs from you inside the lounge
		game.hud.announce("THE INTERN IS HIDING HERE", Color(0.4, 0.55, 0.95))


# ---------------- A5: the data center ----------------

## Gives the reward of an egg room (REWARDS). With no id set yet it just announces a placeholder.
func _grant(key: String) -> void:
	var r: Dictionary = REWARDS.get(key, {})
	var w: String = r.get("weapon", "")
	var c: String = r.get("class", "")
	if r.has("title"):
		game.hud.announce("TITLE EARNED: " + r["title"], Global.C_GOLD)
	elif w == "" and c == "":
		game.hud.announce("REWARD PLACEHOLDER (%s)" % key.to_upper(), Global.C_GOLD)
	else:
		if w != "":
			Meta.unlocks["weapon:" + w] = true
		if c != "":
			Meta.unlocks["class:" + c] = true
		Meta.save()
		game.hud.announce("NEW WEAPON FOUND" if w != "" else "NEW CLASS FOUND", Global.C_GOLD)


func _a5_door() -> Vector2:
	return A5_DOOR_C


func _a5_pad_pos(i: int) -> Vector2:
	return A5_RACK + A5_PADS[i]


func _update_datacenter(p: Vector2, delta: float) -> void:
	if a5_seq.is_empty():   # the sequence of this run: all four colours exactly once, in a random order
		a5_seq = [0, 1, 2, 3]
		a5_seq.shuffle()
	if not a5_rack_seen and p.distance_to(A5_RACK) < 420.0:   # first time near the rack / the sealed door: a short dialogue
		a5_rack_seen = true
		_say(A5_RACK_LINE)
		return
	if not a5_door_seen and a5_state != "done" and p.distance_to(_a5_door()) < 380.0:
		a5_door_seen = true
		_say(A5_DOOR_LINE)
		return
	for i in 4:
		a5_pad_t[i] = maxf(0.0, a5_pad_t[i] - delta)
	a5_pad_bad = maxf(0.0, a5_pad_bad - delta)
	# the rack's loop: four colours one after another, a pause, then again
	a5_t += delta
	var lit := _a5_rack_lit()
	if lit != a5_prev_lit:
		a5_prev_lit = lit
		if lit >= 0 and p.distance_to(A5_RACK) < 1500.0:
			Sfx.play("rack_tone_%d" % lit, 1.0, -3.0, 0.0)
	if a5_state == "idle":
		var on := -1
		for i in 4:
			if p.distance_to(_a5_pad_pos(i)) < A5_PAD_R:
				on = i
		if on != a5_on_pad:
			a5_on_pad = on
			if on >= 0:
				if on == a5_seq[a5_i]:
					a5_pad_on[on] = true
					a5_pad_t[on] = 0.8
					Sfx.play("rack_tone_%d" % on, 1.0, 0.0, 0.0)
					a5_i += 1
					if a5_i >= a5_seq.size():
						_a5_solved()
				else:
					a5_i = 0
					a5_pad_on = [false, false, false, false]
					a5_pad_bad = 0.8
					Sfx.play("rack_wrong", 1.0, 0.0, 0.0)
					game.hud.announce("WRONG ORDER", Global.C_RED)
	if a5_state == "done" and p.distance_to(_a5_door()) < 90.0 and portal_cd <= 0.0:
		_enter_upload()


## Which of the rack's four colours is lit right now (-1 in the gaps and in the pause).
func _a5_rack_lit() -> int:
	if a5_seq.is_empty():
		return -1
	var period := A5_FLASH * A5_LEN + A5_PAUSE
	var ph := fposmod(a5_t, period)
	if ph >= A5_FLASH * A5_LEN:
		return -1
	var k := int(ph / A5_FLASH)
	return int(a5_seq[k]) if fposmod(ph, A5_FLASH) < A5_FLASH * 0.66 else -1


func _a5_solved() -> void:
	a5_state = "done"
	game.main_arena.walls.erase(A5_WALL)
	game.main_arena._rebuild_grid()
	game.hud.announce("DATA STREAM DOOR OPEN", Global.C_GOLD)
	Sfx.play("rack_solved", 1.0, 0.0, 0.0)
	Sfx.play("door_open", 1.0, 0.0, 0.0)   # the door creaks open, like the lounge door
	game.ring(_a5_door(), Global.C_GOLD, 300.0, 0.6, 8.0)


func _enter_upload() -> void:
	teleport(func(): _enter_upload_now(), true, "door_open")


func _enter_upload_now() -> void:
	rooms.erase("upload_done")
	_enter_side("upload", "upload", 6)
	stream_cd = STREAM_TRICKLE
	game.room_enemy_cap = 60
	upload_boss_killed = false
	upload_boss = null
	if not Meta.lore.has("a5_upload"):   # the boss waits at the east end until the upload lore has been found once
		upload_boss_pos = Vector2(room.bounds.end.x - 450.0, room.bounds.get_center().y)
		var b = _spawn_secret_boss("streamhive", upload_boss_pos)
		b.tree_exiting.connect(func(): upload_boss_killed = b.hp <= 0.0)
		upload_boss = b
	game.hud.announce("DATA STREAM: PUSH EAST. THE DARK WEST END THROWS YOU OUT", Global.C_GREEN)


## The data-stream hallway: everything that is not the boss is carried west along the stream (it does not chase), aims its shots at you if it shoots,
## and is removed once it is off screen on the left. The boss never moves and spits out most of the enemies; after it is defeated the east end keeps
## sending enemies, slower. The dark west end throws the player out.
func _update_upload(p: Vector2, delta: float) -> void:
	var pl = game.player
	var lim: Rect2 = room.bounds.grow(-64.0)
	pl.position.x = clampf(pl.position.x - STREAM_PUSH * delta, lim.position.x, lim.end.x)
	pl.position.y = clampf(pl.position.y, room.bounds.position.y + STREAM_CABLE + pl.radius, room.bounds.end.y - STREAM_CABLE - pl.radius)   # the cable walls
	if p.x < room.bounds.position.x + STREAM_EXIT_X:
		game.hud.announce("THROWN OUT OF THE STREAM", Global.C_RED)
		_leave()
		return
	if is_instance_valid(upload_boss):
		upload_boss_pos = upload_boss.global_position
	elif upload_boss != null and upload_boss_killed and not rooms.has("upload_done"):   # the boss is defeated: the upload lore drops where it stood
		rooms["upload_done"] = true
		upload_boss = null
		game.hud.announce("UPLOAD COMPLETE", Global.C_GOLD)
		Sfx.play("app_done", 1.0, 0.0, 0.0)
		_drop_lore(A5_LORE, upload_boss_pos + Vector2(-200.0, 0.0))
	elif upload_boss != null and not upload_boss_killed:
		upload_boss = null   # it was only cleared away
	var left_cut: float = maxf(room.bounds.position.x + 40.0, p.x - 1500.0)
	for e in game.enemy_layer.get_children():
		if e.is_boss or e.is_queued_for_deletion():
			continue
		if e.stream_vec == Vector2.ZERO:   # newly spawned (the boss spits them out): carried west, aimed at the row the player is in
			var flow := randf_range(STREAM_FLOW_MIN, STREAM_FLOW_MAX)
			var t_arrive := maxf((e.global_position.x - p.x) / flow, 0.5)
			var vy := clampf((p.y + randf_range(-110.0, 110.0) - e.global_position.y) / t_arrive, -flow * 0.5, flow * 0.5) if e.global_position.x > p.x else randf_range(-40.0, 40.0)
			e.stream_vec = Vector2(-flow, vy)
			e.no_teleport = true
		elif e.global_position.x < left_cut:
			e.queue_free()   # off screen on the left: gone, room for new ones from the east
	if not is_instance_valid(upload_boss):   # no boss (defeated, or found already): the east end sends enemies at a slow rate
		stream_cd -= delta
		if stream_cd <= 0.0:
			stream_cd = STREAM_TRICKLE
			var kinds := ["bug", "worm", "mite", "spyware", "miner"]
			var at := Vector2(room.bounds.end.x - 300.0, clampf(p.y + randf_range(-300.0, 300.0), room.bounds.position.y + STREAM_CABLE + 40.0, room.bounds.end.y - STREAM_CABLE - 40.0))
			game._spawn_enemy(kinds[randi() % kinds.size()], 2.0, false, at)


# ---------------- A3: the shop and the peripherals ----------------

func _shop_spots() -> Array:
	var o: Vector2 = room.bounds.get_center()
	var out := []
	for i in 4:
		out.append(o + Vector2(-540 + i * 360, -40))   # 360 px apart, so the 160 px pedestals never touch
	return out


## The shop: stand on a pedestal to see the item, its price and what it does; stay on it (the ring fills) to buy. Nothing is bought by walking past.
func _update_shop(p: Vector2, delta: float) -> void:
	var spots := _shop_spots()
	var on := -1
	for i in 4:
		if p.distance_to(spots[i]) < SHOP_REACH:
			on = i
	if on != shop_on:
		shop_on = on
		shop_t = 0.0
		if on >= 0:
			var owned_now: bool = Meta.lore.has("a3_have_" + PERIPHERALS[on])
			Sfx.play("ui_card", 0.7, 0.0, 0.0)
			if not owned_now and Meta.data < A3_COSTS[PERIPHERALS[on]]:
				Sfx.play("ui_deny", 0.8, -6.0, 0.0)
	if on < 0:
		shop_box.visible = false
		return
	var id: String = PERIPHERALS[on]
	var cost: int = A3_COSTS[id]
	var owned: bool = Meta.lore.has("a3_have_" + id)
	var short := cost - int(Meta.data)
	var status := "OWNED. THE LAPTOP HAS ITS ROOM NOW." if owned else ("NEED %d MORE DATA" % short if short > 0 else "STAY ON THE PEDESTAL TO BUY")
	shop_label.text = "%s     %s
%s
YOUR DATA: %d     %s" % [id.to_upper(), "OWNED" if owned else "%d DATA" % cost, PERIPH_INFO[id], int(Meta.data), status]
	shop_label.add_theme_color_override("font_color", Color(1.0, 0.45, 0.45) if (not owned and short > 0) else Color.WHITE)
	shop_box.visible = true
	_place_bottom(shop_box)
	if owned or short > 0 or tp_dir != 0:
		return
	shop_t += delta
	if shop_t < SHOP_TIME:
		return
	shop_t = 0.0
	Meta.data -= cost
	Meta.lore["a3_have_" + id] = true
	Meta.save()
	game.hud.announce("BOUGHT: %s. CHECK THE LAPTOP" % id.to_upper(), Global.C_GOLD)
	Sfx.play("buy", 1.0, 0.0, 0.0)
	game.ring(spots[on], Global.C_GOLD, 260.0, 0.6, 8.0)
	game.burst(spots[on], Global.C_GOLD, 30, 300.0, 4.0, 0.7)


func _place_bottom(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM, Control.PRESET_MODE_MINSIZE)
	c.position.y -= 130.0   # above the ability bar


## A sticky note with the store login lies beside the touchpad slab of the laptop (the biggest block on its map).
func _place_login_note() -> void:
	var big := Rect2()
	for w in game.main_arena.walls:
		if w.size.x * w.size.y > big.size.x * big.size.y:
			big = w
	main_lore.append({"pos": Vector2(big.end.x + 200.0, big.get_center().y), "entry": LOGIN_NOTE})


## The four ports of the laptop. An owned one connects when you stay against it (the ring fills); a port without a device says so.
func _update_laptop(p: Vector2, delta: float) -> void:
	var near := -1
	for i in 4:
		if p.distance_to(A3_PORTALS[i]) < 100.0:
			near = i
	if near < 0 or portal_cd > 0.0 or tp_dir != 0:
		port_on = -1
		port_t = maxf(0.0, port_t - delta * 3.0)
		return
	var id: String = PERIPHERALS[near]
	if not port_seen:   # the first time at any port: a short dialogue
		port_seen = true
		_say(A3_PORT_LINE)
		return
	if not Meta.lore.has("a3_have_" + id):
		if port_on != near:
			port_on = near
			Sfx.play("ui_deny", 0.8, -6.0, 0.0)
			game.float_text(A3_PORTALS[near] + Vector2(0, -130), "PORT EMPTY: NO %s CONNECTED" % id.to_upper(), Color(1.0, 0.5, 0.5), 24, 2.5)
		return
	if port_on != near:
		port_on = near
		port_t = 0.0
		Sfx.play("ui_card", 0.7, 0.0, 0.0)
	port_t += delta
	if int(port_t / 0.15) != int((port_t - delta) / 0.15):
		Sfx.play("app_tick", 0.8 + 0.9 * port_t / PORT_TIME, 0.0, 0.0)
	if port_t >= PORT_TIME:
		port_t = 0.0
		port_on = -1
		_enter_periph(id, near)


func _enter_periph(id: String, i: int) -> void:
	teleport(func(): _enter_periph_now(id, i), true)


func _enter_periph_now(id: String, i: int) -> void:
	_enter_side("periph_" + id, "periph_" + id, 10 + i, "secret/gaming_laptop_secret_room_%s_wall.png" % id, "secret/gaming_laptop_secret_room_%s_floor.png" % id)
	game.hud.announce(id.to_upper() + " CONNECTED", Global.C_CYAN)
	if not rooms.has("pdone_" + id):
		var b = _spawn_secret_boss(A3_BOSS[id], room.nearest_open(room.bounds.get_center() + Vector2(700, 0)))
		game.ring(b.position, b.color, 300.0, 0.8, 10.0)
		game.burst(b.position, b.color, 30, 280.0, 5.0, 0.7)
		periph_boss = b


# ---------------- A6: the satellite uplink ----------------

func _build_battery() -> void:
	bat_tex = TextureRect.new()
	bat_tex.position = Vector2(16, 128)
	bat_tex.custom_minimum_size = Vector2(64, 64)
	bat_tex.size = Vector2(64, 64)
	bat_tex.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	layer.add_child(bat_tex)
	bat_label = _label("", 22, Global.C_GOLD)
	bat_label.position = Vector2(86, 148)
	layer.add_child(bat_label)


func _a6_kills() -> int:
	return int(Meta.lore.get("a6_kills", 0))


func _update_sat(p: Vector2, delta: float) -> void:
	if game.kills > a6_seen:
		var add: int = game.kills - a6_seen
		a6_seen = game.kills
		Meta.lore["a6_kills"] = _a6_kills() + add
		a6_save += add
		if a6_save >= 50:
			a6_save = 0
			Meta.save()
	var frac := clampf(float(_a6_kills()) / float(a6_target), 0.0, 1.0)
	if bat_tex != null:
		var full: Texture2D = PixelArt.load_tex("secret/satellite_uplink_secret_room_battery.png")
		if full != null:
			var at := AtlasTexture.new()
			at.atlas = full
			at.region = Rect2(mini(int(frac * 4.99), 4) * 16, 0, 16, 16)
			bat_tex.texture = at
		bat_label.text = "UPLINK %d / %d" % [mini(_a6_kills(), a6_target), a6_target]
		bat_tex.visible = not active
		bat_label.visible = not active
	if frac < 1.0:
		return
	if a6_beam_t > 0.0:
		a6_beam_t -= delta
		if p.distance_to(A6_BEAM) < 110.0:
			a6_beam_t = 0.0
			_enter_moon()
		elif a6_beam_t <= 0.0:
			a6_pads = [false, false, false]
			game.hud.announce("BEAM MISSED: PADS RESET", Global.C_RED)
		return
	for i in 3:
		if not a6_pads[i] and p.distance_to(A6_PADS[i]) < 100.0:
			a6_pads[i] = true
			Sfx.play("pickup", 0.8 + i * 0.25, -2.0, 0.0)
			game.hud.announce("PAD %d / 3 ALIGNED" % a6_pads.count(true), Color(0.5, 0.8, 1.0))
	if a6_pads.count(true) == 3:
		a6_beam_t = A6_BEAM_TIME
		game.hud.announce("LASER FIRING: STEP INTO THE BEAM", Global.C_GOLD)
		Sfx.play("legendary", 0.7, 0.0, 0.0)
		game.shake(0.8)


func _enter_moon() -> void:
	teleport(func(): _enter_moon_now(), true)


func _enter_moon_now() -> void:
	_enter_side("moon", "moon", 7, "secret/satellite_uplink_secret_room_moon_wall.png", "secret/satellite_uplink_secret_room_moon_floor.png")
	game.hud.announce("MOON BASE", Color(0.7, 0.8, 1.0))
	a6_wave_cd = 6.0
	if not rooms.has("moon_done"):
		var b = _spawn_secret_boss("alien", room.nearest_open(room.bounds.get_center() + Vector2(900, 0)))
		a6_boss = b


func _well_centers() -> Array:
	var o: Vector2 = room.bounds.get_center()
	var out := []
	for w in A6_WELLS:
		out.append(o + w)
	return out


func _update_moon(p: Vector2, delta: float) -> void:
	for c in _well_centers():
		var d: float = p.distance_to(c)
		if d < A6_WELL_R and d > 12.0:
			var closeness := 1.0 - d / A6_WELL_R
			game.player.position += (c - p).normalized() * lerpf(110.0, 185.0, closeness) * delta
	if is_instance_valid(a6_boss):
		a6_wave_cd -= delta
		if a6_wave_cd <= 0.0:
			a6_wave_cd = 8.0
			var o: Vector2 = room.bounds.get_center()
			for k in 5:
				game._spawn_enemy("mite", 2.0, false, o + Vector2.from_angle(TAU * k / 5.0) * 900.0)


# ---------------- A7: the mainframe ----------------

func _update_mainframe(p: Vector2, delta: float) -> void:
	a7_cd = maxf(0.0, a7_cd - delta)
	if a7_key_ok and p.distance_to(A7_PORTAL) < 100.0 and portal_cd <= 0.0:
		_enter_hq()
		return
	if a7_cd > 0.0:
		return
	for i in 3:
		if p.distance_to(A7_BOXES[i]) < 90.0 and a7_wires < 3:
			a7_cd = 1.0
			if i == a7_wires:
				a7_wires += 1
				Sfx.play("pickup", 0.8 + i * 0.2, -2.0, 0.0)
				game.hud.announce("WIRE %d / 3 CONNECTED" % a7_wires, Color(0.4, 1.0, 0.6))
			elif i > a7_wires:
				a7_wires = 0
				Sfx.play("ui_deny", 0.8, 0.0, 0.0)
				game.hud.announce("SHORT CIRCUIT: WIRES RESET", Global.C_RED)
			return
	if p.distance_to(A7_KEYPAD) < 110.0 and not a7_key_ok and not pw_box.visible:
		a7_cd = 4.0
		if a7_wires >= 3:
			_open_password("key")
		else:
			game.hud.announce("NO POWER: CONNECT THE WIRES", Global.C_RED)


func _a7_unlock() -> void:
	a7_key_ok = true
	game.hud.announce("ACCESS KEY ACCEPTED: HQ OPEN", Global.C_GOLD)
	Sfx.play("legendary", 0.9, 0.0, 0.0)
	game.ring(A7_PORTAL, Global.C_GOLD, 300.0, 0.6, 8.0)


func _enter_hq() -> void:
	teleport(func(): _enter_hq_now(), true)


func _enter_hq_now() -> void:
	_enter_side("hq", "hq", 8)
	game.hud.announce("OVERSEER HQ", Color(0.9, 0.5, 0.3))
	if not rooms.has("hq_lore"):
		rooms["hq_lore"] = true
		_drop_lore(A7_LORE, room.bounds.get_center() + Vector2(-700, 350))
		_grant("a7")


func _hq_portals() -> Array:
	var o: Vector2 = room.bounds.get_center()
	var out := []
	for i in 6:
		out.append(o + Vector2(-950 + i * 380, -350))
	return out


func _update_hq(p: Vector2, delta: float) -> void:
	a7_cd = maxf(0.0, a7_cd - delta)
	var ports := _hq_portals()
	for i in 6:
		if p.distance_to(ports[i]) < 90.0 and portal_cd <= 0.0:
			Meta.selected_device = i   # a fresh START RUN on that device
			Global.change_scene("res://scenes/game.tscn")
			return
	if a7_cd <= 0.0 and game.enemy_layer.get_child_count() < 6:
		a7_cd = 6.0
		game._spawn_enemy("sentry", 3.0, false, room.bounds.get_center() + Vector2(900, randf_range(-400, 400)))


# ---------------- A8: the unobserved room ----------------

func _update_quantum(p: Vector2, delta: float) -> void:
	a8_clock += delta
	a8_msg_cd = maxf(0.0, a8_msg_cd - delta)
	if a8_spot < 0:
		if a8_clock >= A8_AFTER:
			a8_spot = randi() % 4
		return
	if p.distance_to(A8_SPOTS[a8_spot]) > 130.0:
		a8_hold = 0.0
		return
	var seen := false
	for e in game.enemy_layer.get_children():
		var d: Vector2 = (e.global_position - p).abs()
		if d.x < 700.0 and d.y < 420.0:
			seen = true
			break
	if seen:
		if a8_hold > 0.0 and a8_msg_cd <= 0.0:
			a8_msg_cd = 3.0
			game.hud.announce("OBSERVED", Global.C_RED)
		a8_hold = 0.0
		return
	a8_hold += delta
	if a8_hold >= A8_HOLD:
		a8_hold = 0.0
		_enter_unobserved()


func _enter_unobserved() -> void:
	teleport(func(): _enter_unobserved_now(), true)


func _enter_unobserved_now() -> void:
	_enter_side("unobserved", "unobserved", 9)
	a8_t = 0.0
	a8_stage = 0


func _update_unobserved(delta: float) -> void:
	a8_t += delta
	if a8_stage == 0 and a8_t > 2.5:
		a8_stage = 1
		game.hud.announce("YOU WERE NOT SUPPOSED TO SEE THIS", Global.C_RED)
		Sfx.announce("lucifer_unobserved")
		_drop_lore(A8_LORE, room.bounds.get_center() + Vector2(400, 300))
	if a8_stage == 1 and a8_t > 16.0:
		a8_stage = 2
		game.hud.announce("GET OUT", Global.C_RED)
		_leave()


# ---------------- drawing ----------------

func _draw() -> void:
	if game == null:
		return
	if not active:
		if wall_active:
			var tex: Texture2D = PixelArt.load_tex("secret/smart_fridge_secret_room_ice_wall_%d.png" % clampi(stage, 0, 2))
			if tex != null:
				var jit := Vector2(sin(t * 90.0), cos(t * 70.0)) * 6.0 * crack_flash
				for i in 3:
					draw_texture_rect(tex, Rect2(A1_WALL.position + Vector2(128 * i, 0) + jit, Vector2(128, 128)), false)
				if crack_flash > 0.0:
					draw_rect(Rect2(A1_WALL.position + jit, A1_WALL.size), Color(1, 1, 1, crack_flash * 0.6))
		elif stage >= CRACKS and room_id == "":
			if shatter > 0.0:
				var s: Texture2D = PixelArt.load_tex("secret/smart_fridge_secret_room_ice_wall_3.png")
				if s != null:
					for i in 3:
						draw_texture_rect(s, Rect2(A1_WALL.position + Vector2(128 * i, 0), Vector2(128, 128)), false, Color(1, 1, 1, shatter * 2.0))
			_draw_portal(_wall_center())
		if office:
			_draw_office()
		if datacenter:
			_draw_datacenter()
		if sat:
			_draw_sat()
		if mainframe:
			_draw_mainframe()
		if quantum:
			_draw_quantum()
		if laptop:
			_draw_laptop()
		if phone and corrupt_i >= 0:
			var ct: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_corrupted_app.png")
			if ct != null:
				var r: Rect2 = app_blocks[corrupt_i]
				var f := int(t * 6.0) % 4
				draw_texture_rect_region(ct, r.grow(-ICON_INSET), Rect2(f * 16, 0, 16, 16))
		if phone and open_idx >= 0 and open_t > 0.0:
			_draw_open_ring(app_blocks[open_idx], open_t / OPEN_TIME)
	elif room != null:
		if floor_path != "":
			var ft: Texture2D = PixelArt.load_tex(floor_path)
			if ft != null:
				draw_texture_rect(ft, room.bounds, true, floor_tint)
		if room_id == "lounge":   # the manager: an NPC that stands in the lounge
			var mg_tex: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_manager.png")
			if mg_tex != null:
				draw_texture_rect_region(mg_tex, Rect2(manager_pos - Vector2(60, 70), Vector2(120, 120)), Rect2((int(t * 2.0) % 2) * 40, 0, 40, 40))   # 40x40 frames like the intern
				_text("MANAGER", manager_pos + Vector2(0, 80), 20, Color(1, 1, 1, 0.8))
		if room_id == "lounge" and badge_pos != null:   # the intern's badge, dropped where it fell in the lounge
			var lb: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_badge.png")
			if lb != null:
				_halo(badge_pos, 60.0, Color(1.0, 0.9, 0.4, 0.4))
				draw_texture_rect(lb, Rect2(badge_pos + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)
		if room_id == "corrupt":
			_draw_glitch(room.bounds, maxi(wave, 0))
		if room_id.begins_with("app_") and room_id != "app_store":
			_draw_app_decor(room_id.substr(4), room.bounds)
			_draw_spots()
		if room_id == "app_weather":   # the thunder strikes of the storm (the hazard art, drawn here so the room floor does not cover it)
			for z in game.hazards.zones:
				if z["id"] == "thunder":
					var page: Texture2D = PixelArt.hazard_tex("thunder")
					var fade: float = HazardScript.zone_fade(z)
					if page != null:
						PixelArt.draw_hazard_zone(self, page, z["pos"], z["r"], z["t"], 0.9 * fade, 0.0, -1, HazardScript.frame_at("thunder", z["t"]), HazardScript.ART_R["thunder"])
					HazardScript.draw_thunder_bolt(self, z["pos"], z["r"], z["t"], fade)
		if room_id == "app_maps" and not maps_cp.is_empty():
			_draw_maps()
		if room_id == "app_phone" and not phone_keys.is_empty():
			_draw_phone()
		if spawn_delay > 0.0:   # glitch squares where the next wave is about to appear
			for ps in pending_spawns:
				var gl := 0.5 + 0.5 * sin(t * 30.0)
				draw_rect(Rect2(ps["pos"] - Vector2(36, 36), Vector2(72, 72)), Color(1.0, 0.3, 0.75, 0.25 + 0.4 * gl), false, 5.0)
				draw_rect(Rect2(ps["pos"] - Vector2(20, 20), Vector2(40, 40)), Color(0.3, 1.0, 0.9, 0.2 * gl))
		if room_id == "freezer":
			_draw_cold(room.bounds)
			if thaw_flash > 0.0:
				draw_rect(room.bounds, Color(0.85, 0.97, 1.0, thaw_flash * 0.45))
			if frozen_on:
				var ids := ["golem", "window"]
				var spots := _spots()
				for i in 2:
					if not thawed[i]:
						_draw_frozen(ids[i], spots[i], thaw_prog[i], thaw_pulse[i])
		if room_id == "upload":
			_draw_stream()
		if room_id == "moon":
			_draw_moon()
		if room_id == "hq":
			_draw_hq()
		if room_id == "unobserved":
			_draw_unobserved()
		if room_id == "app_store":
			_draw_shop()
		_draw_exit()
		for d in lore_drops:
			var li: Texture2D = PixelArt.load_tex("secret/%s.png" % d["entry"]["tex"])
			if li != null:
				var gp := 0.5 + 0.5 * sin(t * 3.0)
				for gi in 3:   # a soft halo centred on the item, in the freezer's icy hue
					draw_circle(d["pos"], (84.0 - 20.0 * gi) + gp * 6.0, Color(0.6, 0.9, 1.0, 0.07 + 0.05 * gi + 0.04 * gp))
				draw_texture_rect(li, Rect2(d["pos"] + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)


## The way out: the freezer's portal, or the red close button of an app.
func _draw_office() -> void:
	var pt: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_printer.png")
	if pt != null:
		draw_texture_rect(pt, Rect2(PRINTER_POS - Vector2(48, 48), Vector2(96, 96)), false)
	var pp: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_paper.png")   # sheets slide out of the printer until it is jammed
	if pp != null:
		if not jam_done:
			for k in 3:
				var off := fposmod(t * 50.0 + k * 40.0, 120.0)
				draw_texture_rect(pp, Rect2(PRINTER_POS + Vector2(-12 + (k - 1) * 4, 40 + off), Vector2(24, 30)), false, Color(1, 1, 1, 1.0 - off / 160.0))
		else:
			draw_texture_rect(pp, Rect2(PRINTER_POS + Vector2(-12, 54), Vector2(24, 30)), false)   # one sheet stuck in the tray
	if not jam_done and player_near(JAM_SPOT, 520.0):
		_halo(JAM_SPOT, 72.0, Color(1.0, 0.9, 0.5, 0.35 + 0.15 * sin(t * 4.0)))
		_text("JAM THE PRINTER", JAM_SPOT + Vector2(0, -100), 22, Color(1, 1, 1, 0.95))
		if jam_hold > 0.0:
			_pix_arc(JAM_SPOT, 96.0, -PI / 2.0, -PI / 2.0 + TAU * jam_hold / JAM_TIME, Color(1, 1, 1, 0.95), 7.0)
	var dt: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_lounge_door_open.png" if door_unlocked else "secret/office_server_secret_room_lounge_door.png")   # looks open once the intern has gone through
	if dt != null:
		draw_texture_rect(dt, Rect2(DOOR_POS - Vector2(64, 64), Vector2(128, 128)), false)
	var bt: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_badge.png")
	if bt != null and badge_pos != null:
		draw_texture_rect(bt, Rect2(badge_pos + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)
	var lk: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_locker.png")   # the intern's locker: closed, or open once the badge was used (tools/gen_secret_fx_art.py)
	if lk != null:
		var lopen := 1 if Meta.lore.has("a4_locker_open") else 0
		draw_texture_rect_region(lk, Rect2(_locker_pos() - Vector2(40, 60), Vector2(80, 120)), Rect2(lopen * 20, 0, 20, 30))
		_text("LOCKER 1337", _locker_pos() + Vector2(0, -80), 22, Color(1, 1, 1, 0.95))
	var mt: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_memo.png")
	if mt != null:
		for d in main_lore:
			draw_texture_rect(mt, Rect2(d["pos"] + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)


func _draw_datacenter() -> void:
	# the door: sealed (the closed door sprite in the wall block) or, once the pads were touched in order, open
	var dt: Texture2D = PixelArt.load_tex("secret/data_center_secret_room_cold_aisle_door_open.png" if a5_state == "done" else "secret/data_center_secret_room_cold_aisle_door.png")
	if dt != null:
		draw_texture_rect(dt, Rect2(_a5_door() - Vector2(64, 64), Vector2(128, 128)), false)
	# the rack node and its current colour on a big lamp above it
	var rt: Texture2D = PixelArt.load_tex("secret/data_center_secret_room_led_rack.png")
	if rt != null:
		draw_texture_rect_region(rt, Rect2(A5_RACK - Vector2(64, 64), Vector2(128, 128)), Rect2((int(t * 2.0) % 4) * 16, 0, 16, 16))
	var pad: Texture2D = PixelArt.load_tex("secret/data_center_secret_room_led_pad.png")   # 2 frames: dim, lit (white, tinted by colour)
	var lit := _a5_rack_lit()
	if pad != null:
		var lamp := Rect2(A5_RACK + Vector2(-48, -190), Vector2(96, 96))
		if lit >= 0:
			_halo(A5_RACK + Vector2(0, -142), 96.0, Color(A5_COLORS[lit], 0.5))
			draw_texture_rect_region(pad, lamp, Rect2(16, 0, 16, 16), A5_COLORS[lit])
		else:
			draw_texture_rect_region(pad, lamp, Rect2(0, 0, 16, 16), Color(0.45, 0.5, 0.6))
		for i in 4:   # the four pads: dim until touched in the right order
			var c := _a5_pad_pos(i)
			var r := Rect2(c - Vector2(64, 64), Vector2(128, 128))
			var col: Color = A5_COLORS[i]
			if a5_pad_bad > 0.0:
				col = Color(1.0, 0.25, 0.25).lerp(col, 0.0)
				draw_texture_rect_region(pad, r, Rect2(16 * (int(t * 12.0) % 2), 0, 16, 16), col)
			elif a5_pad_on[i] or a5_pad_t[i] > 0.0:
				_halo(c, 96.0, Color(col, 0.55))
				draw_texture_rect_region(pad, r, Rect2(16, 0, 16, 16), col)
			else:
				draw_texture_rect_region(pad, r, Rect2(0, 0, 16, 16), Color(col, 0.6).darkened(0.45))


## The upload hallway's floor: panels of data scrolling toward the start.
func _draw_stream() -> void:
	# One continuous data stream, right to left: dark base, then many lanes of pixel packets (square chunks of 8 px) sliding left at different speeds,
	# each with a bright head and a fading trail, plus tiny bits drifting in the gaps. Everything is a function of time, so it never repeats visibly or looks like stacked tiles.
	var r: Rect2 = room.bounds
	draw_rect(r, Color(0.02, 0.05, 0.08))
	var dim := 0.42   # the stream is a quiet backdrop: dim and low-contrast, so the enemies, bullets and pickups stay the loudest things on screen
	var u := 8.0
	var pcx: float = game.player.global_position.x if game.player != null else r.get_center().x
	var vis_lo := pcx - 1700.0   # only what is near the player is drawn: the hallway is long
	var vis_hi := pcx + 1700.0
	var lanes := int(r.size.y / 32.0)
	var heads := [Color(0.75, 1.0, 1.0), Color(0.55, 1.0, 0.8), Color(0.5, 0.85, 1.0), Color(0.9, 1.0, 0.85)]
	var tails := [Color(0.1, 0.55, 0.65), Color(0.1, 0.5, 0.4), Color(0.15, 0.35, 0.7), Color(0.2, 0.55, 0.35)]
	for i in lanes:
		var y: float = r.position.y + i * 32.0 + 8.0
		var v := 160.0 + float((i * 37) % 7) * 70.0        # px/s, leftwards
		var per := 900.0 + float((i * 113) % 5) * 140.0     # distance between repeats of this lane's pattern
		var ci := i % 4
		for k in 3:
			var len_u := 6 + ((i * 7 + k * 5) % 9)           # packet length in units
			var o := float((i * 211 + k * 397) % 1000) / 1000.0 * per
			var reps := int(r.size.x / per) + 2
			for rep in reps:
				var x: float = r.position.x + rep * per + fposmod(o - t * v, per) - per
				x = floorf(x / u) * u
				if x > vis_hi or x + (len_u + 4) * u < vis_lo:
					continue
				var body := Rect2(x + u, y, (len_u - 1) * u, u)
				draw_rect(body, Color(tails[ci], 0.55 * dim))
				for j in range(1, len_u, 2):   # the packet's bits: alternating brighter chunks
					draw_rect(Rect2(x + j * u, y, u, u), Color(tails[ci], 0.8 * dim))
				draw_rect(Rect2(x, y - 4.0, u, u + 8.0), Color(heads[ci], 0.7 * dim))   # the bright head (leading, on the left)
				for tr in 3:   # the trail behind (to the right), fading
					draw_rect(Rect2(x + len_u * u + tr * u, y + 2.0, u, u - 4.0), Color(tails[ci], (0.35 - 0.1 * tr) * dim))
		for b in 5:   # loose bits drifting in the dark between the packets
			var bx: float = r.position.x + fposmod(float((i * 53 + b * 977) % 4000) - t * (v * 0.6 + b * 20.0), r.size.x)
			bx = floorf(bx / u) * u
			if bx < vis_lo or bx > vis_hi:
				continue
			draw_rect(Rect2(bx, y + 8.0 * ((b + i) % 3), u * 0.5, u * 0.5), Color(0.4, 0.8, 0.9, 0.35 * dim))
	_draw_cable_edges(r, vis_lo, vis_hi)
	# the west end tapers off into the dark (stepped in 32 px bands, nothing is smooth): stepping into it throws you out
	var bands := int(STREAM_DARK / 32.0)
	for k in bands:
		if r.position.x + k * 32.0 + 32.0 < vis_lo:
			continue
		var a_k := pow(1.0 - float(k) / bands, 1.6)
		draw_rect(Rect2(r.position.x + k * 32.0, r.position.y, 32.0, r.size.y), Color(0.0, 0.0, 0.02, a_k))


## The top and bottom walls of the hallway drawn as the inside of a data cable / optic fibre: an outer jacket with segment marks, a foil shield, and four glass
## strands (orange, blue, green, white) along which pulses of light run from right to left. Everything is whole 8 px squares.
func _draw_cable_edges(r: Rect2, lo: float, hi: float) -> void:
	var u := 8.0
	var x0 := floorf(maxf(lo, r.position.x) / 128.0) * 128.0
	var x1 := minf(hi, r.end.x)
	var strand_cols := [Color(1.0, 0.6, 0.2), Color(0.35, 0.6, 1.0), Color(0.4, 1.0, 0.55), Color(0.95, 0.95, 1.0)]
	for side in 2:   # 0: top wall, 1: bottom wall (mirrored)
		var sgn := 1.0 if side == 0 else -1.0
		var y_edge: float = r.position.y if side == 0 else r.end.y
		_cable_band(x0, x1, y_edge, sgn, 0.0, 32.0, Color(0.09, 0.11, 0.16))   # the outer jacket
		_cable_band(x0, x1, y_edge, sgn, 32.0, 40.0, Color(0.16, 0.19, 0.27))
		_cable_band(x0, x1, y_edge, sgn, 40.0, 56.0, Color(0.30, 0.36, 0.48))  # the foil shield
		_cable_band(x0, x1, y_edge, sgn, 56.0, 60.0, Color(0.45, 0.52, 0.66))
		_cable_band(x0, x1, y_edge, sgn, 60.0, STREAM_CABLE, Color(0.05, 0.07, 0.12))   # the dark core the strands lie in
		var xi := x0
		while xi < x1:   # segment marks on the jacket and ribs on the shield every 128 px
			draw_rect(Rect2(xi, minf(y_edge, y_edge + sgn * 32.0), u, 32.0), Color(0.05, 0.06, 0.1))
			draw_rect(Rect2(xi + 4.0 * u, minf(y_edge + sgn * 40.0, y_edge + sgn * 56.0), u, 16.0), Color(0.2, 0.24, 0.34))
			xi += 128.0
		for k in 4:   # the four fibre strands, each with light pulses running west
			var yk: float = y_edge + sgn * (62.0 + k * 8.0)
			var sy: float = minf(yk, yk + sgn * u)
			draw_rect(Rect2(x0, sy, x1 - x0, u), Color(strand_cols[k], 0.22))
			var per := 520.0 + k * 90.0
			var spd := 380.0 + k * 70.0
			var reps := int((x1 - x0) / per) + 2
			for rep in reps:
				var px := floorf((x0 + rep * per + fposmod(float(k) * 173.0 - t * spd, per) - per) / u) * u
				if px > x1 or px + 7.0 * u < x0:
					continue
				draw_rect(Rect2(px, sy, 7.0 * u, u), Color(strand_cols[k], 0.55))
				draw_rect(Rect2(px, sy, u, u), Color(1, 1, 1, 0.8))   # the pulse's bright head, leading to the west


func _cable_band(x0: float, x1: float, y_edge: float, sgn: float, d0: float, d1: float, col: Color) -> void:
	var ya: float = y_edge + sgn * d0
	var yb: float = y_edge + sgn * d1
	draw_rect(Rect2(x0, minf(ya, yb), x1 - x0, absf(yb - ya)), col)


func _icon(path: String, c: Vector2, size: float, region := Rect2()) -> void:
	var tex: Texture2D = PixelArt.load_tex(path)
	if tex == null:
		return
	var r := Rect2(c - Vector2(size, size) * 0.5, Vector2(size, size))
	if region.size.x > 0.0:
		draw_texture_rect_region(tex, r, region)
	else:
		draw_texture_rect(tex, r, false)


func _text(s: String, c: Vector2, size: int, col: Color) -> void:
	if size < 36:   # the small white labels of every interactable area: bigger (about 1.45x, at least 30 px), fully opaque and with a thicker outline
		size = maxi(30, roundi(size * 1.45))
		if col.r > 0.8 and col.g > 0.8 and col.b > 0.8:
			col.a = 1.0
	var at := c - Vector2(size * s.length() * 0.25, 0)
	draw_string_outline(Global.FONT_BODY, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, maxi(6, size / 4), Color(0, 0, 0, 0.95))   # a dark outline so it reads on any floor
	draw_string(Global.FONT_BODY, at, s, HORIZONTAL_ALIGNMENT_LEFT, -1, size, col)


func _draw_shop() -> void:
	var spots := _shop_spots()
	var o: Vector2 = room.bounds.get_center()
	_text("PERIPHERALS", o + Vector2(0, -250), 44, Color(1, 1, 1, 0.95))
	_text("STAND ON ONE TO LOOK, STAY TO BUY", o + Vector2(0, -205), 22, Color(1, 1, 1, 0.8))
	for i in 4:
		var id: String = PERIPHERALS[i]
		var c: Vector2 = spots[i]
		var owned: bool = Meta.lore.has("a3_have_" + id)
		var afford: bool = Meta.data >= A3_COSTS[id]
		var edge := Color(0.45, 0.9, 0.55) if owned else (Global.C_GOLD if afford else Color(0.85, 0.35, 0.35))
		var plate := Rect2(c - Vector2(80, 80) + Vector2(0, 40), Vector2(160, 160))
		draw_rect(plate.grow(6.0), Color(0, 0, 0, 0.35))
		draw_rect(plate, Color(0.06, 0.09, 0.18, 0.95))
		draw_rect(plate, Color(edge, 0.55 + 0.35 * (0.5 + 0.5 * sin(t * 3.0 + i)) if shop_on == i else 0.5), false, 5.0)
		_icon("secret/gaming_laptop_secret_room_%s_portal.png" % id, c + Vector2(0, sin(t * 3.0 + i) * 5.0 - 10.0), 112.0, Rect2(0, 0, 16, 16))
		_text(id.to_upper(), c + Vector2(0, -90), 24, Color.WHITE)
		_text("OWNED" if owned else "%d DATA" % A3_COSTS[id], c + Vector2(0, 150), 24, edge)
		if shop_on == i and shop_t > 0.0:   # the buy ring
			var rad := 110.0
			_pix_arc(c + Vector2(0, 40), rad, 0.0, TAU, Color(1, 1, 1, 0.12))
			_pix_arc(c + Vector2(0, 40), rad, -PI / 2.0, -PI / 2.0 + TAU * shop_t / SHOP_TIME, Color(edge, 0.95))


func _draw_laptop() -> void:
	var nt: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_memo.png")
	if nt != null:
		for d in main_lore:
			_halo(d["pos"], 68.0, Color(0.6, 0.9, 1.0, 0.4))
			draw_texture_rect(nt, Rect2(d["pos"] + Vector2(-32, -32 + sin(t * 3.0) * 6.0), Vector2(64, 64)), false)
	for i in 4:
		var id: String = PERIPHERALS[i]
		var c: Vector2 = A3_PORTALS[i]
		var owned: bool = Meta.lore.has("a3_have_" + id)
		var frame: Texture2D = PixelArt.load_tex("secret/gaming_laptop_secret_room_port_frame.png")   # pixel port slot with a running rim (tools/gen_secret_fx_art.py)
		var plug: Texture2D = PixelArt.load_tex("secret/gaming_laptop_secret_room_%s_portal.png" % id)
		_halo(c, 140.0, Color(0.5, 0.85, 1.0, 0.4 + 0.15 * sin(t * 2.5 + i)) if owned else Color(0.5, 0.5, 0.6, 0.18))
		if frame != null:
			draw_texture_rect_region(frame, Rect2(c - Vector2(80, 80), Vector2(160, 160)), Rect2((int(t * 6.0) % 4 if owned else 0) * 32, 0, 32, 32), Color.WHITE if owned else Color(0.5, 0.5, 0.6, 0.7))
		if plug != null:
			if owned:
				draw_texture_rect_region(plug, Rect2(c - Vector2(48, 48), Vector2(96, 96)), Rect2((int(t * 6.0) % 4) * 16, 0, 16, 16))
			else:   # an empty port: the plug's outline, dim
				draw_texture_rect_region(plug, Rect2(c - Vector2(48, 48), Vector2(96, 96)), Rect2(0, 0, 16, 16), Color(0.5, 0.5, 0.6, 0.35))
				_text("EMPTY", c + Vector2(0, 8), 28, Color(0.8, 0.8, 0.9, 0.7))
		_text(id.to_upper(), c + Vector2(0, 150), 24, Color(1, 1, 1, 0.9 if owned else 0.5))
		if port_on == i and owned and port_t > 0.0:
			_pix_arc(c, 112.0, -PI / 2.0, -PI / 2.0 + TAU * port_t / PORT_TIME, Color(1, 1, 1, 0.95))


func _draw_sat() -> void:
	var charged: bool = _a6_kills() >= a6_target
	if not charged:
		return
	for i in 3:
		var tex: Texture2D = PixelArt.load_tex("secret/satellite_uplink_secret_room_pad_%s.png" % ("on" if a6_pads[i] else "off"))
		if tex != null:
			var src := Rect2(64.0 * (int(t * 6.0) % 2), 0, 64, 64) if a6_pads[i] else Rect2(0, 0, 64, 64)
			draw_texture_rect_region(tex, Rect2(A6_PADS[i] - Vector2(96, 96), Vector2(192, 192)), src)
	if a6_beam_t > 0.0:
		var bt: Texture2D = PixelArt.load_tex("secret/satellite_uplink_secret_room_beam.png")
		if bt != null:
			var f := int(t * 10.0) % 2
			draw_texture_rect_region(bt, Rect2(A6_BEAM + Vector2(-96, -600), Vector2(192, 1200)), Rect2(f * 32, 0, 32, 32))


func _draw_moon() -> void:
	var tex: Texture2D = PixelArt.load_tex("hazards/well.png")
	if tex == null:
		return
	for c in _well_centers():
		draw_texture_rect_region(tex, Rect2(c - Vector2(A6_WELL_R, A6_WELL_R), Vector2(A6_WELL_R, A6_WELL_R) * 2.0), Rect2((int(t * 8.0) % 8) * 64, 0, 64, 64))


func _draw_mainframe() -> void:
	var cols := ["red", "yellow", "blue"]
	for i in 3:
		_icon("secret/mainframe_secret_room_junction_box_%s.png" % cols[i], A7_BOXES[i], 96.0)
		if a7_wires > i:
			draw_rect(Rect2(A7_BOXES[i] + Vector2(-8, -72), Vector2(16, 16)), Color(0.4, 1.0, 0.6))
	_icon("secret/mainframe_secret_room_keypad.png", A7_KEYPAD, 96.0)
	if a7_key_ok:
		var tex: Texture2D = PixelArt.load_tex("secret/mainframe_secret_room_hq_portal.png")
		if tex != null:
			draw_texture_rect_region(tex, Rect2(A7_PORTAL - Vector2(128, 128), Vector2(256, 256)), Rect2((int(t * 6.0) % 4) * 32, 0, 32, 32))


func _draw_hq() -> void:
	var ids := ["fridge", "phone", "laptop", "office", "datacenter", "satellite"]
	var ports := _hq_portals()
	for i in 6:
		_icon("secret/mainframe_secret_room_portal_%s.png" % ids[i], ports[i], 160.0, Rect2((int(t * 6.0) % 2) * 16, 0, 16, 16))


func _draw_quantum() -> void:
	if a8_spot < 0:
		return
	var tex: Texture2D = PixelArt.load_tex("secret/quantum_core_secret_room_glitch_tile.png")
	if tex != null:
		draw_texture_rect_region(tex, Rect2(A8_SPOTS[a8_spot] - Vector2(128, 128), Vector2(256, 256)), Rect2((int(t * 10.0) % 4) * 64, 0, 64, 64))


func _draw_unobserved() -> void:
	var r: Rect2 = room.bounds
	var tex: Texture2D = PixelArt.load_tex("secret/quantum_core_secret_room_particle_%s.png" % ("a" if int(t * 3.0) % 2 == 0 else "b"))
	if tex != null:
		for i in 40:
			var slot := int(t * 2.0 + i * 0.37)
			var rng := RandomNumberGenerator.new()
			rng.seed = slot * 977 + i * 131
			var pos := r.position + Vector2(rng.randf(), rng.randf()) * r.size
			draw_texture_rect_region(tex, Rect2(pos, Vector2(48, 48)), Rect2((i % 4) * 8, 0, 8, 8))
	var lt: Texture2D = PixelArt.load_tex("secret/quantum_core_secret_room_lucifer_frame.png")
	if lt != null and a8_t > 2.0:
		var c: Vector2 = r.get_center()
		draw_texture_rect_region(lt, Rect2(c + Vector2(-428, -160), Vector2(256, 320)), Rect2(0, 0, 32, 40), Color(1, 1, 1, clampf((a8_t - 2.0) / 1.5, 0.0, 1.0)))


func _draw_exit() -> void:
	if room_id == "upload":
		return
	if room_id == "freezer":
		_draw_portal(_exit_pos(), 112.0)   # a smaller halo, so it stays inside the room
		return
	var c := _exit_pos()
	if room_id == "lounge":   # the way out of the lounge is the open door
		var od: Texture2D = PixelArt.load_tex("secret/office_server_secret_room_lounge_door_open.png")
		if od != null:
			_halo(c, 128.0, Color(1.0, 0.85, 0.5, 0.35 + 0.1 * sin(t * 3.0)))
			draw_texture_rect(od, Rect2(c - Vector2(64, 64), Vector2(128, 128)), false)
		_text("EXIT", c + Vector2(0, 112), 24, Color(1, 1, 1, 0.9))
		return
	if room_id.begins_with("periph_"):   # the same port as the one you came in by (the laptop map), with the laptop icon instead of the plug
		var pf: Texture2D = PixelArt.load_tex("secret/gaming_laptop_secret_room_port_frame.png")
		var lap: Texture2D = load("res://art/devices/laptop.png") as Texture2D   # the device icon of the gaming laptop
		_halo(c, 140.0, Color(0.5, 0.85, 1.0, 0.4 + 0.15 * sin(t * 2.5)))
		if pf != null:
			draw_texture_rect_region(pf, Rect2(c - Vector2(80, 80), Vector2(160, 160)), Rect2((int(t * 6.0) % 4) * 32, 0, 32, 32))
		if lap != null:
			draw_texture_rect(lap, Rect2(c - Vector2(48, 48), Vector2(96, 96)), false)
		_text("LAPTOP", c + Vector2(0, 150), 24, Color(1, 1, 1, 0.9))
		return
	_halo(c, 128.0, Color(1.0, 0.4, 0.4, 0.45 + 0.15 * sin(t * 3.0)))
	var tex: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_exit_portal.png")   # pixel sprite: dark disc, running red rim, white X (tools/gen_secret_fx_art.py)
	if tex != null:
		draw_texture_rect_region(tex, Rect2(c - Vector2(64, 64), Vector2(128, 128)), Rect2((int(t * 8.0) % 4) * 32, 0, 32, 32))
	_text("EXIT", c + Vector2(0, 112), 24, Color(1, 1, 1, 0.9))


## A glow: the dithered pixel disc (fx_halo.png) tinted `col`, 4 screen px per art pixel; `r` is rounded to whole art pixels.
func _halo(c: Vector2, r: float, col: Color) -> void:
	var tex: Texture2D = PixelArt.load_tex("secret/fx_halo.png")
	if tex == null:
		return
	var h := roundf(r / 4.0) * 4.0
	draw_texture_rect(tex, Rect2((c - Vector2(h, h)).snapped(Vector2(4, 4)), Vector2(h, h) * 2.0), false, col)


## A line made of whole squares (`sz` screen px), like the weapon FX: no smooth strokes.
func _pix_line(a: Vector2, b: Vector2, col: Color, sz := 8.0) -> void:
	var n := maxi(1, ceili(a.distance_to(b) / sz))
	for i in n + 1:
		var q := a.lerp(b, float(i) / n).snapped(Vector2(sz, sz))
		draw_rect(Rect2(q - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)


## An arc made of whole squares.
func _pix_arc(c: Vector2, rad: float, a0: float, a1: float, col: Color, sz := 8.0) -> void:
	var n := maxi(2, ceili(absf(a1 - a0) * rad / sz))
	for i in n + 1:
		var q := (c + Vector2.from_angle(lerpf(a0, a1, float(i) / n)) * rad).snapped(Vector2(sz, sz))
		draw_rect(Rect2(q - Vector2(sz, sz) * 0.5, Vector2(sz, sz)), col)


func _draw_portal(c: Vector2, glow_r := 170.0) -> void:
	var tex: Texture2D = PixelArt.load_tex("secret/smart_fridge_secret_room_freezer_portal.png")
	if tex == null:
		return
	var f := int(t * 8.0) % 4
	var gp := 0.5 + 0.5 * sin(t * 2.5)
	for i in 4:   # a pulsing halo of cold light centred on the portal
		draw_circle(c, glow_r - glow_r * 0.2 * i, Color(0.55, 0.9, 1.0, (0.035 + 0.03 * gp) * (i + 1)))
	draw_texture_rect_region(tex, Rect2(c - Vector2(64, 64), Vector2(128, 128)), Rect2(f * 32, 0, 32, 32))


func _draw_frozen(id: String, c: Vector2, prog: float, pulse: float) -> void:
	var tex: Texture2D = PixelArt.load_tex("secret/smart_fridge_secret_room_%s_frozen.png" % ("golem" if id == "golem" else "window"))
	if tex == null:
		return
	var k: float = PixelArt.boss_scale(id, BossData.SECRET[id].get("vis_radius", BossData.SECRET[id]["radius"]))
	var f := int(t * 2.5) % 2
	var size := Vector2(40, 40) * k
	var st := int(prog * THAW_STAGES)
	var jit := Vector2(sin(t * 80.0), cos(t * 65.0)) * (2.0 * st + 8.0 * pulse)   # a tremor that grows with each stage, and a hard shake on each crack
	var tint := Color(1, 1, 1).lerp(Color(2.2, 2.4, 2.6), pulse)
	draw_texture_rect_region(tex, Rect2(c - size * 0.5 + jit, size), Rect2(f * 40, 0, 40, 40), tint)
	for ci in st:   # one more crack across the ice at every stage
		var a := 1.3 + ci * 2.2
		var pts := PackedVector2Array()
		var q := c + jit
		for n in 5:
			var wob := 0.0 if n == 0 else (0.35 if n % 2 == 0 else -0.35)
			pts.append(q + Vector2.from_angle(a + wob) * size.x * 0.09 * n)
		draw_polyline(pts, Color(0.1, 0.25, 0.4, 0.8), 9.0)
		draw_polyline(pts, Color(0.9, 1.0, 1.0, 0.95), 4.0)


## The opening animation of an app icon: the icon swells and glows, and a ring fills clockwise around the block.
func _draw_open_ring(rc: Rect2, k: float) -> void:
	var c := rc.get_center()
	var ico: Texture2D = game.main_arena.icon_for_block(rc)
	if ico != null:
		draw_texture_rect(ico, rc.grow(-ICON_INSET + 36.0 * k), false, Color(1, 1, 1, 0.35 * k))
	var rad := rc.size.x * 0.5 + 40.0
	_pix_arc(c, rad, 0.0, TAU, Color(1, 1, 1, 0.12))
	_pix_arc(c, rad, -PI / 2.0, -PI / 2.0 + TAU * k, Color(0.5, 0.9, 1.0, 0.95))


## Floor decoration of the app rooms, one motif each (drawn over the floor, under the walls and items).
func _draw_app_decor(theme: String, rb: Rect2) -> void:
	var c := rb.get_center()
	match theme:
		"messages":   # typing dots drifting up the left lane
			for i in 3:
				var k := fposmod(t * 0.6 - i * 0.18, 1.0)
				var dt: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_dot.png")
				if dt != null:
					draw_texture_rect(dt, Rect2((c + Vector2(-780 + i * 46, 300 - k * 80)).snapped(Vector2(4, 4)) - Vector2(32, 32), Vector2(64, 64)), false, Color(0.7, 1.0, 0.85, 0.7 * sin(k * PI)))
		"clock":   # the big pixel dial (smartphone_secret_room_clock_face.png) with hands that follow the real time
			var face: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_clock_face.png")
			if face != null:
				draw_texture_rect(face, Rect2(c - Vector2(380, 380), Vector2(760, 760)), false, Color(1, 1, 1, 0.92))
			var now := Time.get_time_dict_from_system()
			var sec: float = float(now["second"]) + fposmod(Time.get_ticks_msec() / 1000.0, 1.0)
			var mn: float = float(now["minute"]) + sec / 60.0
			var hr: float = float(int(now["hour"]) % 12) + mn / 60.0
			var dark := Color(0.04, 0.05, 0.14)
			_pix_line(c, c + Vector2.from_angle(hr / 12.0 * TAU - PI / 2.0) * 190.0, dark, 16.0)
			_pix_line(c, c + Vector2.from_angle(mn / 60.0 * TAU - PI / 2.0) * 280.0, dark, 12.0)
			_pix_line(c, c + Vector2.from_angle(sec / 60.0 * TAU - PI / 2.0) * 300.0, Color(0.85, 0.2, 0.2), 8.0)
		"music":   # equaliser bars on the floor, bouncing
			for i in 18:
				var h := 40.0 + 90.0 * (0.5 + 0.5 * sin(t * 4.0 + i * 0.9)) * (0.5 + 0.5 * sin(i * 1.7))
				var x := -1000.0 + i * 118.0
				var cell: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_eq_cell.png")   # bars are stacks of 16x8 pixel cells
				if cell != null:
					for k in int(h / 32.0) + 1:
						draw_texture_rect(cell, Rect2(c + Vector2(x, 640.0 - 32.0 * (k + 1)), Vector2(64, 32)), false, Color(1.0, 0.5, 0.85, 0.35))
		"weather":   # rain falling from the cloud
			for i in 60:
				var x := -1000.0 + fmod(i * 197.0, 2000.0)
				var y := -520.0 + fposmod(t * (260.0 + (i % 5) * 40.0) + i * 83.0, 1100.0)
				var rt: Texture2D = PixelArt.load_tex("secret/smartphone_secret_room_rain.png")
				if rt != null:
					draw_texture_rect(rt, Rect2((c + Vector2(x, y)).snapped(Vector2(4, 4)), Vector2(16, 48)), false, Color(0.7, 0.85, 1.0, 0.45))


## The corrupted app's look: the pixel-art floor and walls carry the glitch; on top, whole 12px squares of the tile flicker magenta/cyan
## (stepped 8 times a second, more of them in later waves). No washes, no smooth bars.
func _draw_glitch(r: Rect2, level := 0) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = int(t * 8.0) * 7919 + 13
	for i in 14 + level * 8:
		var cell := Vector2(floorf(rng.randf() * r.size.x / 12.0), floorf(rng.randf() * r.size.y / 12.0)) * 12.0
		var w := 12.0 * (1 + rng.randi() % 5)
		var col := Color("2ff0e0") if rng.randf() < 0.5 else Color("ff4fb8")
		draw_rect(Rect2(r.position + cell, Vector2(w, 12.0)), Color(col, 0.35))


## The freezer's cold look: an icy blue wash over the floor and a frosted rim along the walls of the room.
func _draw_cold(r: Rect2) -> void:
	draw_rect(r, Color(0.35, 0.6, 1.0, 0.24))
	var rim := 90.0
	for i in 6:
		var a := 0.03 * (6 - i) / 6.0
		var w := rim * (i + 1) / 6.0
		draw_rect(Rect2(r.position, Vector2(r.size.x, w)), Color(0.8, 0.95, 1.0, a))
		draw_rect(Rect2(Vector2(r.position.x, r.end.y - w), Vector2(r.size.x, w)), Color(0.8, 0.95, 1.0, a))
		draw_rect(Rect2(r.position, Vector2(w, r.size.y)), Color(0.8, 0.95, 1.0, a))
		draw_rect(Rect2(Vector2(r.end.x - w, r.position.y), Vector2(w, r.size.y)), Color(0.8, 0.95, 1.0, a))
