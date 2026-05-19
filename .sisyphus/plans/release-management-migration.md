# Release 管理优化方案 — 对齐 news-bar

> 创建日期: 2026-05-19
> 状态: 已审核，待执行

---

## 一、目标

将 `dist/` 目录结构改为与 news-bar 项目一致的 `release/` 结构：

```
release/
├── latest/                          # 始终指向最新构建产物
│   ├── Token Cost App - OC Codex.app
│   └── Token Cost App - OC Codex.zip
├── v0.1.0/                          # 正式发布
├── v0.1.1/
├── v0.1.2/
├── v0.1.2-20260519-154604-71172/    # 开发快照（保持现有命名格式）
├── versions.json                    # 结构化版本记录（入库）
├── release-notes/                   # RELEASE_NOTES 集中管理（入库）
│   └── v0.1.1.md
└── .gitkeep
```

参考目标：`/Users/11169285/Documents/Opencode project/news-bar/release/`

---

## 二、P0 风险发现与处理

| # | 发现 | 严重度 | 处理方式 |
|---|------|--------|----------|
| 1 | `build_and_run_codex.sh` L6 `DIST_DIR` 改成 `RELEASE_DIR` 会与 L109 变量**命名冲突** | 🔴 脚本报错 | 用 `RELEASE_BASE_DIR` 替代 |
| 2 | `docs/开发手册.md` L157 `dist/snapshots/codex/` 是文档错误 | 🟡 文档不准确 | 修正为 `~/Library/Application Support/com.yanghaoran.CodexTokenCost/snapshots/codex/` |
| 3 | `.gitignore` 如果写 `release/*/` 会忽略 `versions.json` 和 `release-notes/` | 🔴 文件不入库 | 改为明确 ignore `.app` 和 `.zip` 文件 |
| 4 | `release/` 空目录 git 不跟踪 | 🟡 目录可能丢失 | 创建 `.gitkeep` 文件 |

---

## 三、安全边界

### 3.1 `distDirectory` 死代码

`AppPaths.swift:19` 和 `CodexAppPaths.swift:19` 定义了 `distDirectory` 属性，返回 `bundleURL.deletingLastPathComponent()`。全代码库无任何调用，**不受本次改动影响**。

### 3.2 运行时快照路径独立

快照真正落盘路径：`~/Library/Application Support/com.yanghaoran.CodexTokenCost/snapshots/`，通过 `CodexAppPaths.runtimeRoot` → `SafeFileStore` 管理。**与 release 目录无关**。不需要改任何 Swift 代码。

### 3.3 发布流程完整性

- `release.yml` L25 路径必须同步改为 `release/${{ github.ref_name }}/...`，否则下次 tag push 后 GitHub Release 找不到 zip。

### 3.4 文件写入安全性

- `versions.json` 写入：从已有变量（`RELEASE_VERSION_NUMBER`、`APP_ZIP_NAME`、日期）构造，无外部输入拼接，无注入风险。
- `latest/` 更新：删除+重建，源目录由脚本内部控制，无路径穿越风险。

---

## 四、完整改动清单

### 4.1 `script/build_and_run_codex.sh`

| 行号 | 操作 | 当前 | 改为 |
|------|------|------|------|
| L6 | 改 | `DIST_DIR="$ROOT_DIR/dist"` | `RELEASE_BASE_DIR="$ROOT_DIR/release"` |
| L88 | 改 | `"$DIST_DIR/releases"/v[0-9]*` | `"$RELEASE_BASE_DIR"/v[0-9]*` |
| L106 | 改 | `LOCAL_RELEASE_DIR="$DIST_DIR/releases/${RELEASE_TAG}-${RELEASE_STAMP}"` | `LOCAL_RELEASE_DIR="$RELEASE_BASE_DIR/${RELEASE_TAG}-${RELEASE_STAMP}"` |
| L107 | 改 | `OFFICIAL_RELEASE_DIR="$DIST_DIR/releases/$RELEASE_TAG"` | `OFFICIAL_RELEASE_DIR="$RELEASE_BASE_DIR/$RELEASE_TAG"` |
| L213 后 | 新增 | — | `update_latest()` 函数定义 |
| L213 后 | 新增 | — | `update_versions_json()` 函数定义 |
| release case | 新增 | 仅 `package_release_zip` | `package_release_zip` 后调用 `update_latest` + `update_versions_json` |
| run/build 等 | 新增 | 仅 `stage_bundle` | `stage_bundle` 后调用 `update_latest`（不写 zip/versions.json） |

**新增函数规格：**

```bash
# 更新 release/latest/ 目录
# 在 stage_bundle 后调用（所有模式）；release 模式额外复制 .zip
update_latest() {
  rm -rf "$RELEASE_BASE_DIR/latest"
  mkdir -p "$RELEASE_BASE_DIR/latest"
  ditto "$APP_BUNDLE" "$RELEASE_BASE_DIR/latest/$APP_DISPLAY_NAME.app"
  if [[ "$MODE" == "release" ]] && [[ -f "$RELEASE_DIR/$APP_ZIP_NAME" ]]; then
    cp "$RELEASE_DIR/$APP_ZIP_NAME" "$RELEASE_BASE_DIR/latest/$APP_ZIP_NAME"
  fi
}

# 更新 release/versions.json
# 仅在 release 模式调用
update_versions_json() {
  local versions_file="$RELEASE_BASE_DIR/versions.json"
  local today="$(date +%Y-%m-%d)"
  local entry="{\"version\": \"$RELEASE_VERSION_NUMBER\", \"date\": \"$today\", \"file\": \"$APP_ZIP_NAME\", \"type\": \"release\"}"
  # merge into JSON array, dedup by version+type, sort by semver
}
```

### 4.2 `.github/workflows/release.yml`

| 行号 | 当前 | 改为 |
|------|------|------|
| L25 | `dist/releases/${{ github.ref_name }}/Token Cost App - OC Codex.zip` | `release/${{ github.ref_name }}/Token Cost App - OC Codex.zip` |

### 4.3 `.gitignore`

替换 L24-28：

```gitignore
# Release artifacts (binaries generated locally; zips uploaded via GitHub Releases)
# Ignore all .app bundles and .zip files inside release version directories
release/latest/*.app
release/latest/*.zip
release/latest/*.dmg
release/v*.*.*/*.app
release/v*.*.*/*.zip
release/v*.*.*-*/*.app
release/v*.*.*-*/*.zip

# Keep these release metadata files
!release/versions.json
!release/release-notes/
!release/.gitkeep
!release/latest/.gitkeep
```

### 4.4 `docs/开发手册.md`

| 行号 | 操作 | 说明 |
|------|------|------|
| L34-37 | 改 | 目录结构图 `dist/` → `release/`，追加 `latest/`、`versions.json`、`release-notes/` |
| L157 | 修正 | `dist/snapshots/codex/` → `~/Library/Application Support/com.yanghaoran.CodexTokenCost/snapshots/codex/` |
| L170 | 改 | `dist/releases/` → `release/` |
| L181-182 | 改 | `dist/releases/` → `release/` |
| L196-198 | 改 | `dist/releases/` → `release/` |
| L226-230 | 改 | 命名矩阵两处 `dist/releases/` → `release/` |
| L236-237 | 改 | 产物描述 `dist/releases/` → `release/` |
| L247 | 改 | 发布流程 zip 路径 |
| L257 | 改 | 清理描述 |
| 6.2 节后 | 新增 | `release/latest/` 和 `versions.json` 使用说明 |

### 4.5 `README.md`

| 行号 | 操作 | 当前 | 改为 |
|------|------|------|------|
| L76 | 改 | `dist/releases/` | `release/` |

### 4.6 `RELEASE_NOTES_v0.1.1.md`

| 操作 | 说明 |
|------|------|
| `git mv` | 从项目根 → `release/release-notes/v0.1.1.md` |

### 4.7 `CHANGELOG.md`

在 `## [v0.1.2] - Unreleased` 的 `### Changed` 中新增一条：

```markdown
- **Release 目录重组**：`dist/` → `release/`，对齐 news-bar 项目结构。新增 `release/latest/`（始终指向最新构建）、`release/versions.json`（结构化版本元数据）、`release/release-notes/`（集中管理）。RELEASE_NOTES 从项目根迁入 `release/release-notes/`。更新 `.gitignore` 规则、CI/CD 脚本路径、开发手册和 README。
```

### 4.8 目录操作

| 操作 | 说明 |
|------|------|
| `mkdir -p release/latest release/release-notes` | 创建新结构 |
| `touch release/.gitkeep release/latest/.gitkeep` | git 跟踪空目录 |
| `echo '[]' > release/versions.json` | 初始版本文件 |
| `git mv dist/releases/v* release/` | 迁移现有构建产物 |
| 清理 `dist/archive/` 重复内容 | 删除或归档 |
| 删除空的 `dist/` 目录 | 清理残留 |

---

## 五、无需改动的文件（确认）

| 文件 | 状态 | 原因 |
|------|------|------|
| `SECURITY.md` | ✅ | 无 dist/release 引用 |
| `.github/workflows/ci.yml` | ✅ | 只做 `swift build`，不碰产物 |
| `.github/workflows/codeql.yml` | ✅ | CodeQL 分析，无关 |
| `docs/架构逻辑链图.md` | ✅ | 无 dist/release 引用 |
| `docs/功能模块关联清单.md` | ✅ | 无 dist/release 引用 |
| `docs/余额监控功能-完整计划.md` | ✅ | 无 dist/release 引用 |
| `docs/Provider 计费定价速查.md` | ✅ | 纯定价数据，无引用 |
| `Sources/` 下所有 Swift 代码 | ✅ | 快照走 runtimeRoot，不引用 dist |
| `AppPaths.swift:19` `distDirectory` | 🟢 死代码 | 无调用方，不影响功能。可顺带改名（非必要） |

---

## 六、执行验证计划

1. 目录创建完成后：`ls -la release/` 确认结构
2. 构建脚本修改后：`bash script/build_and_run_codex.sh build` 验证
3. 构建后：`ls -la release/latest/` 确认产物已复制
4. release 模式：`RELEASE_VERSION=v0.1.2 bash script/build_and_run_codex.sh release` 验证
5. `cat release/versions.json` 确认版本记录已写入
6. `.gitignore` 验证：`git status --ignored` 确认二进制被忽略、元数据入库
