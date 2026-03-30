# ArDNSPod

基于DNSPod用户API实现的纯Shell动态域名客户端，适配网卡地址。

## 特性

- ✅ 纯Shell实现，无外部依赖
- ✅ 支持Token认证和邮箱密码认证
- ✅ 跨平台支持（Linux/Mac）
- ✅ 自动检测IP变化并更新DNS记录
- ✅ 支持多域名管理
- ✅ 智能延时策略，避免API限制
- ✅ Docker容器化部署

## 快速开始

### 方式一：直接运行

复制 `dns.conf.example` 到同一目录下的 `dns.conf` 并根据你的配置修改即可。

执行时直接运行 `ddnspod.sh`，支持cron任务。

配置文件格式：
```
# 安全起见，不推荐使用密码认证
# arMail="test@gmail.com"
# arPass="123"

# 推荐使用Token认证
# 按`TokenID,Token`格式填写
arToken="12345,7676f344eaeaea9074c123451234512d"

# 每行一个域名
arDdnsCheck "test.org" "subdomain"
arDdnsCheck "test.org" "www"
```

### 方式二：Docker部署（推荐）

使用 Docker Compose 一键部署：

```bash
# 1. 构建并启动
docker-compose up -d

# 2. 查看日志
docker-compose logs -f

# 3. 查看DDNS更新日志
tail -f logs/ddns.log
```

#### Docker Compose 配置

```yaml
services:
  dnspod-ddns:
    build: .
    image: dnspod-ddns:latest
    container_name: dnspod-ddns
    restart: unless-stopped
    network_mode: host
    environment:
      - DDNS_INTERFACE=${DDNS_INTERFACE:-}
    volumes:
      - ./dns.conf:/app/dns.conf:ro
      - ./logs:/var/log
    logging:
      driver: "json-file"
      options:
        max-size: "10m"
        max-file: "3"
```

#### 常用命令

```bash
# 查看容器日志
docker logs -f dnspod-ddns

# 手动触发更新
docker exec dnspod-ddns /app/ddnspod.sh

# 进入容器
docker exec -it dnspod-ddns sh

# 重启容器
docker restart dnspod-ddns
```

#### 快速构建脚本

提供自动化构建脚本，一键完成更新、构建、部署：

**Windows PowerShell:**
```powershell
# 执行所有步骤
.\build.ps1

# 跳过代码更新
.\build.ps1 -SkipPull

# 仅构建镜像
.\build.ps1 -Action build

# 查看帮助
.\build.ps1 -Help
```

**Linux/Mac Shell:**
```bash
# 添加执行权限
chmod +x build.sh

# 执行所有步骤
./build.sh

# 跳过代码更新
./build.sh --skip-pull

# 仅构建镜像
./build.sh build

# 查看帮助
./build.sh --help
```

**脚本执行步骤：**
1. 从 GitHub 拉取最新代码
2. 停止运行中的容器
3. 删除旧镜像
4. 构建新镜像
5. 启动容器（-d 后台模式）
6. 清理悬空镜像

#### 镜像信息

- **基础镜像**: Alpine Linux (约5MB)
- **最终镜像大小**: 约15MB
- **包含工具**: wget, iproute2, grep, gawk, sed, bash

## 多域名绑定延时策略

### 问题背景

DNSPod API 对频繁更新有限制：
- 如果1小时内对同一记录提交超过5次**无效更新**（IP未变化但仍提交更新），该记录会被锁定1小时
- 多个子域名连续快速更新可能触发API频率限制

### 解决方案

在 `ddnspod.sh` 中实现了智能延时策略：

```sh
# 在 arDdnsCheck 函数中
if [ "$lastIP" != "$hostIP" ]; then
    # IP变化 → 调用更新API
    postRS=$(arDdnsUpdate $1 $2)
    sleep 2  # 更新成功后延迟2秒
else
    # IP未变化 → 不调用更新API
    echo "Last IP is the same as current IP!"
fi
```

### 工作原理

1. **智能判断**：只在IP真正变化时才调用更新API
2. **自动延迟**：每次成功更新后延迟2秒，避免短时间内的连续请求
3. **按序执行**：多个子域名按配置顺序依次更新

### 执行流程示例

```
定时任务触发
    ↓
检查 sub1.example.com
    ├─ IP未变化 → 跳过更新（无延迟）
    └─ IP已变化 → 更新成功 → 延迟2秒
    ↓
检查 sub2.example.com
    ├─ IP未变化 → 跳过更新（无延迟）
    └─ IP已变化 → 更新成功 → 延迟2秒
    ↓
检查 www.example.com
    ├─ IP未变化 → 跳过更新（无延迟）
    └─ IP已变化 → 更新成功
```

### 优势

- ✅ **避免API限制**：只在真正需要时才更新
- ✅ **智能延迟**：只在更新成功时才延迟，IP未变化时无延迟
- ✅ **稳定可靠**：确保多个子域名都能顺利更新
- ✅ **符合规范**：完全符合DNSPod API使用规范

### 注意事项

1. **定时任务频率**：建议每3-5分钟检查一次
2. **日志监控**：关注 `API usage is limited` 错误
3. **配置顺序**：重要域名建议放在配置文件前面

## 定时任务配置

### Crontab 示例

```bash
# 每5分钟检查一次
*/5 * * * * /path/to/ddnspod.sh >> /var/log/ddns.log 2>&1

# 每4小时的10分更新一次
10 */4 * * * /path/to/ddnspod.sh >> /var/log/ddns.log 2>&1
```

### Docker中的定时任务

Docker容器中已预配置cron任务，默认每4小时的10分更新一次：
```
10 */4 * * * /app/ddnspod.sh >> /var/log/ddns.log 2>&1
```

如需修改，编辑 `crontab` 后重新构建镜像。

## 故障排查

### IP获取机制

脚本使用以下方式获取公网IP（按优先级）：

1. **本地网卡**：直接从网卡获取公网IP
2. **外部服务**：
   - `http://ip.3322.net`（优先，兼容VPN环境）
   - `https://api.ipify.org`（备用）
   - `https://icanhazip.com`（备用）

**VPN环境注意事项**：
- 如果使用VPN，部分外部服务可能返回VPN出口IP
- 脚本优先使用 `ip.3322.net`，该服务通常不走VPN代理
- 如需指定网卡，可设置环境变量 `DDNS_INTERFACE=eth0`

### 检查配置文件

```bash
# 直接运行
cat dns.conf

# Docker环境
docker exec dnspod-ddns cat /app/dns.conf
```

### 手动测试

```bash
# 直接运行
./ddnspod.sh

# Docker环境
docker exec dnspod-ddns /app/ddnspod.sh
```

### 查看日志

```bash
# 直接运行
tail -f /var/log/ddns.log

# Docker环境
tail -f logs/ddns.log
# 或
docker exec dnspod-ddns tail -f /var/log/ddns.log
```

### 常见错误

| 错误信息 | 原因 | 解决方案 |
|---------|------|---------|
| `API usage is limited` | API调用频率过高 | 检查脚本逻辑，确保IP未变化时不更新 |
| `Get Record Info Failed!` | 域名或记录不存在 | 检查域名配置，确保已在DNSPod后台添加记录 |
| `Update Failed! Please check your network.` | 网络问题或IP获取失败 | 检查网络连接和IP获取逻辑 |

## 安全建议

1. **使用Token认证**：不推荐使用邮箱密码认证
2. **定期更新Token**：建议每3-6个月更新一次
3. **配置文件保护**：不要将包含Token的配置文件提交到版本控制
4. **只读挂载**：Docker部署时使用 `:ro` 标志挂载配置文件
5. **日志监控**：定期检查日志，及时发现异常

## 最近更新

### 2026-03-31
- 增加多域名绑定智能延时策略
- 添加Docker容器化部署支持
- 优化IP获取机制，优先使用 `ip.3322.net` 兼容VPN环境
- 添加 `network_mode: host` 支持获取真实公网IP
- 新增自动化构建脚本 `build.ps1` 和 `build.sh`
- 完善文档和部署说明

### 2016/3/23
- 进一步POSIX化，支持Mac和大部分Linux发行版
- 更改配置文件格式

### 2016/2/25
- 增加配置文件，分离脚本与配置，适配内网
- 加入Mac支持
- sed脚本POSIX化，可跨平台

### 2015/7/7
- 使用D+服务获取域名解析

### 2015/2/24
- 增加token鉴权方式 (by wbchn)

## Credit

Original: anrip

This version maintained by ProfFan

Enhanced with Docker support and smart delay strategy
