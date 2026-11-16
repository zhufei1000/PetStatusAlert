# PetStatusAlert 1.7.0
Alerts for supported pet classes and Warrior stance mistakes. Pet alerts cover Hunter, Warlock, Unholy DK, and Frost Mage Water Elemental states (Passive, Defensive, Dead, or Missing) with optional combat TTS. Arms and Fury Warriors are warned while Defensive Stance is active. Supports EN/zhCN/zhTW/RU and Warlock Grimoire of Sacrifice.

Forever (Interface 16001): pet alerts use learned summon abilities rather than specializations. Passive and Defensive trigger alerts by default. Aggressive is off by default and can be enabled in the class settings. Missing and dead pet alerts remain available. Mage alerts require the Water Elemental summon ability. Retail Grimoire of Sacrifice talent IDs and live Warrior stance alerts are disabled in Forever.

Open `/psa` or the settings button in QFXAddonManager. Expand **Class Settings**, select a class, then switch between **Retail** and **Forever**. The active client saves alert switches, custom messages, and colors per class and uses existing shared values until a class setting is edited. The other client tab shows its read-only defaults.

The **Warlock** page groups the wrong-summon switch and demon choices together. Sayaad covers both Succubus and Incubus. Retail saves a list for each specialization and suppresses the warning by default when the configured Grimoire of Sacrifice talent is active. Its talent ID is under **Advanced**. Forever uses one list. The **Mage** page lets you change or disable the Water Elemental requirement. Its default ID is 31687. The bottom of each editable class page has a class-only reset for alert switches, text, colors, and rules.

**Display** has a preview you can start or stop while adjusting the settings, on any class. **Voice** lets you listen outside combat and choose between a single announcement and repeating every 2–15 seconds. The default remains every 3 seconds. Alerts without visible text are silent.

In Retail, **Buff Alerts → Class Buffs** shows missing buffs that suit your specialization when you or a group member can provide them. Click to cast a buff you know or to ask an eligible teammate by whisper. **Food & Weapons** has separate warning times for Well Fed and temporary weapon enhancements. Set either to 0 for missing-only alerts. Shaman characters also have an **Enhancement Shaman** tab for main-hand Windfury Weapon and off-hand Flametongue Weapon.

In Forever, use **Buff Alerts → Food** to enable the optional player food buff reminder. It checks outside combat and rest areas. Below max level it also mentions the +5% kill XP from XP food. **Buff Alerts → Ammo** applies to bows, crossbows, and guns. The threshold defaults to 100, and 0 disables the alert. Food and ammo reminders share a supply row. Unlock positions under **Display** to drag the supply row and the pet alert separately.

With **Click to eat** enabled and the supply row locked, right-click the missing food buff icon to choose usable buff food from your bags. Left-click to eat the selection. Your character keeps the choice after relogging or running out. The menu reads your bags only while open.

Under **Hunter → Forever → One-click pet feeding**, the feed button and the unhappy pet reminder have separate switches. Choose food automatically or select a suitable item from your bags. Hunters can also right-click the on-screen pet food icon to choose and left-click to feed out of combat.

Validation: `lua tests/regressions.lua` and `lua tests/compatibility.lua`. In game, verify missing/dead pets, each available pet mode, learning a summon ability, mounting/dismounting, combat TTS, and `/reload` on both clients.

The automated checks use mocked game APIs. In-game verification on Forever, including the summon spell IDs on live characters, is pending.
