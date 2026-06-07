# WebTTY AUR Package

本目录包含 Arch Linux 用户仓库 (AUR) 包的相关文件。

## 目录结构

```
pkg/aur/
├── PKGBUILD           # 包构建脚本模板（CI 自动填充版本号）
├── webtty.install     # pacman 安装脚本（启用服务、生成密钥）
├── build-aur.sh       # 本地构建脚本
└── README.md          # 本文件
```

## 文件说明

### PKGBUILD

Arch Linux 包构建脚本，定义了：

- `pkgname` / `pkgver` / `pkgrel` — 包名、版本、发布号
- `depends` — 运行时依赖 (`glibc`, `gcc-libs`)
- `source` — 从 GitHub Release 下载可执行文件和 service 文件
- `package()` — 安装到 `/usr/bin/webtty` 和 `/usr/lib/systemd/system/`

CI 构建时会自动替换 `${VERSION}` 为实际版本号。

### webtty.install

pacman 安装钩子脚本，包含：

| 函数 | 触发时机 | 功能 |
|------|----------|------|
| `post_install()` | 首次安装后 | 创建目录、生成密钥、显示启动命令 |
| `post_upgrade()` | 升级后 | 重启服务（如果正在运行） |
| `pre_remove()` | 卸载前 | 停止并禁用服务 |
| `post_remove()` | 卸载后 | 提示清理数据命令 |

### build-aur.sh

本地构建脚本，用于在 Arch Linux 系统上测试打包。

## 安装方式

### 从 GitHub Release 安装（推荐）

```bash
# 下载预编译的 pkg 文件
wget https://github.com/anthropics/webtty/releases/download/v1.0.0/webtty-1.0.0-1-x86_64.pkg.tar.zst

# 安装
sudo pacman -U webtty-1.0.0-1-x86_64.pkg.tar.zst

# 启用并启动服务
sudo systemctl enable --now webtty
```

### 从 AUR 助手安装（发布到 AUR 后可用）

```bash
# 使用 yay
yay -S webtty

# 使用 paru
paru -S webtty
```

### 手动构建安装

```bash
# 克隆项目
git clone https://github.com/anthropics/webtty.git
cd webtty

# 构建 AUR 包
./pkg/aur/build-aur.sh 1.0.0

# 安装
sudo pacman -U webtty-1.0.0-1-x86_64.pkg.tar.zst
```

## 本地构建

使用 `build-aur.sh` 脚本：

```bash
# 构建指定版本
./pkg/aur/build-aur.sh 1.0.0

# 使用 git tag 版本
git tag v1.0.0
./pkg/aur/build-aur.sh

# 清理构建产物
./pkg/aur/build-aur.sh --clean
```

### 要求

- Arch Linux 或 Arch-based 发行版
- `base-devel` 包组（包含 makepkg, fakeroot）
- 不能以 root 用户运行

## CI 自动构建

推送 v* tag 到 main 分支时，GitHub Actions 会自动：

1. 在 Arch Linux 容器中构建可执行文件
2. 使用 makepkg 构建 `.pkg.tar.zst` 包
3. 上传到 GitHub Release

## 卸载

```bash
# 卸载（保留配置和数据）
sudo pacman -R webtty

# 完全卸载（包括配置和数据）
sudo pacman -Rn webtty
sudo rm -rf /var/lib/webtty /etc/webtty
```

## 文件路径

| 路径 | 说明 |
|------|------|
| `/usr/bin/webtty` | 可执行文件 |
| `/usr/lib/systemd/system/webtty.service` | systemd 服务 |
| `/etc/webtty/webtty.env` | 配置文件 |
| `/var/lib/webtty/` | 数据目录 |

## 相关资源

- [PKGBUILD 文档](https://wiki.archlinux.org/title/PKGBUILD)
- [AUR 提交指南](https://wiki.archlinux.org/title/AUR_submission_guidelines)
- [pacman 使用指南](https://wiki.archlinux.org/title/Pacman)
