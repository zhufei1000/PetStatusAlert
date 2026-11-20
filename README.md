# PetStatusAlert 1.8.1
Alerts for supported pet classes and Warrior stance mistakes. Pet alerts cover Hunter, Warlock, Unholy DK, and Frost Mage Water Elemental states (Passive, Defensive, Dead, or Missing) with optional combat TTS. Arms and Fury Warriors are warned while Defensive Stance is active. Supports EN/zhCN/zhTW/RU and Warlock Grimoire of Sacrifice.

Forever (Interface 16001): pet alerts use learned summon abilities rather than specializations. Passive and Defensive trigger alerts by default. Aggressive is off by default and can be enabled in the class settings. Missing and dead pet alerts remain available. Mage alerts require the Water Elemental summon ability.

On both clients, the missing-pet alert waits two seconds after you dismount to give your pet time to return. Entering combat checks immediately. Death and pet mode alerts do not wait.

**Forever → Warrior** lets you select which active stances should trigger an alert. Each starts off. Right-click a visible stance alert icon to change the selection.

Open `/psa` or the settings button in QFXAddonManager. Choose **Retail** or **Forever** above the navigation. **Pet Alerts** groups the supported classes with display and voice settings. The other client tab shows read-only defaults for its classes and features.

Open **Animation** for the global pixel glow and vertical motion controls. The glow refresh slider ranges from 10 to 30 updates per second for the main icon (20 by default); accessory icons use about 75% of the selected rate.

Each reminder uses its own switch or threshold. Per-alert choices, custom text, colors, and the ammo threshold are preserved; former master switch values are ignored.

Install both `PetStatusAlert` and `PetStatusAlert_Config` from the package. The companion loads its widgets the first time you open settings.

The **Warlock** page groups the wrong-summon switch and demon choices together. Sayaad covers both Succubus and Incubus. Retail saves a list for each specialization and suppresses the warning by default when the configured Grimoire of Sacrifice talent is active. Its talent ID is under **Advanced**. Forever uses one list. The **Mage** page lets you change or disable the Water Elemental requirement. Its default ID is 31687. The bottom of each editable class page has a class-only reset for alert switches, text, colors, and rules.

Under **General → Position and preview**, you can preview or move the on-screen alerts and reset their position. The preview works on any class and stays visible while you adjust **Display** or **Animation**. **Voice** lets you listen outside combat and choose between a single announcement and repeating every 2–15 seconds. The default remains every 3 seconds. Alerts without visible text are silent.

Open **Forever → Ammo** to turn the low ammo alert on or off and set its threshold (100 by default). The alert is on by default. Turning it off keeps your threshold. Bows, crossbows, and guns that require ammo are checked after combat; the icon shows the remaining count when it falls below the threshold.

**Forever → Hunter Tools → Combat Aspect** has its own switch. The reminder appears in combat only while your own Aspect of the Cheetah or Aspect of the Pack is active. It suggests Aspect of the Falcon if learned, or the highest known rank of Aspect of the Hawk. Switching aspects or leaving combat clears the icon.

**Forever → Pet Alerts → Hunter → Pet autocast** reminds you to turn Growl on outdoors while solo or in a party, and off in a dungeon or raid, including when your group is a raid outdoors. If your pet knows Cower, the reminder checks it against Growl's current autocast setting and only shows it after Growl matches its rule. The icon shows `+` to turn autocast on or `-` to turn it off. Right-click the actual skill on the pet bar or in your pet spellbook to switch it.

Under **Forever → Hunter Tools → One-click pet feeding**, the feed button and the unhappy pet reminder have separate switches. Choose food automatically or select a suitable item from your bags. Hunters can also right-click the on-screen pet food icon to choose and left-click to feed out of combat.
When the pet needs feeding and your bags have no suitable food, the feed reminder shows a gray icon with a red **0** and an explanation on hover. While your pet is eating, the feed reminder stays hidden.

Validation: `lua tests/regressions.lua` and `lua tests/compatibility.lua`. In game, verify missing/dead pets, each available pet mode, learning a summon ability, mounting/dismounting, combat TTS, and `/reload` on both clients.

The automated checks use mocked game APIs. In-game verification on Forever, including the summon spell IDs on live characters, is pending.
