# PetStatusAlert — Pet & Warrior Stance Alerts

**PetStatusAlert** is a lightweight alert addon for **WoW Retail** and **WoW: Forever (Interface 16001)**. It warns you before a pet or class-state mistake costs you a pull: missing or dead pets, the wrong pet mode, the wrong Warlock demon, Defensive Stance on Warriors, low ammunition, Growl/Cower autocast, and unhappy Hunter pets.

No external database is required, and the addon only speaks up when something needs fixing.

## Highlights

- **Pet alerts** for Hunter, Warlock, Unholy Death Knight and Frost Mage on Retail; Hunter, Warlock and Mage on Forever.
- **Wrong pet mode**: Passive, Defensive, and optionally Aggressive on Forever. Only Assist is treated as correct.
- **Warlock wrong-summon alert** with per-demon selection, Sayaad (Succubus/Incubus) sharing one rule, and Grimoire of Sacrifice support.
- **Warrior Defensive Stance** warning for Arms and Fury on Retail, with combat-safe tracking.
- **Forever extras**: low-ammo alerts for bows, crossbows and guns, one-click Hunter pet feeding with a no-food indicator, unhappy-pet alerts, Growl/Cower autocast checks, and a combat warning for Cheetah or Pack.
- **Readable at a glance**: text-only, icon-only, or icon + text, with pixel glow and floating animation.
- **Per-class settings**: alert switches, custom text, colors and class rules, separated for Retail and Forever.
- **Combat TTS** with adjustable speed, speak-once mode, or a 2–15 second repeat interval.
- **4 languages**: English, Simplified Chinese, Traditional Chinese and Russian.

## Supported Classes & Rules

| Class | Retail | WoW: Forever |
|---|---|---|
| Hunter | Beast Mastery and Survival | After learning Call Pet; Aggressive alert optional |
| Warlock | All specializations; per-spec demon rules | After learning a summon ability; one shared demon list |
| Death Knight | Unholy | Not available |
| Mage | Frost with Water Elemental; requirement configurable | Mage with Water Elemental; requirement configurable |
| Warrior | Arms and Fury: Defensive Stance | Optional alerts for Battle, Defensive, and Berserker Stance |

Protection Warrior is intentionally excluded from the Defensive Stance warning. Marksmanship Hunter is excluded from pet alerts on Retail.

## Pet Status Alerts

PetStatusAlert warns when:

- Your pet is **missing**
- Your pet is **dead**
- Your pet is in **Passive** mode
- Your pet is in **Defensive** mode
- Your pet is in **Aggressive** mode (Forever only; off by default)
- The pet status **cannot be identified** (available as an optional alert)

**Assist** is the only pet mode that does not trigger a warning. Alerts are hidden while mounted or in a vehicle. On Retail, Warlocks using Grimoire of Sacrifice do not get false "missing pet" warnings.

Each state has its own switch, custom text and text color. In the default configuration, missing, dead, Passive and Defensive alerts are on; Aggressive, Unknown and the Warlock wrong-summon alert are off until you enable them.

## Warlock: Wrong Demon Alert

Choose which demons should trigger a warning when they are your active pet. Sayaad covers both Succubus and Incubus. On Retail, each specialization keeps its own demon list, and the alert can be suppressed while the configured Grimoire of Sacrifice talent is active. The talent ID can be changed under **Advanced**. Forever uses one shared list.

## Warrior Stance Alerts

Arms and Fury Warriors are warned while Defensive Stance is active. The tracker also works during combat when modern WoW restrictions make aura data unavailable, by following your own stance casts. Protection is not affected on Retail. On Forever, select which active stances should trigger a warning.

## Forever: Ammo, Pet Care & Combat Aspects

- **Low ammo alert** — for any class using a bow, crossbow or gun that consumes ammo. The equipped ammunition is checked after combat, and the icon shows the remaining count. Default threshold: 100 (1–9999). The alert has its own switch; turning it off keeps your threshold.
- **One-click feeding** — a feed button appears out of combat when a Hunter pet can be fed. Left-click to feed, right-click to choose food. The choice is saved per character and rechecked before feeding. A gray icon with a red **0** appears when the pet needs feeding and no suitable food is in your bags; the feed reminder hides while the pet is eating.
- **Unhappy pet reminder** — can be enabled separately from the feed button.
- **Pet autocast reminder** — on Forever Hunters, warns when Growl should be on outdoors (solo or party) and off in a dungeon or raid. If the pet knows Cower, the reminder checks it against Growl's actual autocast state and only appears after Growl matches its rule. The badge shows `+` to turn autocast on or `-` to turn it off.
- **Combat aspect reminder** — in combat, a Hunter's own Aspect of the Cheetah or Aspect of the Pack prompts a switch to Falcon, or the highest learned Hawk rank. Set it under **Forever → Hunter Tools → Combat Aspect**. The ammo threshold is under **Forever → Ammo**.
- **Dismount grace** — on both clients, the missing-pet alert waits two seconds after dismounting so the pet can return. Entering combat checks immediately; death and pet-mode alerts do not wait.

## Display & Customization

- **Text only**, **Icon only**, or **Icon + Text**
- Spell icons for missing/dead pets, stance icons for pet modes, and a stance icon for Warriors
- Icon size and icon/text spacing
- Font size
- Vertical floating animation with adjustable speed and amplitude
- Optional pixel glow with adjustable speed and refresh rate (10–30 updates per second for the main icon; accessory icons use about 75% of that rate)
- Free positioning, position lock, and position reset
- Live preview while you change settings

The **General** page keeps preview and position controls at the top. The preview stays visible while you adjust **Display** or **Animation**.

## Class Settings

Choose **Retail** or **Forever** above the navigation, then select a class under **Pet Alerts**. The active client saves alert switches, custom text, colors and class rules per class. The other client's tab shows its defaults in read-only mode. Each class page shows its activation requirements and has a **Reset this class** button. Food choices are kept when you reset a Hunter.

## Combat TTS

Optional text-to-speech reads the visible alert during combat:

- Speak once, or repeat every **2–15 seconds** (default: **3 seconds**)
- Adjustable speech speed
- Out-of-combat **Listen** preview
- Icon-only alerts with no visible text stay silent

## Settings

- `/psa` opens the standalone settings panel
- **Options → AddOns → PetStatusAlert** also works
- If **QFXAddonManager** is installed, the same settings are available inside the manager
- Language follows the client by default, or can be set manually

## Localization

English, Simplified Chinese, Traditional Chinese, and Russian. Russian translation by **Hubbotu**.

## Compatibility

- WoW Retail: Interface 120105 / 120100 (12.1.5 / 12.1.0)
- WoW: Forever: Interface 16001
- No required dependencies; QFXAddonManager is optional
- SavedVariables: `PetStatusAlertDB`

---

# PetStatusAlert — 宠物与战士姿态提醒

**PetStatusAlert** 是一个轻量级提醒插件，同时支持 **魔兽世界正式服** 和 **魔兽世界：无限服（Interface 16001）**。它会在宠物或职业状态出错时提醒你：未召唤宠物、宠物死亡、宠物模式错误、术士召唤错误、战士防御姿态、弹药不足、低吼/畏缩自动施放错误，以及猎人宠物不高兴。

不需要额外数据库插件，状态正常时不会打扰你。

## 功能概览

- **宠物提醒**：正式服支持猎人、术士、邪恶死亡骑士、冰霜法师；无限服支持猎人、术士、法师。
- **宠物模式提醒**：被动、防御；无限服还可选攻击状态。只有协助模式不会提醒。
- **术士召唤错误提醒**：可逐项选择会触发提醒的恶魔；萨亚德同时涵盖魅魔和夜魔；支持牺牲魔典。
- **战士防御姿态提醒**：正式服武器/狂暴战士，战斗中也能可靠追踪。
- **无限服专属**：弓、弩、枪械弹药不足提醒；猎人一键喂食（含无可用食物提示）、宠物不高兴、低吼/畏缩自动施放检查，以及战斗守护切换提醒。
- **一眼看清**：纯文字、纯图标、图标 + 文字，支持像素流光和上下浮动动画。
- **按职业设置**：每个职业可单独设置提醒开关、文字、颜色和职业规则，正式服与无限服分开保存。
- **战斗 TTS 语音**：语速可调，可选仅播一次或每 2–15 秒重复。
- **4 种语言**：英语、简体中文、繁体中文、俄语。

## 支持职业与规则

| 职业 | 正式服 | 无限服 |
|---|---|---|
| 猎人 | 野兽控制、生存 | 学会召唤宠物后生效；攻击状态提醒可选 |
| 术士 | 所有专精；按专精保存恶魔规则 | 学会召唤技能后生效；共用一份恶魔名单 |
| 死亡骑士 | 邪恶 | 不支持 |
| 法师 | 冰霜，需水元素；条件可调整 | 法师，需水元素；条件可调整 |
| 战士 | 武器、狂暴：防御姿态 | 可选战斗、防御和狂暴姿态提醒 |

防护战士不会触发防御姿态提醒；正式服射击猎人不参与宠物提醒。

## 宠物状态提醒

可检测并提醒：

- **未召唤宠物**
- **宠物死亡**
- **宠物处于被动状态**
- **宠物处于防御状态**
- **宠物处于攻击状态**（仅无限服，默认关闭）
- **无法识别宠物状态**（可选提醒）

只有 **协助模式** 不会触发提醒。骑乘坐骑或进入载具时自动隐藏。正式服术士正确使用牺牲魔典时，不会误报“未召唤宠物”。

每种状态都可以单独开关、自定义文字和颜色。默认开启未召唤、死亡、被动和防御提醒；攻击、未知状态和术士召唤错误提醒默认关闭，需要手动开启。

## 术士：召唤错误提醒

可以勾选“当当前宠物是这些恶魔时提醒”。萨亚德同时涵盖魅魔和夜魔。正式服按专精分别保存名单，并可在配置的牺牲魔典天赋生效时自动抑制提醒；天赋 ID 可在 **高级** 中修改。无限服共用一份名单。

## 战士姿态提醒

武器和狂暴战士处于防御姿态时会收到提醒。即使在新版魔兽世界战斗中光环数据受限，插件也会通过自身姿态施法事件继续追踪，保证提醒可用。正式服防护战士不受影响。无限服可勾选想要提醒的姿态。

## 无限服：弹药、宠物照料与战斗守护

- **弹药不足提醒**：适用于使用弓、弩或枪械且需要弹药的职业。每次战斗结束后检查装备的弹药，图标角标显示剩余数量。默认阈值 100（1–9999），提醒有独立开关，关闭后仍保留阈值。
- **一键喂食**：猎人宠物需要喂食时，脱战状态下显示喂食按钮。左键喂食，右键选择食物；食物选择按角色保存，喂食前会重新核对背包。宠物需要喂食但背包里没有合适食物时，显示灰色图标和红色 **0**；宠物正在进食时隐藏喂食提醒。
- **宠物不高兴提醒**：可与喂食按钮分别开关。
- **宠物自动施放提醒**：无限服猎人在野外（单人或小队）应开启低吼，在五人本或团队中应关闭；宠物学会畏缩后，会在低吼符合规则后再检查畏缩，并用 `+`/`-` 角标提示应开启还是关闭自动施放。
- **战斗守护提醒**：战斗中自己开启猎豹守护或豹群守护时，提示切换到已学的猎鹰守护，或最高等级的雄鹰守护。守护开关位于 **无限服 → 猎人专用 → 守护提醒**，弹药阈值位于 **无限服 → 弹药提醒**。
- **下马缓冲**：正式服与无限服在上下马后给宠物 2 秒返回时间，只延后未召唤提醒；进入战斗立即检查，死亡和姿态提醒不受影响。

## 显示与自定义

- **纯文字**、**纯图标**、**图标 + 文字**
- 未召唤/死亡显示技能图标，宠物模式显示姿态图标，战士显示防御姿态图标
- 图标大小、图标与文字间距
- 字体大小
- 上下浮动动画，可调速度和幅度
- 可选像素流光，可调速度和刷新频率（主图标每秒 10–30 次，附加图标约为该值的 75%）
- 自由移动位置、锁定位置、恢复默认位置
- 调整设置时实时预览

**通用** 页顶部固定显示预览与位置控件；调整 **显示样式** 或 **动画效果** 时预览会保持可见。

## 职业设置

在导航上方选择 **正式服** 或 **无限服**，再打开对应的职业设置。当前客户端会按职业保存提醒开关、自定义文字、颜色和职业规则；另一个客户端页签以只读方式显示默认值。每个职业页都会显示生效条件，并提供 **恢复本职业默认** 按钮。恢复猎人设置时会保留已选食物。

## 战斗 TTS 语音

可选语音提醒会在战斗中朗读当前可见的提醒文字：

- **仅播一次**，或每 **2–15 秒** 重复（默认 **3 秒**）
- 可调整朗读速度
- 脱战时可以 **试听**
- 纯图标且没有可见文字时不会播报

## 设置方式

- `/psa` 打开独立设置面板
- 也可以通过 **选项 → 插件 → PetStatusAlert** 进入
- 安装 **QFXAddonManager** 后，可在管理中心内使用同一套设置
- 语言默认跟随客户端，也可以手动切换

## 多语言

支持英语、简体中文、繁体中文和俄语。俄语翻译：**Hubbotu**。

## 兼容性

- 正式服：Interface 120105 / 120100（12.1.5 / 12.1.0）
- 无限服：Interface 16001
- 无必需依赖；QFXAddonManager 为可选
- 存档变量：`PetStatusAlertDB`
