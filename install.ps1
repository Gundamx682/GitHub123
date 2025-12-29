# PowerShell 脚本：安装 Nginx 并配置 GitHub 代理
# 作者: iFlow CLI
# 描述: 在 Windows 上安装 Nginx 并配置 GitHub 代理

# 设置错误处理
$ErrorActionPreference = "Stop"

# 输出带颜色的信息
function Write-Info {
    param([string]$Message)
    Write-Host "[INFO] $Message" -ForegroundColor Green
}

function Write-Warning {
    param([string]$Message)
    Write-Host "[WARN] $Message" -ForegroundColor Yellow
}

function Write-Error {
    param([string]$Message)
    Write-Host "[ERROR] $Message" -ForegroundColor Red
}

function Write-Verbose {
    param([string]$Message)
    Write-Host "[VERBOSE] $Message" -ForegroundColor Cyan
}

# 主函数
function Main {
    Write-Info "开始安装 GitHub Proxy Nginx 配置..."

    # 检查管理员权限
    Check-AdminPermissions

    # 下载并安装 Nginx
    Install-Nginx

    # 配置 GitHub 代理
    Configure-GitHubProxy

    # 启动 Nginx 服务
    Start-Nginx

    # 显示使用说明
    Show-Usage
}

# 检查管理员权限
function Check-AdminPermissions {
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Error "请以管理员身份运行此脚本"
        exit 1
    }
    
    Write-Info "当前为管理员权限，可以继续安装"
}

# 安装 Nginx
function Install-Nginx {
    Write-Info "开始安装 Nginx..."

    # 检查是否已安装 Nginx
    $nginxPath = "C:\nginx"
    if (Test-Path $nginxPath) {
        Write-Warning "Nginx 已存在，将进行配置更新"
    } else {
        # 创建临时目录
        $tempDir = Join-Path $env:TEMP "nginx-install"
        if (-not (Test-Path $tempDir)) {
            New-Item -ItemType Directory -Path $tempDir | Out-Null
        }

        # 下载 Nginx
        $nginxUrl = "http://nginx.org/download/nginx-1.24.0.zip"
        $nginxZip = Join-Path $tempDir "nginx-1.24.0.zip"
        
        Write-Info "正在下载 Nginx..."
        try {
            Invoke-WebRequest -Uri $nginxUrl -OutFile $nginxZip -UseBasicParsing
        } catch {
            Write-Error "下载 Nginx 失败: $($_.Exception.Message)"
            exit 1
        }

        # 解压 Nginx
        Write-Info "正在解压 Nginx..."
        try {
            Expand-Archive -Path $nginxZip -DestinationPath $tempDir -Force
            Copy-Item -Path "$tempDir\nginx-1.24.0" -Destination $nginxPath -Recurse
        } catch {
            Write-Error "解压 Nginx 失败: $($_.Exception.Message)"
            exit 1
        }

        # 清理临时文件
        Remove-Item -Path $tempDir -Recurse -Force
    }

    Write-Info "Nginx 安装/配置完成"
}

# 配置 GitHub 代理
function Configure-GitHubProxy {
    Write-Info "配置 GitHub 代理..."

    # 检查 github-proxy.conf 文件是否存在
    $configFile = Join-Path $PSScriptRoot "github-proxy.conf"
    $nginxConfPath = Join-Path "C:\nginx\conf" "nginx.conf"

    if (-not (Test-Path $configFile)) {
        Write-Error "配置文件 github-proxy.conf 不存在于当前目录"
        exit 1
    }

    # 读取原始 nginx.conf
    $nginxConfContent = Get-Content $nginxConfPath -Raw

    # 创建备份
    $backupPath = "$nginxConfPath.backup.$(Get-Date -Format 'yyyyMMdd_HHmmss')"
    $nginxConfContent | Out-File -FilePath $backupPath -Encoding UTF8
    Write-Info "已备份原始配置到 $backupPath"

    # 读取 github-proxy.conf 内容
    $proxyConfContent = Get-Content $configFile -Raw

    # 替换 nginx.conf 中的 http 块，插入我们的配置
    # 找到 http 块的开始和结束位置
    $httpStartIndex = $nginxConfContent.IndexOf('http {')
    if ($httpStartIndex -eq -1) {
        Write-Error "在 nginx.conf 中未找到 http 块"
        exit 1
    }

    # 找到 http 块的结束位置（匹配大括号）
    $braceCount = 0
    $httpEndIndex = -1
    $contentArray = $nginxConfContent.ToCharArray()
    for ($i = $httpStartIndex; $i -lt $contentArray.Length; $i++) {
        if ($contentArray[$i] -eq '{') {
            $braceCount++
        } elseif ($contentArray[$i] -eq '}') {
            $braceCount--
            if ($braceCount -eq 0) {
                $httpEndIndex = $i
                break
            }
        }
    }

    if ($httpEndIndex -eq -1) {
        Write-Error "无法找到 http 块的结束位置"
        exit 1
    }

    # 提取 http 块内容
    $httpBlock = $nginxConfContent.Substring($httpStartIndex, $httpEndIndex - $httpStartIndex + 1)

    # 构建新的 http 块，包含我们的配置
    $newHttpBlock = $httpBlock -replace '}\s*$', "`n    # GitHub Proxy Configuration`n$proxyConfContent`n}"
    
    # 替换原配置
    $newNginxConf = $nginxConfContent.Substring(0, $httpStartIndex) + $newHttpBlock + $nginxConfContent.Substring($httpEndIndex + 1)

    # 写入新配置
    $newNginxConf | Out-File -FilePath $nginxConfPath -Encoding UTF8

    Write-Info "GitHub 代理配置已应用"
}

# 启动 Nginx
function Start-Nginx {
    Write-Info "启动 Nginx 服务..."

    $nginxExe = Join-Path "C:\nginx" "nginx.exe"

    # 检查 Nginx 是否已在运行
    $nginxProcess = Get-Process -Name "nginx" -ErrorAction SilentlyContinue
    if ($nginxProcess) {
        Write-Info "停止现有 Nginx 进程..."
        try {
            & $nginxExe -s quit
            Start-Sleep -Seconds 3
        } catch {
            Write-Warning "无法优雅停止 Nginx，可能需要手动停止"
        }
    }

    # 启动 Nginx
    try {
        & $nginxExe
        Start-Sleep -Seconds 2
        
        # 验证 Nginx 是否启动成功
        $nginxProcess = Get-Process -Name "nginx" -ErrorAction SilentlyContinue
        if ($nginxProcess) {
            Write-Info "Nginx 已成功启动"
        } else {
            Write-Error "Nginx 启动失败"
            exit 1
        }
    } catch {
        Write-Error "启动 Nginx 失败: $($_.Exception.Message)"
        exit 1
    }

    # 测试配置
    try {
        & $nginxExe -t
        if ($LASTEXITCODE -eq 0) {
            Write-Info "Nginx 配置测试通过"
        } else {
            Write-Error "Nginx 配置测试失败"
            exit 1
        }
    } catch {
        Write-Error "Nginx 配置测试失败: $($_.Exception.Message)"
        exit 1
    }
}

# 显示使用说明
function Show-Usage {
    Write-Info "GitHub Proxy 安装完成！"
    Write-Host ""
    Write-Host "配置说明:" -ForegroundColor Yellow
    Write-Host "  - 端口 80: GitHub 主站代理" -ForegroundColor Yellow
    Write-Host "  - 端口 8080: GitHub API 代理" -ForegroundColor Yellow
    Write-Host "  - 端口 8081: GitHub Raw 内容代理" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "使用方法:" -ForegroundColor Yellow
    Write-Host "  1. 确保防火墙允许 80, 8080, 8081 端口访问" -ForegroundColor Yellow
    Write-Host "  2. 在浏览器中访问 http://localhost 或 http://<your-server-ip> 代理 GitHub 站点" -ForegroundColor Yellow
    Write-Host "  3. 访问 http://<your-server-ip>:8080 代理 GitHub API" -ForegroundColor Yellow
    Write-Host "  4. 访问 http://<your-server-ip>:8081 代理 GitHub Raw 内容" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "管理命令:" -ForegroundColor Yellow
    Write-Host "  - 重启 Nginx: C:\nginx\nginx.exe -s reload" -ForegroundColor Yellow
    Write-Host "  - 停止 Nginx: C:\nginx\nginx.exe -s quit" -ForegroundColor Yellow
    Write-Host "  - 检查配置: C:\nginx\nginx.exe -t" -ForegroundColor Yellow
}

# 执行主函数
Main
