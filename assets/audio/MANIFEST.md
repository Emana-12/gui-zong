# 音频资源清单 (S03-06)

## SFX 文件需求

### 剑式命中音效
| 文件名 | 格式 | 说明 | 对应信号 |
|--------|------|------|---------|
| `hit_you_metal.ogg` | OGG 22050Hz | 游剑式击中金属 | feedback(form=1, material=metal) |
| `hit_you_wood.ogg` | OGG 22050Hz | 游剑式击中木材 | feedback(form=1, material=wood) |
| `hit_you_body.ogg` | OGG 22050Hz | 游剑式击中肉体 | feedback(form=1, material=body) |
| `hit_you_ink.ogg` | OGG 22050Hz | 游剑式击中墨体 | feedback(form=1, material=ink) |
| `hit_rao_metal.ogg` | OGG 22050Hz | 绕剑式击中金属 | feedback(form=2, material=metal) |
| `hit_rao_wood.ogg` | OGG 22050Hz | 绕剑式击中木材 | feedback(form=2, material=wood) |
| `hit_rao_body.ogg` | OGG 22050Hz | 绕剑式击中肉体 | feedback(form=2, material=body) |
| `hit_rao_ink.ogg` | OGG 22050Hz | 绕剑式击中墨体 | feedback(form=2, material=ink) |
| `hit_zuan_metal.ogg` | OGG 22050Hz | 钻剑式击中金属 | feedback(form=3, material=metal) |
| `hit_zuan_wood.ogg` | OGG 22050Hz | 钻剑式击中木材 | feedback(form=3, material=wood) |
| `hit_zuan_body.ogg` | OGG 22050Hz | 钻剑式击中肉体 | feedback(form=3, material=body) |
| `hit_zuan_ink.ogg` | OGG 22050Hz | 钻剑式击中墨体 | feedback(form=3, material=ink) |
| `hit_generic_body.ogg` | OGG 22050Hz | 通用命中音效（回退） | feedback(form=0, material=body) |

### 万剑归宗音效
| 文件名 | 格式 | 说明 |
|--------|------|------|
| `myriad_trigger.ogg` | OGG 22050Hz | 万剑归宗触发（渐强爆发） |

### BGM
| 文件名 | 格式 | 说明 |
|--------|------|------|
| `combat_loop.ogg` | OGG 22050Hz | 战斗背景音乐（循环） |

## 音量规范

- SFX: 0.8 默认音量（SceneWiring 中 play_sfx 调用参数）
- BGM: 1.0 默认音量，SFX 不遮盖 BGM
- 万剑归宗触发音效: 渐强 0% → 100%，与顿帧同步

## 技术规范

- 格式: OGG Vorbis
- 采样率: 22050Hz (Web 平台体积优化)
- 声道: 单声道 (SFX), 立体声 (BGM)
- 总库上限: < 30 文件, < 2MB (ADR-0004)
