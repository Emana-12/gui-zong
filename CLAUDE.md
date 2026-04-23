### 重要！###
当前是powershell环境，遇到bash需要自动转为powershell命令。
请确保在与我交流时始终使用中文。
所有路径已经确定，无需再向我询问任何问题，直接按推荐路径进行操作即可。
在完成上一个任务后，自动开启下一个任务，不要再询问我是否继续
# 归宗 (Gui Zong) — 三式剑招 3D 动作 Roguelite

中国水墨风 3D 剑术动作 Roguelite，基于 Godot 4.6.2 + GDScript 开发。
Web (HTML5) 平台发布。

## Technology Stack

- **Engine**: Godot 4.6.2
- **Language**: GDScript
- **Physics**: Jolt (Godot 4.6 default)
- **Target Platform**: Web (HTML5)
- **Version Control**: Git with trunk-based development

## Project Structure

@.claude/docs/directory-structure.md

## Engine Version Reference

@docs/engine-reference/godot/VERSION.md

## Technical Preferences

@.claude/docs/technical-preferences.md

## Coordination Rules

@.claude/docs/coordination-rules.md

## Collaboration Protocol

**User-driven collaboration, not autonomous execution.**
Every task follows: **Question -> Options -> Decision -> Draft -> Approval**

- Agents MUST ask "May I write this to [filepath]?" before using Write/Edit tools
- Agents MUST show drafts or summaries before requesting approval
- Multi-file changes require explicit approval for the full changeset
- No commits without user instruction

See `docs/COLLABORATIVE-DESIGN-PRINCIPLE.md` for full protocol and examples.

> **First session?** If the project has no engine configured and no game concept,
> run `/start` to begin the guided onboarding flow.

## Coding Standards

@.claude/docs/coding-standards.md

## Context Management

@.claude/docs/context-management.md
