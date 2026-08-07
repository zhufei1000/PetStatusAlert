# PetStatusAlert v1.4.0 — 图标提醒模式

## 本次改动概述

为 PetStatusAlert 插件新增**图标提醒模式**：宠物未召唤/死亡时，可显示对应召唤技能的法术图标（如猎人哨子、邪DK亡者复生），而非仅文字。

## 新增功能

### 三种显示模式（设置 > 动画页可切换）

| 模式 | 说明 |
|------|------|
| 纯文字 `text` | 原有行为，默认值（老用户升级后保持纯文字） |
| 纯图标 `icon` | NO_PET/PET_DEAD 只显示技能图标；PASSIVE/DEFENSIVE 显示宠物姿态图标（需宠物存在）；UNKNOWN 显示文字 |
| 图标+文字 `both` | 图标在左、文字在右并列显示 |

### 各职业图标映射

| 职业 | 状态 | 图标来源 | 技能/spellID |
|------|------|----------|------|
| 猎人 | 没宠物 | 技能图标 | Call Pet 哨子 (883) |
| 猎人 | 宠物死 | 技能图标 | Revive Pet 复活宠物 (982) |
| 猎人 | 被动/防御 | 宠物动作栏姿态按钮 | PET_MODE_PASSIVE / PET_MODE_DEFENSIVE |
| 邪DK | 没宠物/宠物死 | 技能图标 | Raise Dead 亡者复生 (46584) |
| 邪DK | 被动/防御 | 宠物动作栏 | PET_MODE_PASSIVE / PET_MODE_DEFENSIVE |
| 术士 | 没宠物/宠物死 | 动态检测已学召唤技能 | 恶魔守卫>地狱猎犬>魅魔>蓝胖>小鬼 |
| 术士 | 被动/防御 | 宠物动作栏 | PET_MODE_PASSIVE / PET_MODE_DEFENSIVE |
| 冰法 | 没宠物/宠物死 | 技能图标 | Summon Water Elemental (31687) |
| 冰法 | 被动/防御 | 宠物动作栏 | PET_MODE_PASSIVE / PET_MODE_DEFENSIVE |

> UNKNOWN（未知）状态无图标可用，始终显示文字。

### 新增可调参数

- 图标模式（纯文字/纯图标/图标+文字）
- 图标大小（24~96，默认 48）
- 图标与文字间距（0~40，默认 10，纯图标模式不使用）

## 改动文件清单

| 文件 | 改动 |
|------|------|
| `Core/Database.lua` | 新增 alertIconMode/alertIconSize/alertIconGap 配置项与常量 |
| `Core/AlertFrame.lua` | 核心：contentFrame 浮动层、icon 纹理、状态→spellID 映射、布局逻辑、Get/Set API |
| `Core/Localization.lua` | 4 语言（EN/zhCN/zhTW/ruRU）新增图标模式 UI 文本 |
| `UI/Options.lua` | 动画页新增图标模式三按钮 + 图标大小滑条；窗口高度调整 |
| `PetStatusAlert.toc` | 版本 1.3.24 → 1.4.0，Notes 补充说明 |

## 关键设计

- **contentFrame 中间层**：icon 和 text 都放在 contentFrame 里，浮动动画作用于 contentFrame 整体，与 icon/text 相对布局解耦，避免每帧重算锚点。
- **图标覆盖全部状态**：NO_PET/PET_DEAD 使用法术图标；PASSIVE/DEFENSIVE 从宠物动作栏动态获取姿态按钮图标（宠物存在时）。UNKNOWN 无图标。
- **纹理获取安全**：`C_Spell.GetSpellTexture` 是纯查询，不触发 secure 机制，战斗中可用。
- **术士动态检测**：按已学召唤技能优先级选择图标，恶魔专精显示恶魔守卫。
- **向后兼容**：默认纯文字模式，老用户升级后观感不变。

## 验证

全部 10 个 Lua 文件通过 luaparse 语法检查。

## 升级注意

- 配置自动迁移：`alertIconMode` 缺省为 `"text"`，不会突然显示图标。
- 无需删除 SavedVariables，旧配置完全兼容。
