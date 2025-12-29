#!/bin/bash

# CentOS 7 GitHub Proxy Nginx 一键安装脚本
# 作者: iFlow CLI
# 描述: 在 CentOS 7 上自动安装 Nginx 并配置 GitHub 代理

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
        print_error "请使用root权限运行此脚本 (sudo ./centos7-install.sh)"
        exit 1
    fi
}

# 检测操作系统版本
detect_os() {
    if [[ -f /etc/os-release ]]; then
        . /etc/os-release
        OS=$NAME
        VERSION=$VERSION_ID
    else
        print_error "无法检测操作系统"
        exit 1
    fi
    
    if [[ "$ID" != "centos" ]] || [[ "$VERSION" != "7" ]]; then
        print_error "此脚本专为 CentOS 7 设计，当前系统: $OS $VERSION"
        exit 1
    fi
    
    print_info "检测到操作系统: $OS $VERSION (CentOS 7)"
}

# 更新系统并安装必要工具
update_system() {
    print_info "更新系统包..."
    yum update -y
}

# 安装 Nginx (CentOS 7 需要先添加 EPEL 仓库)
install_nginx() {
    print_info "开始安装 Nginx..."
    
    # 安装 EPEL 仓库
    print_info "安装 EPEL 仓库..."
    yum install -y epel-release
    
    # 如果 EPEL 安装失败，尝试手动添加
    if ! rpm -q epel-release >/dev/null 2>&1; then
        print_info "手动添加 EPEL 仓库..."
        yum install -y https://dl.fedoraproject.org/pub/epel/epel-release-latest-7.noarch.rpm
    fi
    
    # 安装 nginx
    print_info "安装 Nginx..."
    yum install -y nginx
    
    print_info "Nginx 安装完成"
}

# 启用并启动防火墙端口
configure_firewall() {
    print_info "配置防火墙，开放必要端口..."
    
    # 检查是否安装了 firewalld
    if systemctl list-unit-files | grep -q firewalld; then
        systemctl enable firewalld
        systemctl start firewalld
        
        # 开放 HTTP (80), 8080, 8081 端口
        firewall-cmd --permanent --add-port=80/tcp
        firewall-cmd --permanent --add-port=8080/tcp
        firewall-cmd --permanent --add-port=8081/tcp
        firewall-cmd --reload
        
        print_info "防火墙配置完成"
    else
        # 检查是否使用 iptables
        if rpm -q iptables-services >/dev/null 2>&1; then
            systemctl enable iptables
            systemctl start iptables
            
            # 添加规则
            iptables -I INPUT -p tcp -m tcp --dport 80 -j ACCEPT
            iptables -I INPUT -p tcp -m tcp --dport 8080 -j ACCEPT
            iptables -I INPUT -p tcp -m tcp --dport 8081 -j ACCEPT
            service iptables save
            
            print_info "iptables 防火墙配置完成"
        else
            print_warn "未检测到 firewalld 或 iptables，跳过防火墙配置"
        fi
    fi
}

# 备份现有配置
backup_nginx_config() {
    if [[ -f /etc/nginx/nginx.conf ]]; then
        print_info "备份现有 Nginx 配置..."
        cp /etc/nginx/nginx.conf /etc/nginx/nginx.conf.backup.$(date +%Y%m%d_%H%M%S)
    fi
}

# 创建 Nginx 主配置文件，包含 GitHub 代理配置
setup_nginx_config() {
    print_info "配置 Nginx 和 GitHub 代理..."
    
    # 检查 github-proxy.conf 文件是否存在
    if [[ ! -f ./github-proxy.conf ]]; then
        print_error "配置文件 github-proxy.conf 不存在于当前目录"
        exit 1
    fi
    
    # 创建主配置文件
    cat > /etc/nginx/nginx.conf << 'EOF'
user nginx;
worker_processes auto;
error_log /var/log/nginx/error.log;
pid /run/nginx.pid;

include /usr/share/nginx/modules/*.conf;

events {
    worker_connections 1024;
}

# GitHub 代理配置
http {
    log_format  main  '$remote_addr - $remote_user [$time_local] "$request" '
                      '$status $body_bytes_sent "$http_referer" '
                      '"$http_user_agent" "$http_x_forwarded_for"';

    access_log  /var/log/nginx/access.log  main;

    sendfile            on;
    tcp_nopush          on;
    tcp_nodelay         on;
    keepalive_timeout   65;
    types_hash_max_size 2048;

    include             /etc/nginx/mime.types;
    default_type        application/octet-stream;

    # 引入 GitHub 代理配置
    include /etc/nginx/github-proxy.conf;
}
EOF

    # 创建配置目录（如果不存在）
    mkdir -p /etc/nginx/sites-available
    mkdir -p /etc/nginx/sites-enabled

    # 复制 GitHub 代理配置文件
    cp ./github-proxy.conf /etc/nginx/github-proxy.conf
    
    # 如果存在默认配置，备份并移除
    if [[ -f /etc/nginx/conf.d/default.conf ]]; then
        mv /etc/nginx/conf.d/default.conf /etc/nginx/conf.d/default.conf.backup.$(date +%Y%m%d_%H%M%S)
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

# 启动 Nginx 服务并设置开机自启
start_nginx() {
    print_info "启动 Nginx 服务..."
    
    systemctl enable nginx
    systemctl start nginx
    
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
        netstat -tuln | grep -E ':(80|8080|8081)\s' || echo "端口可能未在监听，稍后检查服务状态"
    elif command -v ss >/dev/null 2>&1; then
        ss -tuln | grep -E ':(80|8080|8081)\s' || echo "端口可能未在监听，稍后检查服务状态"
    else
        print_warn "未找到 netstat 或 ss 命令，跳过端口检查"
        return
    fi
}

# 检查服务状态
check_service_status() {
    print_info "检查 Nginx 服务状态..."
    systemctl status nginx --no-pager
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
    echo "  1. 直接访问 http://<your-server-ip>:80 代理 GitHub 站点"
    echo "  2. 访问 http://<your-server-ip>:8080 代理 GitHub API"
    echo "  3. 访问 http://<your-server-ip>:8081 代理 GitHub Raw 内容"
    echo
    echo "管理命令:"
    echo "  - 重启 Nginx: sudo systemctl restart nginx"
    echo "  - 查看状态: sudo systemctl status nginx"
    echo "  - 查看日志: sudo journalctl -u nginx -f"
    echo "  - 测试配置: sudo nginx -t"
    echo
    echo "注意: 如果无法访问，请检查防火墙设置"
}

# 主函数
main() {
    print_info "开始为 CentOS 7 安装 GitHub Proxy Nginx 配置..."
    
    check_root
    detect_os
    update_system
    install_nginx
    configure_firewall
    backup_nginx_config
    setup_nginx_config
    test_nginx_config
    start_nginx
    check_ports
    check_service_status
    show_usage
    
    print_info "GitHub Proxy 在 CentOS 7 上安装完成！"
}

# 执行主函数
main "$@"