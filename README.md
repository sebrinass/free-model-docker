# free-model-docker

Our Free Model（OFM）的 Docker 封装，用于在 Unraid 上以容器方式运行，并把它的 OpenAI 兼容网关接入同机的 Octopus（章鱼）网关。

## 它是什么

- 上游：[Ebony-Vinyl/dsh-our-free-model](https://github.com/Ebony-Vinyl/dsh-our-free-model)（MIT，JS，零依赖、无构建步骤）。
- OFM 是一个伪装成 opencode CLI 去获取上游免密免费额度的客户端，并把上游包装成 OpenAI / Anthropic 兼容的网关。上游是 opencode.ai 与 api.kilo.ai，全部直连、不经任何第三方中转。
- 本镜像运行的是它的「独立本地服务」模式（`packages/standalone/`）：
  - **18900**：本机推理 + 管理页。项目硬限制只绑容器内 loopback（不支持 `--host` / `OFM_ALLOW_NON_LOOPBACK`），所以镜像**不对外映射这个口**。
  - **18901**：LAN 中继（`--lan --lan-port 18901`，绑 `0.0.0.0`），**这是给 Octopus 用的入口**。中继只放行 5 条路径：`/v1/models`、`/v1/chat/completions`、`/v1/responses`、`/v1/messages`、`/v1/messages/count_tokens`（带不带 `/v1` 前缀都放行）；其余（`/`、`/health`、管理页）一律不转发。
- 免密车道的传输层需要 Bun：`OUR_FREE_MODEL_FREE_TRANSPORT` 默认 `auto`（优先 bun），node 回退官方不保证上游接受，所以镜像里装了 Bun。

## 为什么自己封装、源码从哪来

- 上游**没有官方 Docker 镜像**，本仓库自行封装。
- `packages/standalone` 既不在 npm 包的 files 里，也不在 GitHub Release 制品里（最新 Release 只有 macOS dmg），所以镜像源码来自 **git tag 的 tarball**（`scripts/fetch-source.sh` 下载解压），**不是** `npm install`。
- 上游 tag 形如 `v2.8.5`；同一 commit 还存在变体 tag `v2.8.5-macos-unofficial`，脚本只接受严格的 `v数字.数字.数字`，变体一律拒绝。

## 快速开始（Unraid + compose）

```bash
mkdir -p /mnt/user/appdata/ofm
# 把本仓库的 docker-compose.yml 拷到宿主机任意目录
docker compose up -d
```

compose 说明：

- 端口只映射 `18901:18901`。18900 是容器内 loopback，映射出去也没用，且管理页暴露有风险。
- 数据卷：`/mnt/user/appdata/ofm:/data`（容器内 `OFM_HOME=/data`）。
- network：`octopus-net`（`external: true`）——**需要先在 Unraid 上创建**：`docker network create octopus-net`，再让章鱼容器加入同一 network。另一条路：不建 network，章鱼直接用宿主 IP `http://192.168.1.3:18901`。

### 章鱼（Octopus）侧配置

| 字段 | 值 |
| --- | --- |
| base_url | 同 network：`http://ofm:18901`；否则 `http://192.168.1.3:18901` |
| dialect | `generic` |
| key | 挂卷里 `settings.json` 的 **`standaloneLanKey`**（⚠️ 不是 `forwardKey`，两者不能混用） |

配好后在章鱼点一次「同步模型列表」。注意：章鱼 `/v1/models` 对外返回的是分组名；章鱼请求带 `member_non_stream_response_timeout_seconds=120`。

### 镜像 tag 策略

- 每次构建推 `ghcr.io/sebrinass/free-model-docker:<tag>`（如 `v2.8.5`）和 `:latest`，平台 `linux/amd64`（Unraid x86_64）。
- GHCR 包可见性设为 public 是**一次性操作**：workflow 每次构建都会尝试自动 PATCH，若自动失败请手动到 仓库 Settings → Packages → free-model-docker → 设为 public。

## 更新模型 / 更新节奏

- 容器内**不做自更新**：入口脚本启动时会把 `distribution: "managed"` 合并写进 `settings.json`（保留其它已有字段），该开关停掉 self-updater / 公告 feed / hot reload。升级 = 重建镜像。
- 更新节奏：每周一 UTC 04:37（cron `37 4 * * 1`），GitHub Actions 自动拉最新上游 tag 重建 + 推送 + 冒烟测试；也可以在 Actions 页手动 `workflow_dispatch`（可指定版本）。
- 重建后如果上游模型列表变了，需要在章鱼点一次「同步模型」。

## 已知限制

1. **magpie 本地引擎不可用**：magpie 只发布了 Windows 二进制（`vendor/magpie/bin/magpie-win32-x64.exe`），Linux 容器里这条车道没有引擎（magpie 是可选本地引擎，不影响其它车道）。
2. **管理页容器外打不开**：18900 只绑 loopback。要改配置就 `docker exec` 进容器，或直接编辑挂卷里的 `settings.json`。
3. **账号渠道不可用**：TRAE / Qoder / Cline 等账号渠道和 EAC 需要浏览器 OAuth，容器内无法完成；可用的是免密车道（匿名免费 + Kilo）和聚合渠道（自带 Key）。
4. **免密额度按出口 IP 计**：真实 429 会被上游锁约 6 小时；章鱼的 failover 分组（group mode=failover）可以兜底切到别的渠道。
5. **内容合规**：免费车道的条款由 opencode / kilo 上游决定，敏感内容不要走这条车道。
