# Accessibility Requirements: 归宗 (Gui Zong)

> **Status**: Draft
> **Author**: ux-designer
> **Last Updated**: 2026-04-22
> **Accessibility Tier Target**: Basic
> **Platform(s)**: Web (HTML5)
> **External Standards Targeted**:
> - WCAG 2.1 Level A
> - Game Accessibility Guidelines (Basic tier)
> **Accessibility Consultant**: None engaged
> **Linked Documents**: `design/gdd/systems-index.md`, `design/gdd/game-concept.md`

---

## Accessibility Tier Definition

### This Project's Commitment

**Target Tier**: Basic

**Rationale**: 归宗 is a Web-based action combat game targeting hardcore players who seek mechanical mastery. The fast-twitch nature (precise timing, form-switching, combo execution) creates inherent motor barriers. As a solo-developer demo, Standard tier features (full input remapping, colorblind modes, subtitle customization) are out of scope. Basic tier ensures: readable text at standard resolution, no color-as-sole-differentiator failures, independent volume controls, and photosensitivity awareness. The Web platform also limits platform-level API integration (no Xbox XAG, no PlayStation AccessibilityNode). Godot 4.6 AccessKit support covers basic menu accessibility if needed post-demo.

**Features explicitly in scope (beyond tier baseline)**:
- Independent volume controls for Music / SFX (三式各有音色)
- Screen flash reduction option (水墨风格 VFX 可能包含闪烁)
- Hold-to-toggle alternative for dodge input (闪避是主要 hold 操作)

**Features explicitly out of scope**:
- Full input remapping (Web 端键盘/手柄映射固定)
- Colorblind modes (水墨墨色+金色为核心美术方向，色盲模式会破坏视觉风格)
- Screen reader support (3D 实时动作游戏不适用)
- Subtitle customization (无语音内容，Demo 阶段无对话系统)
- Difficulty assist modes (核心支柱：纯技巧无属性成长)

---

## Visual Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Minimum text size — HUD | Basic | Combo counter, health, wave info | Not Started | 20px minimum at 1080p. Web 游戏常见浏览器窗口尺寸需测试。 |
| Minimum text size — menus | Basic | Title, pause, settings | Not Started | 24px minimum at 1080p. |
| Text contrast — UI text | Basic | All HUD and menu text | Not Started | Minimum 4.5:1 ratio (WCAG AA). 水墨风格暗色背景 + 金色文字需验证对比度。 |
| Color-as-only-indicator audit | Basic | All UI and gameplay | Not Started | 见下方审计表。 |
| Brightness/gamma controls | Basic | Global | Not Started | Web 端通过 CSS filter 或 Godot 渲染设置暴露。Range: -25% to +25%. |
| Screen flash / strobe warning | Basic | All VFX, hit effects | Not Started | (1) 启动时显示光敏警告。(2) 审计所有闪烁 VFX（命中火花、万剑归宗爆发）。(3) 可选：减弱闪烁模式。 |
| Motion/animation reduction mode | Basic | Camera shake, hit stop | Not Started | 选项：减弱/关闭屏幕震动 + 顿帧。不影响玩家移动动画（会破坏可读性）。 |

### Color-as-Only-Indicator Audit

| Location | Color Signal | What It Communicates | Non-Color Backup | Status |
|----------|-------------|---------------------|-----------------|--------|
| 三式切换 HUD | 墨色=绕剑式, 金色=游剑式/钻剑式 | 当前激活剑式 | 图标形状不同（绕剑=圆形, 游剑=菱形, 钻剑=三角）+ 文字标签 | Not Started |
| 连击计数 | 金色高亮 = 连击中 | 连击是否活跃 | 连击数字本身递增 + 位置固定在 HUD | Not Started |
| 敌人生命值 | 红色 = 低血量 | 敌人濒死 | 无需备份 — 敌人 HP 条为辅助信息，非核心操作依据 | N/A |
| 万剑归宗就绪 | 金色粒子爆发 | 终极技能可触发 | 屏幕边缘 UI 图标亮起 + 音效提示 | Not Started |
| 波次信息 | 白色文字 | 当前波次 | 纯文字信息，非颜色编码 | N/A |

---

## Motor Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Hold-to-press alternatives | Basic | 闪避（dodge）输入 | Not Started | 闪避为唯一 hold 输入。提供 toggle 模式：按一次闪避，无需长按。 |
| Input timing adjustments | Basic | 剑招精确命中窗口 | Not Started | Demo 阶段不提供时机调整——精确时序是核心玩法。标记为 Known Limitation。 |

---

## Cognitive Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Pause anywhere | Basic | All gameplay states | Not Started | 已由 game-state-manager 的 INTERMISSION 状态支持。暂停菜单需包含设置入口。 |

---

## Auditory Accessibility

| Feature | Target Tier | Scope | Status | Implementation Notes |
|---------|-------------|-------|--------|---------------------|
| Independent volume controls | Basic | Music / SFX | Not Started | 两个独立滑块（0-100%）。SFX 包含三式音色、敌人受击音效、环境音。 |
| Visual indicators for audio-only information | Basic | Off-screen enemy attacks | Not Started | 若敌人攻击音效是唯一预警来源，需添加屏幕边缘方向指示器。当前 ADR-0013 命中反馈系统已规划视觉反馈。 |

---

## Platform Accessibility API Integration

| Platform | API / Standard | Features Planned | Status | Notes |
|----------|---------------|-----------------|--------|-------|
| Web (HTML5) | WCAG 2.1 (menus only) | Keyboard navigation for menus | Not Started | Godot 4.6 对 Web 端无障碍 API 支持有限。菜单键盘导航通过 Tab/Focus 实现。 |
| Web (HTML5) | Web Audio API | Volume controls | Not Started | 通过 Godot AudioServer 暴露 bus volume，不直接调用 Web Audio API。 |

---

## Per-Feature Accessibility Matrix

| System | Visual Concerns | Motor Concerns | Cognitive Concerns | Auditory Concerns | Addressed | Notes |
|--------|----------------|---------------|-------------------|------------------|-----------|-------|
| 三式剑招系统 | 墨色/金色切换视觉区分 | 快速切换三式需要精确输入 | 同时追踪当前式+冷却+敌人位置 | 三式各有音色差异 | Partial | 图标形状区分色差；不提供时机调整 |
| 敌人系统 | 5 种敌人视觉区分 | 敌人攻击节奏需学习 | 波次中多敌人需追踪 | 攻击音效预警 | Not Started | |
| 连击/万剑归宗 | 金色连击指示 | 连击需精确时序 | 连击计数+就绪状态 | 连击音效递进 | Partial | HUD 文字+数字备份颜色指示 |
| HUD/UI 系统 | 文字对比度+大小 | 无直接交互负担 | 信息量需控制 | 无 | Not Started | 需验证水墨暗背景上金色文字对比度 |
| 摄像机系统 | 屏幕震动+顿帧 | 无 | 震动可能造成视觉干扰 | 无 | Not Started | 需减弱震动选项 |

---

## Accessibility Test Plan

| Feature | Test Method | Pass Criteria | Status |
|---------|------------|--------------|--------|
| Text contrast ratios | Automated — 截图 + 对比度工具 | All HUD text >= 4.5:1 | Not Started |
| Hold-to-toggle dodge | Manual — 启用 toggle，完成一局完整游戏 | 闪避可完全通过 toggle 模式使用 | Not Started |
| Screen flash warning | Manual — 检查启动画面 | 光敏警告显示且可跳过 | Not Started |
| Volume controls | Manual — 验证独立滑块 | Music/SFX 独立调节，静音后无音频泄漏 | Not Started |
| Reduced motion mode | Manual — 启用减弱动画，完成一局 | 屏幕震动和顿帧减弱/关闭 | Not Started |
| 图标+文字备份颜色 | Manual — 截图对比 | 所有颜色编码元素有非颜色备份 | Not Started |

---

## Known Intentional Limitations

| Feature | Tier Required | Why Not Included | Risk / Impact | Mitigation |
|---------|--------------|-----------------|--------------|------------|
| 剑招精确时序调整 | Standard | 精确到毫秒的打击是核心玩法支柱（"精确即力量"）。提供时序调整会从根本上改变游戏性质 | 影响有运动障碍的玩家无法完成精确打击 | 记录为 Known Limitation；核心玩法设计决定了此功能不可用 |
| 完整输入重映射 | Standard | Web 端键盘/手柄映射受限于 Godot 导出能力；Demo 阶段无资源实现完整重映射 | 影响需要非标准键位的玩家 | 提供默认 WASD + 常见键位方案；标记为 post-demo 改进 |
| 色盲模式 | Standard | 水墨风格以墨色（黑）和金色为核心视觉语言，色盲调色板会破坏美术方向 | 影响约 8% 男性玩家区分三式 | 通过图标形状+文字标签提供非颜色备份（见 Color Audit 表） |

---

## Audit History

| Date | Auditor | Type | Scope | Findings Summary | Status |
|------|---------|------|-------|-----------------|--------|
| 2026-04-22 | Internal — ux-designer | Initial assessment | Pre-production accessibility baseline | Basic tier committed. 3 Known Limitations documented. Color audit table initialized with 5 entries. Hold-to-toggle for dodge in scope. | In Progress |

---

## External Resources

| Resource | URL | Relevance |
|----------|-----|-----------|
| Game Accessibility Guidelines | https://gameaccessibilityguidelines.com | Basic tier checklist |
| WCAG 2.1 | https://www.w3.org/TR/WCAG21/ | Text contrast and readability standards |
| AbleGamers | https://ablegamers.org | Motor accessibility research for action games |
| Godot Accessibility (AccessKit) | https://docs.godotengine.org/en/stable/tutorials/platforming/accessibility.html | Engine-level accessibility (4.5+) |

---

## Open Questions

| Question | Owner | Deadline | Resolution |
|----------|-------|----------|------------|
| Godot 4.6 Web 导出的 CSS filter 支持亮度调节吗？ | engine-programmer | Before implementation | Unresolved |
| 水墨 VFX 中哪些包含 >3次/秒 的闪烁？ | technical-artist | Before VFX implementation | Unresolved |
