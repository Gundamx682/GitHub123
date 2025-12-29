# GitHub Proxy Nginx 配置

一个用于加速访问 GitHub 资源的 Nginx 代理配置，可以帮助解决访问 GitHub 速度慢的问题。

## 功能特性

- 代理 GitHub 主站访问
- 代理 GitHub API 调用
- 代理 GitHub Raw 内容访问
- 支持 Linux 和 Windows 系统一键安装

## 端口说明

- 端口 80: GitHub 主站代理
- 端口 8080: GitHub API 代理  
- 端口 8081: GitHub Raw 内容代理

## 安装方法

### Linux/macOS

```bash
# 克隆项目
git clone https://github.com/your-username/github-proxy.git
cd github-proxy

# 给脚本执行权限
chmod +x install.sh

# 运行安装脚本 (需要 root 权限)
sudo ./install.sh
```

### Windows

```powershell
# 下载项目文件到本地
# 以管理员身份运行 PowerShell
# 进入项目目录并执行安装脚本
.\install.ps1
```

## 使用方法

### 直接访问代理

访问以下地址来使用代理:

- GitHub 主站: `http://<your-server-ip>:80`
- GitHub API: `http://<your-server-ip>:8080`
- GitHub Raw 内容: `http://<your-server-ip>:8081`

### 配置系统代理

您可以将代理配置到系统或浏览器中:

1. 将代理服务器设置为您的服务器 IP
2. 端口设置为 80 (或根据需要选择 8080, 8081)

## 配置文件

- `github-proxy.conf`: Nginx 配置文件，定义了代理规则

## 管理命令

### Linux/macOS

```bash
# 重启 Nginx
sudo systemctl restart nginx

# 查看 Nginx 状态
sudo systemctl status nginx

# 查看 Nginx 日志
sudo journalctl -u nginx
```

### Windows

```powershell
# 重启 Nginx
C:\nginx\nginx.exe -s reload

# 停止 Nginx
C:\nginx\nginx.exe -s quit

# 检查配置
C:\nginx\nginx.exe -t
```

## 自定义配置

您可以根据需要修改 `github-proxy.conf` 文件，例如:

- 更改监听端口
- 添加更多 GitHub 相关域名
- 调整缓存策略
- 设置访问限制

## 注意事项

1. 确保服务器防火墙开放相应的端口 (80, 8080, 8081)
2. 一键安装脚本会自动备份原有 Nginx 配置
3. Windows 版本会安装 Nginx 到 `C:\nginx` 目录
4. Linux 版本需要 root 权限进行安装

## 故障排除

如果遇到问题，请检查:

1. 端口是否被占用
2. 防火墙设置
3. Nginx 配置语法 (`nginx -t`)
4. 系统日志

## 许可证

MIT License