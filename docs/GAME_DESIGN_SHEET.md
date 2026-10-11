# Kernel Panic: Design Sheet (classes, weapons, prestige, devices)

Generated 2026-10-08 from the Godot project. **Edit anything in the tables, write your changes in the "CHANGE" column or right in the cell, and send the file back.** Where a cell says *(code)* it is a rule that lives in a script rather than in a table; say what you want and it will be wired up.

Source files: `classes.gd`, `meta.gd` (WEAPON_SOURCE, CLASS_SOURCE, SECRET_CLASSES), `tree_data.gd`, `evolutions.gd`, `challenges.gd`, `achievements.gd`, `game.gd` (DEVICE_POOLS, WEAPONS), `boss_data.gd`, `hazards.gd`, `maps_data.gd`.

How unlocking works today:
- **DATA** = bought with DATA in the research tree (must be bought again after every reformat).
- **Prestige** = a license bought with prestige points (PP), kept through reformats; the class/weapon is then bought with DATA.
- **Challenge** = complete a challenge once; it grants permission to buy.
- **Secret** = found by doing something in a run; never hinted in game.
- Unlocks only grant *permission to buy*. Base weapons are bought; evolved weapons are found in a run.

---

## 1. Classes

| Class | Starting weapon | Passive | Ability (cooldown) | Unlock source today | Unlock condition | CHANGE |
|---|---|---|---|---|---|---|
| BASIC | PACKET LASER | none | PURGE: wipe every threat on screen, not bosses (60s, charges only) | always | none | |
| SYSADMIN | FIREWALL | +25 max HP, +0.3 HP/s | RESTORE: heal 40% max HP, 1.5s invulnerable (60s) | DATA | buy in CLASSES tree (cost x136) | |
| HACKER | BACKDOOR | +10% crit, +20% crit dmg | OVERCLOCK: +50% weapon speed 6s (45s) | DATA | buy in CLASSES tree (cost x340) | |
| ARCHITECT | LOGIC BOMB | +20% area, +20% duration | LOCKDOWN: slow and hit everything nearby for 4s (60s) | Prestige | ARCHITECT LICENSE (10 PP), then buy (x680) | |
| GHOST | PING.EXE | +10% move speed, +8% dodge | PHASE: dash forward, untouchable 1.5s (20s) | Challenge | GLASS CANNON: max HP 35%, defeat 2 bosses; then buy (x1020) | |
| ANALYST | SCANNER | +25% XP, +8% luck | DEEP SCAN: threats take +25% damage 8s (40s) | Challenge | SINGLE THREAD: only PACKET LASER, survive 6 min; then buy (x1360) | |
| PACIFIST | none (no weapon) | +30% XP, +10% luck | PAUSE: stop time 4s (60s) | DATA | buy in CLASSES tree (cost x340) | |
| RAILGUNNER (secret) | RAILGUN | +15% crit, +30% crit dmg | RAIL STRIKE: piercing beam, guaranteed heavy crit (30s) | Secret | evolve RAILGUN, then survive 6 min taking 5 hits or fewer; then buy (x1700) | |
| ARSONIST (secret) | SCORCHED EARTH | +25% area, +25% duration | WILDFIRE: ignite everything nearby, 6s burn (50s) | Secret | evolve SCORCHED EARTH and delete 1500 threats in one run; then buy (x1700) | |
| STORMCALLER (secret) | TESLA GRID | +10% move speed, +20% XP | THUNDERSTORM: 6s of bolts every 0.35s (45s) | Secret | evolve TESLA GRID and reach a x50 combo; then buy (x1700) | |
| CRYOMANCER (secret) | ABSOLUTE ZERO | +30 max HP, +5% dodge | DEEP FREEZE: freeze everything nearby 3s, bosses slowed (55s) | Secret | evolve ABSOLUTE ZERO and survive 10 min; then buy (x1700) | |

Class extras (code): each class has a TRAINING node (+10% per rank to its passives, 5 ranks, cost x20). Every class can use the shared ability upgrades HOT SWAP (-4% cooldown per rank), CAPACITOR (+1 stored charge, 2 ranks) and PHASE LOCK (SUPER window earlier, 4 ranks). A SUPER cast is a second tap in the ring window: x1.5 strength, 2s invulnerability, half the cooldown back.

Roadmap targets for classes: two egg classes, one achievement class (nothing built yet). Your notes:

> 

---

## 2. Weapons

Base weapons (all are plain DATA buys today; `Meta.WEAPON_SOURCE` is empty on purpose).

| Weapon | Type | What it does | Unlock source today | Unlock condition | Mastery | CHANGE |
|---|---|---|---|---|---|---|
| PACKET LASER | Base (starting) | Data bolts at the nearest threat | always owned | none | LASER MASTERY (+10%/rank, 5) | |
| FIREWALL | Base | Burning ring around you | DATA | buy in ARSENAL | FIREWALL MASTERY (3 ranks) | |
| ENCRYPTION KEYS | Base | Crystal shards orbit you | DATA | buy in ARSENAL | KEY MASTERY (3 ranks) | |
| PING.EXE | Base | Chain lightning between threats | DATA | buy in ARSENAL | PING MASTERY (3 ranks) | |
| LOGIC BOMB | Base | Proximity mines | DATA | buy in ARSENAL | BOMB MASTERY (5 ranks) | |
| SCANNER | Base | Radar beams sweep around you | DATA | buy in ARSENAL | SCANNER MASTERY (5 ranks) | |
| BACKDOOR | Base | Boomerang discs hit twice | DATA | buy in ARSENAL | BACKDOOR MASTERY (6 ranks) | |
| QUARANTINE | Base | Freezing zones slow and damage groups | DATA | buy in ARSENAL | QUARANTINE MASTERY (6 ranks) | |

Evolutions (found in a run, kept forever once found; the evolved weapon then also appears as a card and gets a DATA mastery).

| Weapon | Type | Recipe (all at level 10 + item) | What it does | Unlock condition | CHANGE |
|---|---|---|---|---|---|
| RAILGUN | Evolution | PACKET LASER + BACKDOOR + DRONE item | Piercing beam through everything in a line | Meet the recipe in a run; Legendary EVOLVE card then offered (50% chance) | |
| SCORCHED EARTH | Evolution | FIREWALL + LOGIC BOMB + TOTEM item | Huge burning ring that ignites and erupts | same | |
| TESLA GRID | Evolution | PING.EXE + SCANNER + CHAIN item | Lightning on many threats at once, shocks them | same | |
| ABSOLUTE ZERO | Evolution | QUARANTINE + ENCRYPTION KEYS + SHATTER item | Persistent frost area around you that pulses periodically (rim flares, area swells), freezing everything inside | same | |

Weapon-wide research (code): INFECTION TRANSMISSION (+25% status chance), TOXIC PERSISTENCE (prestige, +40% status duration), EXPANSION SLOT (5th weapon slot), PRE-INSTALLED (starting weapon begins at higher level), EVOLUTION (prestige, weapons level beyond 10), OMNI-ARSENAL (prestige, +5% all weapon damage, 25 ranks).

Roadmap targets for weapons: one prestige-license weapon, 2 to 3 challenge weapons, 2 to 3 egg weapons, optional device-cure gate (`WEAPON_CURE_REQ`). Your notes:

> 

---

## 3. Prestige nodes (bought with PP, kept through every reformat)

Default price by ring if no base is given: ring 1 = 2 PP, ring 2 = 2 PP, ring 3 = 5 PP (code, `pp_base`). Nodes with a listed base price are shown.

| Node | Branch | Effect | Max rank | Base PP | Unlock condition | CHANGE |
|---|---|---|---|---|---|---|
| QUANTUM ALGORITHMS | Offense | +8% damage | 10 | default | root of prestige tree | |
| ERROR CORRECTION | Defense | +20 max HP, +0.2 HP/s | 10 | default | root | |
| COMPRESSION | Utility | +20% DATA | 10 | default | root | |
| TOXIC PERSISTENCE | Arsenal | +40% status duration | 1 | default | root | |
| SUPERUSER | System | +1 reroll, +8% luck | 5 | default | root | |
| ANNIHILATOR | Offense | +15% crit damage | 10 | default | needs QUANTUM ALGORITHMS | |
| IMMORTAL PROCESS | Defense | +1 revive per run | 1 | default | needs ERROR CORRECTION | |
| HYPERDRIVE | Utility | +3% move speed, +5% XP | 10 | default | needs COMPRESSION | |
| EVOLUTION | Arsenal | weapons level 1 beyond LV 10 | 2 | default | needs TOXIC PERSISTENCE | |
| MULTIVERSE | System | +1 card in every upgrade offer | 1 | default | needs SUPERUSER | |
| INFINITE RECURSION | Offense | +5% damage | 25 | default | needs ANNIHILATOR | |
| ETERNAL UPTIME | Defense | +15 max HP | 25 | default | needs IMMORTAL PROCESS | |
| ENDLESS STREAM | Utility | +15% DATA | 25 | default | needs HYPERDRIVE | |
| OMNI-ARSENAL | Arsenal | +5% damage for every weapon | 25 | default | needs EVOLUTION | |
| DEUS EX MACHINA | System | +5% luck, -1% cooldowns | 25 | default | needs MULTIVERSE | |
| ARCHITECT LICENSE | Arsenal | lets you buy the ARCHITECT class | 1 | 10 | root | |
| TIME DILATION | Offense | unlocks SPEED RUN on cured devices | 1 | 4 | root | |
| THREAT ANALYSIS | Offense | unlocks THREAT LEVEL on cured devices and THE INTERNET | 1 | 6 | root | |
| TRIAL ACCESS | Defense | unlocks CHALLENGES on the device map | 1 | 3 | root | |
| ROOT KEY | Utility | +1% DATA and +1% damage per rank, never ends, price grows | infinite | 2 (+0.4 per rank) | root | |
| PRESTIGE HARVEST | System | +10% chance per rank of an extra PP per cure (100% = guaranteed extra) | infinite | 3 (+0.5 per rank) | root | |
| AUTO-DECRYPT | System | caches open themselves and pick a safe item | 1 | default | needs SUPERUSER | |
| AUTO-UPGRADE | System | level-up cards pick themselves without pausing | 1 | default | needs SUPERUSER | |

Prestige points (PP) come from curing devices (extra from HARD and SPEED RUN, achievements and challenges). Your notes:

> 

---

## 4. Challenges and achievements (unlock sources)

Challenges (need TRIAL ACCESS; 2 exist, roadmap wants about 8):

| Challenge | Rule | Goal | Reward | CHANGE |
|---|---|---|---|---|
| SINGLE THREAD | only the PACKET LASER is offered | survive 6 minutes | ANALYST class permission | |
| GLASS CANNON | max HP is 35% | defeat 2 bosses | GHOST class permission | |

Achievements (rewards are prestige points only today; roadmap wants weapon/class/cosmetic rewards):

| Group | Achievements (PP reward) | CHANGE |
|---|---|---|
| Kills (lifetime) | EXTERMINATOR 1,000 (1), PEST CONTROL 10,000 (2), EXTINCTION EVENT 100,000 (4) | |
| Runs (lifetime) | FIRST BOOT 1 (1), REGULAR 10 (1), UPTIME ADDICT 50 (2) | |
| Bosses (lifetime) | BUG BOUNTY 10 (1), BOSS RUSH 50 (2), GIANT KILLER 200 (4) | |
| Cures (lifetime) | PATIENT ZERO 1 (1), SYSADMIN 5 (2), CHIEF SECURITY OFFICER 20 (4) | |
| DATA (lifetime) | BYTE SIZED 10k (1), DATA HOARDER 1M (2), BIG DATA 100M (4) | |
| Survive in one run | STILL STANDING 5 min (1), LONG UPTIME 10 min (1), NINES 15 min (2) | |
| Level in one run | UPGRADED 10 (1), FULLY PATCHED 20 (2) | |
| Combo | ON A ROLL x50 (1), UNSTOPPABLE x150 (2) | |
| Skill | FLAWLESS cure without a hit (3), ARMORY hold 5 weapons (1), MINIMALIST cure holding 1 weapon (3) | |
| Overtime | OVERTIME 3 min (2), DOUBLE SHIFT 10 min (4) | |
| Class cures | cure a device as SYSADMIN / HACKER / ARCHITECT / GHOST / ANALYST (2 each); survive 5 min as PACIFIST (2) | |
| Modes | NO MERCY cure on HARD (3), OVERCLOCKED cure in SPEED RUN (2), SURFING 15 min on THE INTERNET (3) | |

---

## 5. Devices

Each device multiplies enemy health and damage (about x2 HP and x1.8 damage per device) and DATA (x2 per device). Boss slots: 3 mid-bosses at 3:00, 6:00, 9:00 (random from the 6 mid-bosses, health scaled by slot) and the device's final boss at 12:00, then overtime. Regular enemies are limited to the device pool; 3 types are live at once, a new one arrives every 2 minutes. Map sizes below are the new x2-per-side scale (4x the area of before).

| # | Device | Map design | Map size (px) | Enemy pool | Final boss | Hazard | Boss room |
|---|---|---|---|---|---|---|---|
| 1 | SMART FRIDGE | Two long shelves with gaps on opposite ends, two door posts. Teal frost palette, falling snow background | 11560 x 7820 | BUG, WORM, MITE, ADWARE, TROJAN, SPYWARE, RANSOMWARE | ROOT KERNEL | FROST PATCHES (fixed): slow you | two shelf posts |
| 2 | SMARTPHONE | Grid of square app-icon pillars around an open centre. Blue palette, floating icons | 10200 x 9520 | BUG, MITE, ADWARE, ZIP BOMB, SPYWARE, SENTRY, NANOBOT, RAM, ROOTKIT | BASEBAND | SIGNAL JAMMERS (fixed): slow your weapons | four app pillars |
| 3 | GAMING LAPTOP | Rows of key blocks across the top, touchpad slab at the bottom. Purple palette, pressing key caps | 11900 x 7820 | BUG, WORM, TROJAN, MINER, ZIP BOMB, LEECH, RAM, RANSOMWARE, ROOTKIT | BLUE SCREEN | HEAT VENTS (event): burst and burn near you | key blocks |
| 4 | OFFICE SERVER | Staggered rack columns making a snaking corridor maze. Green palette, data pulses | 12240 x 8160 | BUG, WORM, TROJAN, MINER, SENTRY, NANOBOT, LEECH, BOTNET, ROOTKIT | ROOT KERNEL | LIVE WIRES (fixed): lightning + shock | two racks |
| 5 | DATA CENTER | Server-row aisles split by a gap, short blocks forming two halls. Orange palette, heat bands and fans | 12920 x 8840 | WORM, MITE, SPYWARE, MINER, ZIP BOMB, SENTRY, LEECH, NANOBOT, RANSOMWARE | BASEBAND | COOLING FANS (fixed): wind pushes you | two aisle rows |
| 6 | SATELLITE UPLINK | Central dish with solar-panel walls around it, player starts south. Red palette, stars | 11560 x 11560 | BUG, MITE, ADWARE, ZIP BOMB, SENTRY, LEECH, NANOBOT, RAM, ROOTKIT, RANSOMWARE | BLUE SCREEN | ORBITAL STRIKES (event): giant laser beam | the dish |
| 7 | MAINFRAME | Three nested square rooms, doors on alternating sides. Cyan palette, falling code | 12240 x 12240 | WORM, TROJAN, SPYWARE, MINER, ZIP BOMB, NANOBOT, BOTNET, RAM, ROOTKIT, RANSOMWARE | ROOT KERNEL | GRAVITY WELLS (fixed): pull you in | (see `maps_data.room`) |
| 8 | QUANTUM CORE | Two wall sets swapping every 7s (vertical then horizontal bars) plus fixed pillars. White palette, pulsing rings | 10880 x 10880 | every enemy kind | BASEBAND | QUANTUM FLUX (event): weapons swing fast/slow | (see `maps_data.room`) |
| ∞ | THE INTERNET | Endless chunked map, unlocked by curing the OFFICE SERVER; no cure, no PP, DATA x0.8 | endless | every enemy kind | none (overtime rules) | MIXED: all fixed kinds in chunks + vents, strikes and flux rifts | n/a |

Fixed hazards sit at the same spots every run (about one per 2.2 million px², 10 to 28 per arena). Event hazards pop up near you; THREAT LEVEL (0 to 5) makes them more frequent, bigger and burstier.

**Enemy kinds (16):** BUG fast zig-zagger, WORM chaser, MITE fast pack lunger (packs of 5+), ADWARE splits into POPUPs, POPUP, TROJAN tank, SPYWARE ranged kiter, MINER wanderer with big XP, ZIP BOMB arming blast, SENTRY warping turret, LEECH latching healer, NANOBOT laser sniper, BOTNET dasher, RAM charger, RANSOMWARE giant brute, ROOTKIT teleporter.
**Elite modifiers (5):** SWIFT, ARMORED, VAMPIRIC, SUMMONER, VOLATILE. Chance per regular enemy: +6% per device after the first, +3% per threat level, max 45%.

**Mid-bosses (6):** MEGAWORM (summons bugs, dashes), THE LOCKER (radial and aimed shots, calls trojans), BOTNET HIVE (dashes, summons botnets), POP-UP KING (floods popups), KEYLOGGER (kites, fans, blinks), PHISHER (dashes, slams, summons bugs).
**Final bosses (3, cycling):** ROOT KERNEL (fridge, server, mainframe): spirals, rings, kernel minions. BASEBAND (phone, data center, quantum): spirals, fans, spies, blinks. BLUE SCREEN (laptop, satellite): slams, rings, popups.

Your notes for devices (new enemies, bosses per device, map changes, hazards, difficulty curve):

> 

---

## 6. Open questions from the roadmap that depend on this sheet

- Who gets which weapon/class source (the hand-set unlock table, `Meta.WEAPON_SOURCE` / `Meta.CLASS_SOURCE`)?
- Target split: 1 to 3 weapons and classes for DATA, 1 to 3 for prestige, the rest from achievements, challenges or eggs.
- Whether later weapons should need a device cured first (`WEAPON_CURE_REQ`).
