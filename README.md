# 워드프레스 자동 설치 스크립트

## 🚀 소개

이 스크립트는 Oracle VM(또는 Ubuntu 서버)에 워드프레스를 쉽고 빠르게 설치하기 위한 자동화 솔루션입니다. 터미널 명령어 몇 개만으로 전체 워드프레스 환경을 구성할 수 있습니다.

## ✨ 주요 기능

- ⏱️ 시간대를 한국 시간(Asia/Seoul)으로 설정
- 🔒 기본 방화벽 설정 (SSH, HTTP, HTTPS)
- 💾 4GB 스왑 메모리 자동 구성
- 💽 MariaDB 데이터베이스 설치 및 보안 설정
- 🌐 Nginx 웹 서버 설치 및 최적화된 설정
- 🔄 (선택 사항) DDNS 클라이언트 설정 (Cloudflare 지원)
- 🐘 PHP 8.2 설치 및 성능 최적화
- 📝 워드프레스 최신 버전 다운로드 및 설정
- 🔐 SSL 인증서 발급 준비 (Certbot 설치)

## 📋 필수 조건

- Ubuntu 22.04 LTS 이상의 서버 환경
- 관리자(root) 권한
- 인터넷 연결
- 도메인 이름 (권장)

## 🛠️ 설치 방법

1. 다음 명령어들을 차례대로 실행하여 스크립트를 다운로드하고 실행하세요:

```bash
cd ~
curl -O https://raw.githubusercontent.com/kimvayne/wordpress/main/wordpress-setup.sh
chmod +x wordpress-setup.sh
sudo ./wordpress-setup.sh
```

2. 스크립트 실행 중 다음 정보를 입력하게 됩니다:
   - 도메인 이름 (예: example.com)
   - 데이터베이스 이름
   - 데이터베이스 사용자 이름
   - 데이터베이스 비밀번호
   - DDNS 사용 여부 및 관련 정보 (선택 사항)

3. 설치가 완료되면 시스템 재부팅 여부를 선택할 수 있습니다.

## 🔧 설치 후 작업

스크립트 설치가 완료된 후 다음 단계를 수행하세요:

### SSL 인증서 설치

도메인의 DNS 설정이 서버 IP를 가리키도록는지 확인한 후 다음 명령어로 SSL 인증서를 발급받으세요:

```bash
sudo certbot --nginx -d yourdomain.com -d www.yourdomain.com
```

> **참고**: Cloudflare를 사용하는 경우, 
SSL 인증서 발급 전에 DNS 레코드를 DNS-only 모드(회색 구름), SSL/TLS(가변)으로 설정 하세요. 
인증서 발급 후 다시 프록시(오렌지색 구름), SSL/TLS 전체(엄격)으로 변경할 수 있습니다.

### 워드프레스 설정 완료

브라우저에서 도메인(http://yourdomain.com 또는 https://yourdomain.com)에 접속하여 워드프레스 설치 마법사를 완료하세요.

## 📁 주요 파일 및 디렉토리

- 워드프레스 설치 경로: `/var/www/wordpress`
- Nginx 설정 파일: `/etc/nginx/sites-available/wordpress`
- PHP 설정 파일: `/etc/php/8.2/fpm/php.ini`
- MariaDB 데이터베이스: MySQL CLI 또는 phpMyAdmin으로 접근

## 🔍 문제 해결

### Nginx 설정 테스트
```bash
sudo nginx -t
```

### PHP-FPM 상태 확인
```bash
sudo systemctl status php8.2-fpm
```

### 워드프레스 디렉토리 권한 문제
```bash
sudo chown -R www-data:www-data /var/www/wordpress
sudo chmod -R 755 /var/www/wordpress
```

### 로그 파일 확인
```bash
# Nginx 에러 로그
sudo tail -f /var/log/nginx/error.log

# Nginx 접근 로그
sudo tail -f /var/log/nginx/access.log

# PHP-FPM 로그
sudo tail -f /var/log/php8.2-fpm.log
```

## 📝 스크립트 사용자 정의

특별한 요구 사항이 있는 경우 스크립트를 직접 수정할 수 있습니다. 주요 설정 부분:

- PHP 설정: 스크립트의 `# PHP 설정` 섹션
- Nginx 설정: `# Nginx 설정` 섹션의 템플릿
- 데이터베이스 설정: `# 데이터베이스 및 사용자 생성` 섹션

## 📊 성능 최적화 팁

- **Redis 캐시 추가**: `sudo apt install redis-server php8.2-redis`
- **이미지 최적화**: ImageMagick 설치 (`sudo apt install imagemagick php8.2-imagick`)
- **브라우저 캐싱**: Nginx 설정에 이미 포함되어 있음
- **워드프레스 캐싱 플러그인 사용**: WP Super Cache, W3 Total Cache 등

## 🔄 유지 관리

### 시스템 업데이트
```bash
sudo apt update && sudo apt upgrade -y
```

### 워드프레스 백업
```bash
# 데이터베이스 백업
sudo mysqldump -u root -p wpdb > wpdb_backup.sql

# 파일 백업
sudo tar -czf wordpress_backup.tar.gz /var/www/wordpress
```

## 🔒 보안 강화 방법

- 주기적으로 워드프레스, 플러그인, 테마 업데이트
- 강력한 비밀번호 사용 및 정기적 변경
- 보안 플러그인 설치 (Wordfence, Sucuri 등)
- `fail2ban` 설치로 무차별 공격 방지

## 📜 라이선스

이 스크립트는 개인 및 상업적 용도로 자유롭게 사용할 수 있습니다. 필요에 따라 수정하여 사용하세요.

## 🤝 기여하기

버그 신고나 기능 제안은 GitHub 이슈를 통해 알려주세요.

---

© 2025 kimvayne
