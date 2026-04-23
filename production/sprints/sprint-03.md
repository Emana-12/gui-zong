# Sprint 03 — 2026-04-23 to 2026-05-06

## Sprint Goal
关闭 Sprint 02 遗留验证条件 + 实现计分系统 + 扩展敌人类型 + 创建核心音频素材，将游戏从"系统实现"推进到"完整体验交付"。

## Capacity
- Total days: 10 working days
- Buffer (20%): 2 days reserved for unplanned work
- Available: 8 days (~25.6h based on Sprint 02 velocity)

## Tasks

### Must Have (Critical Path)
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S03-01 | Web 端完整导出验证 | gameplay-programmer | 1d | Godot editor | Web 导出构建成功，Jolt 碰撞在 3 场景中验证通过，着色器编译无错误，实测帧率数据填入 performance baseline |
| S03-02 | 场景信号串联 (4 处 deferred) | gameplay-programmer | 0.5d | S03-01 | combo AC-3~5, hud AC-6, hud AC-2, hit-feedback AC-4 全部连接并测试通过 |
| S03-03 | 计分系统 Epic + 实现 | gameplay-programmer | 2d | S03-02 | scoring_system.gd 实现，追踪最高波次/最长连击/万剑归宗次数，最佳记录持久化，游戏结束画面显示本局 vs 历史最佳 |
| S03-04 | 敌人类型扩展（2-3 种新类型） | ai-programmer | 2.5d | S03-01 | GDD 定义的 5 种敌人中至少 3 种可生成，各有不同攻击模式和推荐克制剑式，AI 状态机独立运行 |
| S03-05 | CI 绿色构建截图存档 | devops-engineer | 0.25d | S03-01 | GitHub Actions 绿色构建截图保存至 production/qa/evidence/ |

**Must Have subtotal**: 6.25d (~20h)

### Should Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S03-06 | 核心战斗音频素材 | sound-designer | 1.5d | S03-02 | 3 种剑式命中音效 + 万剑归宗触发音效 + 1 段 BGM 占位（OGG 格式，22050Hz） |
| S03-07 | 死亡/计分画面 UX Spec | ux-designer | 0.5d | S03-03 | design/ux/death-screen.md + design/ux/score-screen.md，覆盖布局/动画/交互规范 |

**Should Have subtotal**: 2d (~6.5h)

### Nice to Have
| ID | Task | Agent/Owner | Est. Days | Dependencies | Acceptance Criteria |
|----|------|-------------|-----------|-------------|-------------------|
| S03-08 | 纯技巧进度系统实现 | gameplay-programmer | 1.5d | S03-03 | skill_progression.gd 实现，追踪平均连击长度/闪避成功率/万剑归宗频率，局间趋势展示 |
| S03-09 | 方向判定 miss 率修复 | gameplay-programmer | 0.25d | S03-01 | 复现 miss 场景，修复或文档化触发条件和频率 |

**Nice to Have subtotal**: 1.75d (~5.5h)

## Carryover from Previous Sprint
| Task | Reason | New Estimate |
|------|--------|-------------|
| S02-02 CI 绿色构建截图 | 环境限制（无 Godot editor） | 0.25d (S03-05) |
| S02-03 性能基线数据填充 | 环境限制（无 Godot editor） | 合并入 S03-01 |
| S02-04 Jolt 碰撞验证 | 环境限制（无 Godot editor） | 合并入 S03-01 |

## Risks
| Risk | Probability | Impact | Mitigation |
|------|------------|--------|------------|
| Jolt Web 碰撞实测失败 | 中 | 高 | S03-01 前置执行（Day 1-2），ADR-0005 已定义降级路线图 |
| 着色器 WebGL 性能不达标 | 低 | 中 | ShaderManager 自动降级已编码，fps<30 关后处理 |
| 敌人 AI 扩展复杂度超估 | 中 | 中 | 优先实现 2 种而非 3 种，敏捷型敌人闪避机制可延后 |
| 场景串联后发现隐藏 bug | 中 | 中 | 每次连接后运行测试套件，20% buffer 吸收 |

## Dependencies on External Factors
- Godot 4.6.2 editor 可用（解决 S02 遗留的 3 条件）
- Web 导出模板已安装

## Definition of Done for this Sprint
- [ ] All Must Have tasks completed
- [ ] All tasks pass acceptance criteria
- [ ] QA plan exists (`production/qa/qa-plan-sprint-03.md`)
- [ ] All Logic/Integration stories have passing unit/integration tests
- [ ] Smoke check passed (`/smoke-check sprint`)
- [ ] QA sign-off report: APPROVED or APPROVED WITH CONDITIONS (`/team-qa sprint`)
- [ ] No S1 or S2 bugs in delivered features
- [ ] Design documents updated for any deviations
