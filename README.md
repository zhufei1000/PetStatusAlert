# PetStatusAlert 1.5.6
Alerts for supported pet classes and Warrior stance mistakes. Pet alerts cover Hunter, Warlock, Unholy DK, and Frost Mage Water Elemental states (Passive, Defensive, Dead, or Missing) with optional combat TTS. Arms and Fury Warriors are warned while Defensive Stance is active. Supports EN/zhCN/zhTW/RU and Warlock Grimoire of Sacrifice.

Forever (Interface 16001): pet alerts use learned summon abilities rather than specializations. Only Assist is normal; Passive, Defensive, and Aggressive can trigger alerts. Missing and dead pet alerts remain available. Mage alerts require the Water Elemental summon ability. Retail Grimoire of Sacrifice talent IDs are not used, and Warrior stance alerts and previews are disabled. Retail specialization and stance rules remain unchanged.

Validation: `lua tests/regressions.lua` and `lua tests/compatibility.lua`. In game, verify missing/dead pets, each available pet mode, learning a summon ability, mounting/dismounting, combat TTS, and `/reload` on both clients.

The automated checks use mocked game APIs. This release has not been tested in game on Forever; the summon spell IDs still require confirmation on live characters.
