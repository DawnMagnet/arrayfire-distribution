# ArrayFire Docker 构建系统 - 配置指南

## 环境配置

### 1. Docker Buildx 跨平台构建设置

如果要支持多架构构建（如在 amd64 上构建 arm64），需要配置 buildx：

```bash
# 安装 QEMU 用户态仿真支持（可选，用于本地跨架构构建）
sudo apt-get install -y qemu-user-static binfmt-support

# 创建专用的 buildx 构建器实例
docker buildx create --name arrayfire-builder --driver docker-container --use

# 验证构建器
docker buildx ls
```

### 2. GitHub Actions 配置

#### 2.1 设置 Personal Access Token (PAT)

1. 访问 https://github.com/settings/tokens
2. 创建新 token，勾选：
   - `repo` (完整访问仓库)
   - `write:packages` (推送 packages)
   - `read:packages` (读取 packages)
3. 复制 token

#### 2.2 配置 Secrets

在 GitHub 仓库设置中添加：

```
Settings → Secrets and variables → Actions
```

需要添加的 secrets：

| Secret               | 说明                                                    |
| -------------------- | ------------------------------------------------------- |
| `GHCR_TOKEN`         | GitHub Container Registry token (默认使用 GITHUB_TOKEN) |
| `REGISTRY_USER`      | Registry 用户名 (default: dawnmagnet)                   |
| `BUILD_CACHE_BUCKET` | (可选) S3/OSS 用于外部缓存                              |

**默认配置：** 工作流使用 `GITHUB_TOKEN` 自动处理认证，无需额外配置。

#### 2.3 配置私有镜像仓库（可选）

编辑 `.github/workflows/build-release.yml`：

```yaml
# 修改 Docker 登录步骤
- name: Log in to Private Registry
  uses: docker/login-action@v3
  with:
    registry: your-registry.com
    username: ${{ secrets.PRIVATE_REGISTRY_USER }}
    password: ${{ secrets.PRIVATE_REGISTRY_PASSWORD }}

# 修改镜像推送标签
tags: |
  your-registry.com/arrayfire-${{ matrix.backend }}:${{ env.ARRAYFIRE_VERSION }}
```

### 3. 本地构建前置条件

#### 3.1 Linux (Debian/Ubuntu)

```bash
# 安装必要工具
sudo apt-get update
sudo apt-get install -y \
    docker.io \
    docker-compose \
    python3 \
    python3-pip \
    git \
    buildkit

# 启动 Docker 服务
sudo systemctl start docker
sudo usermod -aG docker $USER

# 安装 Python 依赖
pip3 install pyyaml
```

#### 3.2 macOS

```bash
# 使用 Homebrew 安装
brew install docker docker-compose python3

# 启动 Docker Desktop（GUI）或通过 colima
brew install colima
colima start

# 安装 Python 依赖
pip3 install pyyaml
```

#### 3.3 Windows

```powershell
# 使用 WSL2 + Docker Desktop
# 1. 启用 WSL2
wsl --install

# 2. 安装 Docker Desktop
# 下载: https://www.docker.com/products/docker-desktop

# 3. 在 PowerShell 或 WSL2 终端中安装 Python 依赖
pip3 install pyyaml
```

## 构建配置文件说明

### build-config.yaml 结构

```yaml
arrayfire:
  version: "3.10" # ArrayFire 主版本
  release: "v3.10.0" # Git 发布标签
  repo: "https://..." # 源代码仓库

platforms:
  debian:
    versions: [11, 12, 13] # 支持的 Debian 版本
  rhel:
    versions: [8, 9, 10] # 支持的 RHEL 版本

architectures: # 支持的架构
  - amd64
  - arm64

backends: # 后端配置
  all: # 后端名称
    display_name: "..." # 显示名称
    dependencies: [...] # 依赖项
    cmake_options: { ... } # CMake 编译选项
    package_name: "..." # 包名称

mvp_matrix: # MVP 构建矩阵
  - distro: debian # 发行版
    version: 12 # 版本
    backend: all # 后端
    architectures: # 架构
      - amd64
      - arm64
```

## 自定义构建

### 添加新的发行版

1. **更新 build-config.yaml：**

```yaml
platforms:
  alpine:
    versions: [3.18, 3.19]
    distributions:
      alpine:3.18:
        name: "Alpine 3.18"
        dockerfile: "Dockerfile.alpine"
```

2. **创建新的 Dockerfile：**

```dockerfile
# docker/Dockerfile.alpine
ARG ALPINE_VERSION=3.18
FROM alpine:${ALPINE_VERSION}

ARG ALPINE_VERSION
ARG BACKEND=all
ARG ARRAYFIRE_VERSION=3.10

# ... (依赖安装和构建步骤)
```

3. **更新 GitHub Actions 工作流：**

编辑 `.github/workflows/build-release.yml`，添加新的矩阵条目。

### 添加新的后端

1. **更新 build-config.yaml：**

```yaml
backends:
  custom-backend:
    display_name: "Custom Backend"
    dependencies: ["custom-lib"]
    cmake_options:
      AF_BUILD_CUSTOM: ON
      CUSTOM_LIBRARY_PATH: "/usr/local/custom"
    package_name: "arrayfire-custom"
```

2. **修改 Dockerfile：**

```dockerfile
# 在依赖安装部分添加条件
RUN if [ "${BACKEND}" = "all" ] || [ "${BACKEND}" = "custom-backend" ]; then \
    apt-get install -y custom-backend-dev; \
    fi

# 在 CMake 配置中添加分支
elif [ "${BACKEND}" = "custom-backend" ]; then \
    cmake -B build -G Ninja \
      -DAF_BUILD_CUSTOM_BACKEND=ON \
      ...; \
fi
```

### 修改构建参数

编辑 Dockerfile 中的 CMake 选项：

```dockerfile
# 例如，启用 cuDNN 支持
cmake -B build -G Ninja \
  -DAF_WITH_CUDNN=ON \
  -DcuDNN_ROOT=/usr/local/cuda \
  ...
```

## 性能优化

### 1. 本地构建缓存

```bash
# 使用 Docker BuildKit 本地缓存
export DOCKER_BUILDKIT=1

# 配置最大缓存大小
docker system prune --all --volumes --force

# 增加 Docker 磁盘空间
# Docker Desktop: Settings → Resources → Disk Image Size
```

### 2. 多层缓存策略

```bash
# 缓存依赖层
docker build -f docker/Dockerfile.debian \
  --target dependencies \
  -t arrayfire:debian12-deps:latest .

# 使用缓存构建
docker build -f docker/Dockerfile.debian \
  --cache-from=arrayfire:debian12-deps:latest \
  ...
```

### 3. GitHub Actions 缓存优化

```yaml
cache-from: |
  type=gha
  type=registry,ref=ghcr.io/${{ env.REGISTRY_USER }}/arrayfire-cache:${{ matrix.backend }}
cache-to: |
  type=gha,mode=max
  type=registry,ref=ghcr.io/${{ env.REGISTRY_USER }}/arrayfire-cache:${{ matrix.backend }},mode=max
```

## 问题诊断

### 查看构建日志

```bash
# 本地构建
docker build -f docker/Dockerfile.debian --progress=plain \
  --build-arg BACKEND=all .

# GitHub Actions
# 访问 Actions → 工作流 → 点击失败的 job → 查看日志
```

### 进入构建容器调试

```bash
# 构建到某个阶段后进入容器
docker run -it --entrypoint bash \
  $(docker build -f docker/Dockerfile.debian \
    --target builder --quiet .)
```

### 检查生成的产物

```bash
# 本地
ls -lh docker/output/debian12-all-amd64/

# GitHub Actions
# Artifacts → 下载对应构建的产物
```

## 版本升级

### 升级 ArrayFire 版本

1. **更新版本号：**

```bash
# 编辑 build-config.yaml
version: "3.11"          # 新版本号
release: "v3.11.0"       # 新的 git tag
```

2. **更新 GitHub Actions：**

```yaml
# .github/workflows/build-release.yml
env:
  ARRAYFIRE_VERSION: 3.11
```

3. **测试构建：**

```bash
cd docker
./build.sh list --mvp  # 验证配置
./build.sh -d debian -v 12 -b cpu --dry-run  # 模拟运行
```

### 回滚版本

```bash
# 恢复上一个版本
git checkout HEAD~1 build-config.yaml .github/workflows/build-release.yml

# 重新运行工作流
gh workflow run build-release.yml
```

## 安全考虑

### 1. 镜像扫描

```bash
# 本地扫描镜像漏洞
trivy image ghcr.io/dawnmagnet/arrayfire-all:3.10-debian12-amd64

# 在 GitHub Actions 中添加扫描
- uses: aquasecurity/trivy-action@master
  with:
    image-ref: ${{ steps.meta.outputs.full_image }}
```

### 2. 签名镜像

```bash
# 配置 Docker Content Trust
export DOCKER_CONTENT_TRUST=1

# 使用 cosign 签名
cosign sign --key cosign.key ghcr.io/dawnmagnet/arrayfire-all:3.10-debian12-amd64
```

### 3. 私密信息

- 不要在 Dockerfile 中硬编码密钥
- 使用 Docker secrets（Swarm 模式）或 BuildKit secrets
- 在 GitHub Actions 中使用 secrets 而非环境变量

## 参考资源

- [Docker 官方文档](https://docs.docker.com/)
- [Docker Buildx](https://docs.docker.com/build/architecture/)
- [GitHub Actions](https://docs.github.com/en/actions)
- [ArrayFire 官方文档](https://arrayfire.com/docs)
- [构建最佳实践](https://docs.docker.com/develop/dev-best-practices/)

---

**版本:** 1.0
**最后更新:** 2024-12-17
