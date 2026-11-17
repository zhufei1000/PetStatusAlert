# PetStatusAlert 1.7.0
Alerts for supported pet classes and Warrior stance mistakes. Pet alerts cover Hunter, Warlock, Unholy DK, and Frost Mage Water Elemental states (Passive, Defensive, Dead, or Missing) with optional combat TTS. Arms and Fury Warriors are warned while Defensive Stance is active. Supports EN/zhCN/zhTW/RU and Warlock Grimoire of Sacrifice.

Forever (Interface 16001): pet alerts use learned summon abilities rather than specializations. Passive and Defensive trigger alerts by default. Aggressive is off by default and can be enabled in the class settings. Missing and dead pet alerts remain available. Mage alerts require the Water Elemental summon ability.

**Forever → Warrior** lets you select which active stances should trigger an alert. Each starts off. Right-click a visible stance alert icon to change the selection.

Open `/psa` or the settings button in QFXAddonManager. Choose **Retail** or **Forever** above the navigation. **Pet Alerts** groups the supported classes with display and voice settings. The other client tab shows read-only defaults for its classes and features.

Each reminder uses its own switch or threshold. Per-alert choices, custom text, colors, and the ammo threshold are preserved; former master switch values are ignored.

Install both `PetStatusAlert` and `PetStatusAlert_Config` from the package. The companion loads its widgets the first time you open settings.

The **Warlock** page groups the wrong-summon switch and demon choices together. Sayaad covers both Succubus and Incubus. Retail saves a list for each specialization and suppresses the warning by default when the configured Grimoire of Sacrifice talent is active. Its talent ID is under **Advanced**. Forever uses one list. The **Mage** page lets you change or disable the Water Elemental requirement. Its default ID is 31687. The bottom of each editable class page has a class-only reset for alert switches, text, colors, and rules.

**Display** has a preview you can start or stop while adjusting the settings, on any class. **Voice** lets you listen outside combat and choose between a single announcement and repeating every 2–15 seconds. The default remains every 3 seconds. Alerts without visible text are silent.

Open **Forever → Ammo** to set the low ammo threshold. Bows, crossbows, and guns that require ammo are checked after combat. The icon shows the remaining count when it falls below the threshold (100 by default); set it to 0 to disable the warning.

**Forever → Hunter Tools → Combat Aspect** has its own switch. The reminder appears in combat only while your own Aspect of the Cheetah or Aspect of the Pack is active. It suggests Aspect of the Falcon if learned, or the highest known rank of Aspect of the Hawk. Switching aspects or leaving combat clears the icon.

Under **Forever → Hunter Tools → One-click pet feeding**, the feed button and the unhappy pet reminder have separate switches. Choose food automatically or select a suitable item from your bags. Hunters can also right-click the on-screen pet food icon to choose and left-click to feed out of combat.

Validation: `lua tests/regressions.lua` and `lua tests/compatibility.lua`. In game, verify missing/dead pets, each available pet mode, learning a summon ability, mounting/dismounting, combat TTS, and `/reload` on both clients.

The automated checks use mocked game APIs. In-game verification on Forever, including the summon spell IDs on live characters, is pending.
