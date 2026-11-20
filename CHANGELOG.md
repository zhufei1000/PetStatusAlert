# PetStatusAlert

## 1.8.1

- Fix pet stance alerts (Passive, Defensive, and Aggressive) going silent on Retail and Forever. The client returns the pet action flags as numeric `1`/`0` rather than Lua booleans, so the previous read left the active stance unreadable. Stance parsing now accepts both the Retail and Classic tuple layouts and both boolean and numeric flags.
- Retry an unreadable stance instead of caching the first failed read, so alerts recover after a summon or pet-bar update.
- Fix the Warrior aura-refresh guard to use the timer bucket that `QueueRefresh` actually stores.
- Remove an unused TTS localization string.

## 1.8.0

- Move pixel glow and vertical motion to a separate Animation page. Add a shared glow refresh slider (10–30 updates per second, default 20).
- Put screen preview, position lock, and position reset at the top of General. Keep the preview visible while adjusting Display or Animation.
- Add a separate Forever low ammo alert switch, on by default. Turning it off keeps the threshold, and a previously saved threshold of zero is carried over as an opt-out.
- On Forever, warn when Hunter pet Growl should be enabled outdoors or disabled in a dungeon or raid. Remind players to set a learned Cower opposite to Growl's actual autocast setting after fixing any Growl mismatch.
- Give pets two seconds to return after dismounting on both clients. Only the missing-pet alert waits, and entering combat checks immediately.
- On Forever, show a separate zero-food indicator when a pet needs feeding and there is no suitable food in the player's bags. Hide the feed reminder while the pet is eating.
- Reduce idle and combat CPU: cache mount/vehicle and pet stance state between the events that can change them, cache learned spell lookups, remove protected-call wrappers from the pet refresh hot path, and reuse timer callbacks instead of allocating closures and formatted strings for every pet event.
- Reduce bag-event CPU: cache pet-food edibility per item, reuse per-slot food entries instead of rebuilding them on every pickup, and cache the preferred-food count between bag changes.
- By default, update pixel glow up to 20 times per second for the main alert and 15 for accessory icons, with six pixels per glow. Floating text still updates at 15 FPS.
- Skip redundant alert work: unchanged statuses no longer rewrite the text color, rebuild the layout, or recalculate default message strings.
- Fix pet stance detection to read the real `isActive` pet action flag instead of the `isToken` flag on clients that return the full action tuple.
- Remove general class and group buffs, player food reminders, and temporary weapon enhancement alerts. Pet and Warrior stance alerts, pet feeding, and low ammo remain available.
- On Forever, show the Hunter aspect reminder only in combat with the Hunter's own Cheetah or Pack active. Suggest Falcon or the highest known Hawk rank.
- Move Retail and Forever selection above the navigation. Group class, display, and voice settings under Pet Alerts. Forever has separate Hunter Tools and Ammo pages.
- Remove master switches. Each reminder uses its own saved setting or threshold.

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
