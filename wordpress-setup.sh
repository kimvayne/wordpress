#!/bin/bash

# 워드프레스 자동 설치 스크립트
# Oracle VM에서 워드프레스를 쉽게 설치하기 위한 스크립트입니다.

# 색상 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# 로그 함수
log() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# 사용자 입력 함수
get_input() {
    local prompt="$1"
    local default="$2"
    local result

    if [ -n "$default" ]; then
        read -p "$prompt [$default]: " result
        result=${result:-$default}
    else
        read -p "$prompt: " result
    fi

    echo "$result"
}

get_password() {
    local prompt="$1"
    local password
    local confirm_password
    
    while true; do
        read -s -p "$prompt: " password
        echo
        read -s -p "비밀번호 확인: " confirm_password
        echo
        
        if [ "$password" = "$confirm_password" ]; then
            break
        else
            warn "비밀번호가 일치하지 않습니다. 다시 시도해주세요."
        fi
    done
    
    echo "$password"
}

# 저장된 설정 파일 로드
load_config() {
    local config_file="$1"
    if [ -f "$config_file" ]; then
        log "설정 파일을 불러옵니다: $config_file"
        source "$config_file"
        return 0
    else
        return 1
    fi
}

# 설정 파일 저장
save_config() {
    local config_file="$1"
    
    cat > "$config_file" << EOF
# WordPress 설치 설정 파일
# 생성일: $(date)

# 도메인 설정
domain="$domain"

# 데이터베이스 설정
db_name="$db_name"
db_user="$db_user"
db_password="$db_password"

# DDNS 설정
use_ddns="$use_ddns"
ddns_provider="$ddns_provider"
ddns_login="$ddns_login"
ddns_password="$ddns_password"
ddns_domain="$ddns_domain"
EOF

    chmod 600 "$config_file"
    log "설정이 파일에 저장되었습니다: $config_file"
}

# 관리자 권한 확인
if [ "$EUID" -ne 0 ]; then
    error "이 스크립트는 관리자 권한으로 실행해야 합니다. sudo를 사용해주세요."
fi

clear
echo -e "${BLUE}==============================================${NC}"
echo -e "${BLUE}       워드프레스 자동 설치 스크립트         ${NC}"
echo -e "${BLUE}==============================================${NC}"
echo ""
echo "이 스크립트는 Ubuntu 서버에 워드프레스를 자동으로 설치합니다."
echo ""

# 설정 파일 선택 또는 생성
config_file="wp-setup-config.conf"
if [ "$1" ]; then
    config_file="$1"
fi

if load_config "$config_file"; then
    echo -e "다음 설정을 불러왔습니다:"
    echo "도메인: $domain"
    echo "데이터베이스 이름: $db_name"
    echo "데이터베이스 사용자: $db_user"
    echo "DDNS 사용: $use_ddns"
    
    use_loaded_config=$(get_input "이 설정을 사용하시겠습니까? (y/n)" "y")
    if [ "$use_loaded_config" != "y" ] && [ "$use_loaded_config" != "Y" ]; then
        # 사용자가 기존 설정을 사용하지 않기로 한 경우, 새 설정 입력
        config_loaded=false
    else
        config_loaded=true
    fi
else
    echo "설정 파일이 없거나 읽을 수 없습니다. 새 설정을 입력하세요."
    config_loaded=false
fi

# 새 설정 입력이 필요한 경우
if [ "$config_loaded" = false ]; then
    # 기본 정보 수집
    domain=$(get_input "도메인 이름을 입력하세요 (예: example.com)" "example.com")
    db_name=$(get_input "데이터베이스 이름" "wordpress")
    db_user=$(get_input "데이터베이스 사용자 이름" "wordpress")
    db_password=$(get_password "데이터베이스 비밀번호")

    # DDNS 사용 여부
    use_ddns=$(get_input "DDNS를 사용하시겠습니까? (y/n)" "n")

    if [ "$use_ddns" = "y" ] || [ "$use_ddns" = "Y" ]; then
        ddns_provider=$(get_input "DDNS 제공자 (cloudflare)" "cloudflare")
        ddns_login=$(get_input "DDNS 로그인 이메일 (Cloudflare 이메일)")
        ddns_password=$(get_password "DDNS API 토큰/비밀번호")
        ddns_domain=$(get_input "DDNS 업데이트할 도메인" "$domain")
    fi

    # 설정 저장 여부 확인
    save_settings=$(get_input "이 설정을 파일에 저장하시겠습니까? (y/n)" "y")
    if [ "$save_settings" = "y" ] || [ "$save_settings" = "Y" ]; then
        save_config "$config_file"
    fi
fi

echo ""
log "설치를 시작합니다..."
sleep 1

# 시스템 업데이트
log "시스템 업데이트 중..."
apt update -y && apt upgrade -y || error "시스템 업데이트 실패"

# 타임존 설정
log "타임존 설정 중..."
timedatectl set-timezone Asia/Seoul
timedatectl status | grep "Time zone"

# 방화벽 설정
log "방화벽 설정 중..."
ufw allow 22/tcp
ufw allow 80/tcp
ufw allow 443/tcp
ufw --force enable
ufw status

# 스왑 메모리 설정
log "스왑 메모리 설정 중..."
if [ ! -f /swapfile ]; then
    fallocate -l 4G /swapfile
    chmod 600 /swapfile
    mkswap /swapfile
    swapon /swapfile
    echo "/swapfile none swap sw 0 0" >> /etc/fstab
    swapon --show
    free -h
else
    warn "스왑 파일이 이미 존재합니다. 건너뜁니다."
fi

# 필요한 패키지 설치
log "필요한 패키지 설치 중..."
apt install -y mariadb-server mariadb-client nginx software-properties-common || error "패키지 설치 실패"

# PHP 8.2 설치
log "PHP 8.2 설치 중..."
add-apt-repository ppa:ondrej/php -y
apt update
apt install -y php8.2-fpm php8.2-mysql php8.2-curl php8.2-gd php8.2-mbstring php8.2-xml php8.2-xmlrpc php8.2-soap php8.2-intl php8.2-zip || error "PHP 설치 실패"

# PHP 설정
log "PHP 설정 수정 중..."
php_ini="/etc/php/8.2/fpm/php.ini"
sed -i '0,/short_open_tag = Off/{s/short_open_tag = Off/short_open_tag = On/}' $php_ini
sed -i 's/memory_limit = .*/memory_limit = 2048M/g' $php_ini
sed -i 's/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/g' $php_ini
sed -i 's/upload_max_filesize = .*/upload_max_filesize = 100M/g' $php_ini
sed -i 's/post_max_size = .*/post_max_size = 101M/g' $php_ini
sed -i 's/max_execution_time = .*/max_execution_time = 360/g' $php_ini
sed -i 's/;date.timezone.*/date.timezone = Asia\/Seoul/g' $php_ini

systemctl reload php8.2-fpm

# DDNS 설정 (선택 사항)
if [ "$use_ddns" = "y" ] || [ "$use_ddns" = "Y" ]; then
    log "ddclient 설치 및 설정 중..."
    apt install -y ddclient
    
    # Cloudflare 설정
    if [ "$ddns_provider" = "cloudflare" ]; then
        cat > /etc/ddclient.conf << EOF
daemon=300
syslog=yes
ssl=yes
use=web

protocol=cloudflare
zone=$ddns_domain
login=$ddns_login
password=$ddns_password
$ddns_domain
EOF
    fi
    
    systemctl restart ddclient
    systemctl enable ddclient
    log "ddclient 설정 완료. Cloudflare에서 DNS 레코드를 확인하세요."
fi

# MariaDB 보안 설정
log "MariaDB 보안 설정 중..."
mysql --user=root <<EOF
ALTER USER 'root'@'localhost' IDENTIFIED BY '$db_password';
DELETE FROM mysql.user WHERE User='';
DELETE FROM mysql.user WHERE User='root' AND Host NOT IN ('localhost', '127.0.0.1', '::1');
DROP DATABASE IF EXISTS test;
DELETE FROM mysql.db WHERE Db='test' OR Db='test\\_%';
FLUSH PRIVILEGES;
EOF

# 데이터베이스 및 사용자 생성
log "워드프레스 데이터베이스 생성 중..."
mysql --user=root --password="$db_password" <<EOF
CREATE DATABASE $db_name DEFAULT CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
CREATE USER '$db_user'@'localhost' IDENTIFIED BY '$db_password';
GRANT ALL ON $db_name.* TO '$db_user'@'localhost';
FLUSH PRIVILEGES;
EOF

# 워드프레스 다운로드 및 설치
log "워드프레스 다운로드 및 설치 중..."
cd /tmp
wget https://wordpress.org/latest.tar.gz
tar -xvzf latest.tar.gz
rm -rf /var/www/wordpress
mv wordpress /var/www/wordpress

# 권한 설정
chown -R www-data:www-data /var/www/wordpress/
chmod -R 755 /var/www/wordpress/

# wp-config.php 생성
log "워드프레스 설정 파일 생성 중..."
cp /var/www/wordpress/wp-config-sample.php /var/www/wordpress/wp-config.php
sed -i "s/database_name_here/$db_name/g" /var/www/wordpress/wp-config.php
sed -i "s/username_here/$db_user/g" /var/www/wordpress/wp-config.php
sed -i "s/password_here/$db_password/g" /var/www/wordpress/wp-config.php

# 보안 키 생성
log "보안 키 생성 중..."
KEYS=$(curl -s https://api.wordpress.org/secret-key/1.1/salt/)
KEYS=$(echo "$KEYS" | sed "s/[\']/\\\'/g")
sed -i "/define( 'AUTH_KEY'/,/define( 'NONCE_SALT'/ { d; }" /var/www/wordpress/wp-config.php
echo "$KEYS" >> /var/www/wordpress/wp-config.php

# 메모리 제한 추가
echo "define('WP_MEMORY_LIMIT', '1024M');" >> /var/www/wordpress/wp-config.php

# Nginx 설정
log "Nginx 설정 중..."
cat > /etc/nginx/sites-available/wordpress << EOF
server {
    listen 80;
    listen [::]:80;
    server_name $domain www.$domain;

    root /var/www/wordpress;

    index index.php;

    location ~ \.(gif|jpg|png)$ {
        add_header Vary "Accept-Encoding";
        add_header Cache-Control "public, no-transform, max-age=31536000";
    }
    location ~* \.(css|js)$ {
        add_header Cache-Control "public, max-age=604800";
        log_not_found off;
        access_log off;
    }
    location ~*.(mp4|ogg|ogv|svg|svgz|eot|otf|woff|woff2|ttf|rss|atom|ico|zip|tgz|gz|rar|bz2|doc|xls|exe|ppt|tar|mid|midi|wav|bmp|rtf|cur)$ {
        add_header Cache-Control "max-age=31536000";
        access_log off;
    }
    charset utf-8;
    server_tokens off;
    client_max_body_size 100M;
    
    # REST API 지원 추가
    location /wp-json/ {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    # WordPress 기본 설정
    location / {
        try_files \$uri \$uri/ /index.php?\$args;
    }
    
    location ~ /\.ht {
        deny all;
    }
    
    location ~ \.php$ {
         include snippets/fastcgi-php.conf;
         fastcgi_pass unix:/run/php/php8.2-fpm.sock;
         fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
         include fastcgi_params;
    }
}
EOF

ln -s /etc/nginx/sites-available/wordpress /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Certbot 설치
log "Certbot 설치 중..."
apt install -y python3-certbot-nginx

log "설치가 완료되었습니다!"
echo ""
echo -e "${BLUE}==============================================${NC}"
echo -e "${GREEN}워드프레스 설치 요약${NC}"
echo -e "${BLUE}==============================================${NC}"
echo "도메인: $domain"
echo "데이터베이스 이름: $db_name"
echo "데이터베이스 사용자: $db_user"
echo "워드프레스 디렉토리: /var/www/wordpress"
echo ""
echo "다음 단계:"
echo "1. DNS 설정이 완료되면 다음 명령어로 SSL 인증서를 설치하세요:"
echo "   sudo certbot --nginx -d $domain -d www.$domain"
echo ""
echo "2. 브라우저에서 http://$domain 에 접속하여 워드프레스 설정을 완료하세요."
echo -e "${BLUE}==============================================${NC}"

if [ "$use_ddns" = "y" ] || [ "$use_ddns" = "Y" ]; then
    echo ""
    echo -e "${YELLOW}DDNS 주의사항:${NC}"
    echo "Cloudflare를 사용하는 경우, SSL 인증서 발급 전에 DNS 레코드를 DNS-only 모드(회색 구름)로 설정하세요."
    echo "인증서 발급 후 원하는 대로 프록시(오렌지색 구름)로 변경할 수 있습니다."
    echo ""
fi

# 설치 로그 저장
log_file="wp-setup-$(date +%Y%m%d%H%M%S).log"
{
    echo "워드프레스 설치 로그"
    echo "설치 일시: $(date)"
    echo "도메인: $domain"
    echo "데이터베이스 이름: $db_name"
    echo "데이터베이스 사용자: $db_user"
    echo "워드프레스 디렉토리: /var/www/wordpress"
    echo "DDNS 사용: $use_ddns"
    if [ "$use_ddns" = "y" ] || [ "$use_ddns" = "Y" ]; then
        echo "DDNS 제공자: $ddns_provider"
        echo "DDNS 도메인: $ddns_domain"
    fi
} > "$log_file"
log "설치 로그가 $log_file 파일에 저장되었습니다."

# 시스템 재부팅 여부 확인
restart=$(get_input "설치를 완료하기 위해 시스템을 재부팅하시겠습니까? (y/n)" "y")
if [ "$restart" = "y" ] || [ "$restart" = "Y" ]; then
    log "시스템을 재부팅합니다..."
    sleep 3
    reboot
fi
