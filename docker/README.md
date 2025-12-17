# ArrayFire Docker Build System

完整的多平台多后端 ArrayFire 构建系统，支持自动化的包生成、发布和容器镜像管理。

## 功能

✅ **多平台支持**

- **Linux 发行版**: Debian 11/12/13, RHEL/CentOS 8/9/10
- **CPU 架构**: amd64 (x86_64), arm64

✅ **多后端支持**

- **all**: 所有后端 (CPU, CUDA, OpenCL)
- **cpu**: CPU 计算后端
- **cuda**: NVIDIA CUDA 后端
- **opencl**: OpenCL 后端
- **oneapi**: Intel oneAPI/SYCL 后端

✅ **自动化工作流**

- GitHub Actions 持续集成
- 构建产物自动上传到 GitHub Release
- 容器镜像自动推送到 ghcr.io
- 智能缓存加速构建

✅ **灵活部署**

- 本地 Docker 构建
- Docker Compose 编排
- 跨平台构建 (docker buildx)

## 快速开始

### 前置要求

- Docker >= 20.10
- Docker Compose >= 1.29（可选，用于编排）
- git >= 2.20
- Python 3.7+（用于构建矩阵脚本）

### 本地构建

#### 1. 基本构建 - 快速单个目标

```bash
# 进入 docker 目录
cd docker

# 构建 Debian 12 CPU 后端 amd64
./build.sh -d debian -v 12 -b cpu -a amd64

# 构建 RHEL 9 CUDA 后端 amd64
./build.sh -d rhel -v 9 -b cuda -a amd64
```

#### 2. 列出可用目标

```bash
./build.sh list --mvp
```

输出示例：

```
Available targets:
MVP (Minimum Viable Product):
  debian12-all-amd64
  debian12-all-arm64
  debian12-cpu-amd64
  debian12-cpu-arm64
  debian12-cuda-amd64
  debian12-opencl-amd64
  debian12-opencl-arm64
  rhel9-all-amd64
  rhel9-cuda-amd64
```

#### 3. 使用 Docker Compose 批量构建

```bash
# 构建所有 MVP 目标
docker-compose -f docker-compose.build.yml build

# 构建特定服务
docker-compose -f docker-compose.build.yml build debian12-cuda-amd64

# 运行构建并提取产物
docker-compose -f docker-compose.build.yml run debian12-cuda-amd64
```

#### 4. 使用 Python 构建矩阵工具

```bash
cd docker

# 列出所有目标
python3 build-matrix.py list

# 构建单个目标
python3 build-matrix.py build --target debian12-all-amd64

# 构建所有 MVP 目标
python3 build-matrix.py build --mvp

# 使用 buildx 跨平台构建（需要配置 buildx）
python3 build-matrix.py build --mvp --buildx --push
```

## 目录结构

```
.
├── docker/
│   ├── Dockerfile.debian          # Debian/Ubuntu 构建文件
│   ├── Dockerfile.rhel            # RHEL/CentOS 构建文件
│   ├── build-config.yaml          # 构建配置矩阵
│   ├── build-matrix.py            # Python 构建管理脚本
│   ├── build.sh                   # Shell 构建脚本
│   └── output/                    # 本地构建产物输出目录
├── docker-compose.build.yml       # Docker Compose 编排配置
├── .github/workflows/
│   └── build-release.yml          # GitHub Actions CI/CD 工作流
└── README.md                       # 本文档
```

## 构建配置详解

### Dockerfile 参数

所有 Dockerfile 都支持以下 ARG 参数：

| 参数                | 默认值  | 说明                                       |
| ------------------- | ------- | ------------------------------------------ |
| `DEBIAN_VERSION`    | 12      | Debian 版本 (11/12/13) - Dockerfile.debian |
| `RHEL_VERSION`      | 9       | RHEL 版本 (8/9/10) - Dockerfile.rhel       |
| `BACKEND`           | all     | 后端类型 (all/cpu/cuda/opencl/oneapi)      |
| `ARCH`              | amd64   | 架构 (amd64/arm64)                         |
| `ARRAYFIRE_VERSION` | 3.10    | ArrayFire 版本号                           |
| `ARRAYFIRE_RELEASE` | v3.10.0 | Git 发布标签                               |

### CMake 编译选项

基于选定后端，Dockerfile 会自动设置相应的 CMake 选项：

```bash
# CPU 后端
-DAF_BUILD_CPU=ON
-DAF_COMPUTE_LIBRARY=FFTW

# CUDA 后端
-DAF_BUILD_CUDA=ON
-DAF_WITH_CUDNN=OFF  # 可选：启用 cuDNN 加速

# OpenCL 后端
-DAF_BUILD_OPENCL=ON

# 通用选项
-DCMAKE_BUILD_TYPE=Release
-DAF_BUILD_EXAMPLES=ON
-DAF_BUILD_TESTS=ON
-DAF_WITH_LOGGING=ON
-DCMAKE_INSTALL_PREFIX=/opt/arrayfire
```

## 生成的产物

### Debian 包

构建完成后生成 `.deb` 包，位于 `docker/output/{target}/`:

```
arrayfire-{backend}_{version}_{arch}.deb
```

**示例：**

- `arrayfire-all_3.10_amd64.deb` - Debian 12 all 后端
- `arrayfire-cuda_3.10_amd64.deb` - Debian 12 CUDA 后端

**安装：**

```bash
sudo dpkg -i arrayfire-{backend}_3.10_amd64.deb
```

### RPM 包

RHEL 构建生成 `.rpm` 包，位于 `docker/output/{target}/`:

```
arrayfire-{backend}-{version}-1.{arch}.rpm
```

**示例：**

- `arrayfire-all-3.10-1.x86_64.rpm` - RHEL 9 all 后端

**安装：**

```bash
sudo rpm -ivh arrayfire-{backend}-3.10-1.x86_64.rpm
```

### 容器镜像

通过 GitHub Actions，构建的镜像自动推送到：

```
ghcr.io/dawnmagnet/arrayfire-{backend}:{version}-{distro}{version}-{arch}
```

**示例：**

```bash
# 拉取镜像
docker pull ghcr.io/dawnmagnet/arrayfire-cuda:3.10-debian12-amd64
docker pull ghcr.io/dawnmagnet/arrayfire-all:3.10-rhel9-amd64

# 运行容器
docker run -it ghcr.io/dawnmagnet/arrayfire-cuda:3.10-debian12-amd64 bash
```

## GitHub Actions 工作流

### 触发条件

工作流在以下情况自动执行：

1. **Push 到 main 分支**（docker/ 或 workflow 文件变更）
2. **每周日 02:00 UTC** - 定期完整构建
3. **手动触发** - workflow_dispatch 允许手动运行

### 工作流步骤

1. **prepare** - 生成构建矩阵和 build ID
2. **build** - 并行构建所有目标（支持缓存）
3. **publish** - 收集产物并创建 GitHub Release

### 手动触发

```bash
# 通过 GitHub CLI
gh workflow run build-release.yml -f build_mvp=true

# 或通过 GitHub Web UI
# 1. Actions → ArrayFire Build & Release
# 2. Run workflow
# 3. 选择选项并运行
```

## 缓存策略

### GitHub Actions 缓存

工作流使用 GitHub Actions 的 gha 缓存后端：

```yaml
cache-from: type=gha
cache-to: type=gha,mode=max
```

**优势：**

- 自动跨 workflow 共享缓存
- 支持多架构缓存
- 减少重复编译时间

### 本地缓存优化

如果使用 docker buildx：

```bash
# 创建持久化构建器实例
docker buildx create --name arrayfire-builder --driver docker-container
docker buildx use arrayfire-builder

# 启用 docker 内置缓存
docker build \
  --build-arg BUILDKIT_CONTEXT_KEEP_GIT_DIR=1 \
  --cache-from=type=local,src=/tmp/docker-cache \
  --cache-to=type=local,dest=/tmp/docker-cache,mode=max \
  ...
```

## 构建矩阵详解

### MVP (最小可行产品)

默认构建矩阵，包含核心组合：

| 发行版 | 版本 | 后端   | 架构        | 用途          |
| ------ | ---- | ------ | ----------- | ------------- |
| Debian | 12   | all    | amd64/arm64 | 全功能参考    |
| Debian | 12   | cpu    | amd64/arm64 | CPU 计算      |
| Debian | 12   | cuda   | amd64       | GPU 计算      |
| Debian | 12   | opencl | amd64/arm64 | 异构计算      |
| RHEL   | 9    | all    | amd64       | RHEL 标准配置 |
| RHEL   | 9    | cuda   | amd64       | RHEL GPU      |

**构建时间：** ~30-45 分钟（取决于缓存）

### 完整矩阵

扩展构建，支持所有版本和后端组合：

```
发行版: Debian 11/12/13 + RHEL 8/9/10 (6 种)
后端: all/cpu/cuda/opencl/oneapi (5 种)
架构: amd64/arm64 (2 种，某些后端仅支持 amd64)

总计：约 40-60 个目标
构建时间：~3-4 小时
```

启用完整矩阵：

```bash
# 通过 GitHub Actions
gh workflow run build-release.yml -f build_full=true

# 或本地测试（推荐分批构建）
python3 docker/build-matrix.py build --target debian11-all-amd64
python3 docker/build-matrix.py build --target debian12-all-amd64
# ...
```

## 故障排除

### 问题 1: 构建超时

**症状：** Docker 构建在编译 CUDA 时超时

**解决：**

```bash
# 增加构建资源
docker run --cpus=4 --memory=8g ...

# 或分离 CUDA 和 CPU 构建，分别构建
./build.sh -b cpu -d debian -v 12
./build.sh -b cuda -d debian -v 12
```

### 问题 2: 跨架构构建失败

**症状：** `exec format error` 当在 amd64 上构建 arm64

**解决：**

```bash
# 安装 qemu 用户空间模拟
sudo apt-get install qemu-user-static

# 或使用原生构建器在对应架构机器上执行
```

### 问题 3: NVIDIA 相关依赖缺失

**症状：** CUDA 后端构建失败，找不到 cuda-toolkit

**解决：**

```bash
# 官方 CUDA 仓库可能不支持某些 Debian 版本
# 使用社区维护的仓库或手动安装
# 或选择 CPU/OpenCL 后端代替
```

### 问题 4: 磁盘空间不足

**症状：** Docker 构建到中途报错 `no space left on device`

**解决：**

```bash
# 清理 Docker 缓存
docker system prune -a

# 或增加 Docker 磁盘空间
# Docker Desktop: Settings → Resources → Disk Image Size
```

## 高级用法

### 自定义构建

修改 `build-config.yaml` 添加新的平台组合：

```yaml
mvp_matrix:
  - distro: debian
    version: 12
    backend: custom-backend
    architectures: [amd64]
```

然后创建对应的依赖安装脚本。

### 添加新后端

1. 修改 Dockerfile 添加依赖安装逻辑
2. 更新 `build-config.yaml` 添加后端配置
3. 定义 CMake 选项

### 集成私有镜像仓库

修改 GitHub Actions 工作流 `build-release.yml`：

```yaml
- name: Push to private registry
  run: |
    docker tag ghcr.io/dawnmagnet/arrayfire-all:... \
               your-registry.com/arrayfire-all:...
    docker push your-registry.com/arrayfire-all:...
```

## 许可证和贡献

- ArrayFire 项目许可证：参见 [LICENSE](../LICENSE)
- 本构建系统基于 ArrayFire 官方构建流程
- 贡献和改进欢迎提交 PR

## 支持

- 问题报告: [GitHub Issues](https://github.com/arrayfire/arrayfire/issues)
- 讨论: [GitHub Discussions](https://github.com/arrayfire/arrayfire/discussions)
- 官网: https://arrayfire.com

---

**版本:** 1.0
**最后更新:** 2024-12-17
**ArrayFire 版本:** 3.10.0
