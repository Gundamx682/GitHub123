#!/bin/bash

# GitHub Proxy Nginx 一键安装脚本
# 作者: iFlow CLI
# 描述: 自动安装 Nginx 并配置 GitHub 代理

set -e  # 遇到错误时退出

# 颜色定义
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# 打印带颜色的信息
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# 检查是否为root用户
check_root() {
    if [[ $EUID -eq 0 ]]; then
        print_info "当前为root用户，可以继续安装"
    else
        print_error "请使用root权限运行此脚本 (sudo ./install.sh)"
        exit 1
    fi
}

# 检测操作系统
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        DISTRO=$ID
    else
        print_error "无法检测操作系统"
        exit 1
    fi
    
    print_info "检测到操作系统: $OS ($DISTRO)"
}

# 安装 Nginx
install_nginx() {
    print_info "开始安装 Nginx..."
    
    case $DISTRO in
        ubuntu|debian)
            apt update
            apt install -y nginx
            ;;
        centos|rhel|fedora|rocky|almalinux)
            if [[ $DISTRO == "fedora" ]]; then
                dnf install -y nginx
            else
                yum install -y nginx
            fi
            ;;
        opensuse|opensuse-leap|opensuse-tumbleweed)
            zypper install -y nginx
            ;;
        arch|archlinux)
            pacman -Sy --noconfirm nginx
            ;;
        *)
            print_error "不支持的操作系统: $DISTRO"
            exit 1
            ;;
    esac
    
    print_info "Nginx 安装完成"
}

# 备份现有配置
backup_nginx_config() {
    if [[ -f /etc/nginx/nginx.conf ]]; then
        print_info "备份现有 Nginx 配置..."
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi
}

# 复制 GitHub 代理配置
setup_github_proxy_config() {
    print_info "配置 GitHub 代理..."
    
    # 复制配置文件到 Nginx 配置目录
    cp ./github-proxy.conf /etc/nginx/sites-available/github-proxy.conf
    
    # 创建软链接到 sites-enabled
    ln -sf /etc/nginx/sites-available/github-proxy.conf /etc/nginx/sites-enabled/
    
    # 如果是 Ubuntu/Debian，可能需要删除默认配置
    if [[ $DISTRO == "ubuntu" || $DISTRO == "debian" ]]; then
        rm -f /etc/nginx/sites-enabled/default
    fi
}

# 测试 Nginx 配置
test_nginx_config() {
    print_info "测试 Nginx 配置..."
    nginx -t
    if [[ $? -eq 0 ]]; then
        print_info "Nginx 配置测试通过"
    else
        print_error "Nginx 配置测试失败"
        exit 1
    fi
}

# 重启 Nginx 服务
restart_nginx() {
    print_info "重启 Nginx 服务..."
    
    systemctl enable nginx
    systemctl restart nginx
    
    if systemctl is-active --quiet nginx; then
        print_info "Nginx 服务已启动并设置为开机自启"
    else
        print_error "Nginx 服务启动失败"
        exit 1
    fi
}

# 检查端口是否开放
check_ports() {
    print_info "检查端口状态..."
    
    if command -v netstat >/dev/null 2>&1; then
        netstat -tuln | grep -E ':(80|8080|8081)\s'
    elif command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -E ':(80|8080|8081)\s'
    else
        print_warn "未找到 netstat 或 ss 命令，跳过端口检查"
        return
    fi
}

# 显示使用说明
show_usage() {
    print_info "GitHub Proxy 安装完成！"
    echo
    echo "配置说明:"
    echo "  - 端口 80: GitHub 主站代理"
    echo "  - 端口 8080: GitHub API 代理"
    echo "  - 端口 8081: GitHub Raw 内容代理"
    echo
    echo "使用方法:"
    echo "  1. 配置浏览器或系统代理 (如需要)"
    echo "  2. 或直接访问 http://<your-server-ip>:80 代理 GitHub 站点"
    echo "  3. 访问 http://<your-server-ip>:8080 代理 GitHub API"
    echo "  4. 访问 http://<your-server-ip>:8081 代理 GitHub Raw 内容"
    echo
    echo "管理命令:"
    echo "  - 重启 Nginx: sudo systemctl restart nginx"
    echo "  - 查看状态: sudo systemctl status nginx"
    echo "  - 查看日志: sudo journalctl -u nginx"
}

# 主函数
main() {
    print_info "开始安装 GitHub Proxy Nginx 配置..."
    
    check_root
    detect_os
    install_nginx
    backup_nginx_config
    setup_github_proxy_config
    test_nginx_config
    restart_nginx
    check_ports
    show_usage
    
    print_info "GitHub Proxy 安装完成！"
}

# 执行主函数
main "$@"