# 归宗 (Gui Zong)

中国水墨风 3D 剑术动作 Roguelite，基于 Godot 4.6.2 开发。

## 游戏简介

玩家操控剑术学徒，掌握三式剑招（游、钻、绕）对抗不断涌来的敌人。
通过连击积累蓄力触发「万剑归宗」——全屏剑气爆发。
每种敌人有不同方向的破绽，善用对应剑式可造成双倍伤害。

## 三式剑招

| 剑式 | 按键 | 特性 | 视觉效果 |
|------|------|------|----------|
| 游剑式 | J | S 形蛇行扫击，范围广 | 金色蛇形轨迹 |
| 钻剑式 | K | 直线穿透，伤害最高 | 金色直线穿透 |
| 绕剑式 | L | 360° 环绕横扫 | 墨色大弧环绕 |

## 技术栈

- **引擎**: Godot 4.6.2
- **语言**: GDScript
- **物理**: Jolt Physics
- **目标平台**: Web (HTML5)
- **测试**: GDUnit4

## 项目结构

```
src/              # 游戏源码 (core/, scenes/, ui/, shaders/)
design/           # 设计文档 (GDD, art bible, UX spec)
docs/             # 技术文档 (18 个 ADR, 架构蓝图)
tests/            # 测试套件 (55+ 测试文件)
assets/           # 游戏资源 (音频, 字体)
production/       # 制作管理 (sprint, QA, gate check)
```

## 本地运行

1. 安装 [Godot 4.6.2](https://godotengine.org/releases/4.6/)
2. 用 Godot 编辑器打开 `src/project.godot`
3. 按 F5 运行

### Web 版本

```bash
# 在 Godot 编辑器中导出 Web 版本到 src/实例/ 目录
# 然后启动本地服务器：
python -m http.server 8060 --directory src/实例
# 浏览器打开 http://localhost:8060/index.html
```

## 开发工具链

本项目使用 [Claude Code Game Studios](https://github.com/Donchitos/Claude-Code-Game-Studios) 模板，
通过 48 个 AI 子代理协调进行游戏开发，覆盖设计、编程、美术、音效、QA 全流程。

## License

MIT License
