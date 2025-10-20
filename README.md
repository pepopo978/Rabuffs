# WARNING
This version is not backwards compatible with the original - it uses a new format in the WTF file as the original was very impractical to work with.

I would recommend backing up your WTF folder or SavedVariables\Rabuffs.lua in case you ever want to revert.

# Pepo Changes

- All buffs can be toggled self only rather than having two versions
- Options for hiding in combat and hiding buffs that are active
- Reorganized all the buff menus to make it easier to find things
- Made settings window draggable
- Ability to ignore player names on specific buffs
- Better identification of buffs with the same texture/tooltip
- Added profile system to save and load buff sets

# RABuffs

An addon to track raid wide and your personal buffs and personal weapon enchants.

It provides a panel of clickable buttons that light up when a buff is found.

You can click on the panel to buff up, which saves space from your action bars.

A lot of the functionality is also available in macros via the /rab and /rabq commands.

There is also an addon based on Rabuffs that can log buffs to a file for tracking https://github.com/Loogosh/Rabuffs_Logger.

## Slash Commands

### Basic Commands (`/rab` or `/rabuffs`)

- `/rab` - Show help and available commands
- `/rab show` - Display the RABuffs UI frame (if hidden)
- `/rab hide` - Hide the RABuffs UI frame
- `/rab info` - Display buff/debuff texture names on your current target
- `/rab versioncheck [target]` - Check RABuffs versions
  - `/rab versioncheck` - Check raid/party (default based on group type)
  - `/rab versioncheck raid` - Check current raid
  - `/rab versioncheck party` - Check current party
  - `/rab versioncheck guild` - Check guild members
  - `/rab versioncheck PlayerName` - Check specific player via whisper

### Profile Management (`/rab profile`)

- `/rab profile` - Show profile command help
- `/rab profile list` - List all available profiles
- `/rab profile current` - Show current active profile
- `/rab profile save <name>` - Save current bars to named profile
- `/rab profile load <name>` - Load named profile
- `/rab profile delete <name>` - Delete named profile

### Advanced Commands

- `/rab hookchat` - Toggle chat frame event hooking
- `/rab regtest` - Perform query regression test (debug)
- `/rab coreinfo` - Display core addon information

### Buff Query Commands (`/rabq` or `/rq`)

Query and report buff status with flexible targeting:

- `/rabq [target] <query> [groups] [classes]`

**Target Options:**
- (none) - Output to console/chat
- `raid` - Output to raid chat
- `party` - Output to party chat
- `officer` - Output to officer chat
- `w PlayerName` - Whisper to player
- `c ChannelName` - Output to channel

**Query Examples:**
- `/rabq motw` - Check Mark of the Wild (console)
- `/rabq raid fort` - Check Fortitude to raid chat
- `/rabq party not pws` - Check who's missing Power Word: Shield
- `/rabq officer ai 12 mp` - Check Arcane Intellect on groups 1-2, mages and priests only

**Group Limits:** Numbers 1-8 (e.g., `12345` for groups 1-5)

**Class Limits:** Letters for each class
- `m` = Mage
- `l` = Warlock  
- `p` = Priest
- `r` = Rogue
- `d` = Druid
- `h` = Hunter
- `s` = Shaman
- `w` = Warrior
- `a` = Paladin

Use `not` prefix to invert queries (show who's missing the buff).

![screenshot](ss.png?raw=true "screenshot")
![screenshot2](ss2.png?raw=true "screenshot2")
