# PetStatusAlert

## 1.5.4

- Declare WoW 12.1.5 compatibility.
- Support QFXAddonManager hosted settings while preserving standalone operation and saved preferences.
- Fix the standalone settings preview being covered by the panel, long custom text overflowing the screen, and Warrior first-cast detection.
- Skip redundant database initialization and combat aura refreshes; apply slider changes on release instead of on every step.
- Stop TTS from reading hidden text or color markup; retry failed spell icon lookups instead of caching the failure.
