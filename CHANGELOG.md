# PetStatusAlert

## 1.7.0

- Configure reminders, text, and colors for any supported class from the expandable **Class Settings** menu. Each class has Retail and Forever tabs. The other client shows its defaults in read-only mode.
- Add a wrong-summon alert for Warlocks on both clients. Choose which demons trigger the alert. Sayaad covers both Succubus and Incubus. Retail supports separate lists for each specialization and a configurable Grimoire of Sacrifice exception.
- Let Mages change or disable the Water Elemental requirement. Add a class-only reset and show which specializations or summon abilities are required for alerts to work.
- Split the Forever Hunter feeding button and unhappy-pet reminder into separate switches. Add food selection to the Hunter settings. The Aggressive alert on Forever is now off by default and can be enabled per class.
- Compact the alert settings and keep the display preview accessible while scrolling. The preview works on any class. Fix the error when hovering over a settings slider or its label.
- Add voice preview outside combat and a choice of one announcement or a repeat interval of 2–15 seconds. The default interval is 3 seconds.

## 1.6.0

- Add low-ammo alerts for bows, crossbows, and guns in WoW: Forever. Check the equipped ammunition after every combat and display the remaining amount below a configurable threshold. The default is 100, and 0 disables the alert.
- Add a Forever settings tab in `/psa` and QFXAddonManager. Both use the same saved ammo threshold.
- Add a Hunter feeding shortcut for hungry pets. Left-click to feed out of combat, or right-click to choose food. The addon remembers the selection per character and rechecks the item slot before feeding.
- Put ammo, feeding, and stance icons on one row with a shared size and position. Ammo text extends to the left, and the remaining count appears on the icon. Pixel glow defaults to on for ammo, feeding, Passive, and Defensive alerts.
- Reuse food data for unchanged bags and item data for the equipped weapon and ammo. Coalesce pet bar updates into a single stance check on Forever.
- Open the standalone settings directly with `/psa`, and use the current voice API for combat TTS.

## 1.5.6

- Add WoW: Forever compatibility (Interface 16001) without requiring specializations.
- Enable Forever pet alerts from class-specific learned summon abilities; refresh eligibility when spells are learned or changed.
- On Forever, only Assist suppresses pet-mode warnings. Passive, Defensive, and Aggressive have separate alerts and settings, with localized text and icons.
- Disable Warrior stance alerts, previews, and settings on Forever while retaining Retail stance support.
- Recognize pet modes explicitly, including DefensiveAssist; unknown or unreadable actions are no longer guessed as Defensive.
- Keep Retail specialization and Grimoire of Sacrifice rules separate from Forever and preserve existing saved settings.
- Validate with automated compatibility and UI regression checks. Forever in-game testing and live-character summon spell ID confirmation remain outstanding.

## 1.5.5

- Restore the selected language, alert position, and lock state after reloading the UI.
- Fix the icon-spacing control, retry missing spell icons, and restart combat TTS when visible text returns.
- Cancel pending slider callbacks when settings are hidden so previews cannot reappear after closing.
- Refresh hosted settings when the language or supported states change; preserve fixed spell-icon caches across zones and avoid duplicate glow layouts.
- Use shorter, natural English alerts for all supported pet states and Warrior Defensive Stance.

## 1.5.4

- Declare WoW 12.1.5 compatibility.
- Support QFXAddonManager hosted settings while preserving standalone operation and saved preferences.
- Fix the standalone settings preview being covered by the panel, long custom text overflowing the screen, and Warrior first-cast detection.
- Skip redundant database initialization and combat aura refreshes; apply slider changes on release instead of on every step.
- Stop TTS from reading hidden text or color markup; retry failed spell icon lookups instead of caching the failure.
