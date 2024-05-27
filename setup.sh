#!/bin/sh

# Kök kullanıcı olup olmadığını kontrol et
if [ "$(id -u)" -ne 0 ]; then
    echo "Bu script'i çalıştırmak için root kullanıcısı olmanız gerekmektedir."
    exit 1
fi

# Paket yöneticisini güncelle ve gerekli paketleri yükle
echo "Paket yöneticisini güncelliyoruz ve gerekli paketleri yüklüyoruz..."
pkg update
pkg install -y gcc git nginx postgresql13-server postgresql13-client php83 php83-pgsql php83-extensions

# Ağ arayüzünü sabitle
echo "Ağ arayüzünü sabitliyoruz..."
sysrc ifconfig_em0="inet 172.16.16.18 netmask 255.255.255.0"
sysrc defaultrouter="172.16.16.1"

# SSH servisini etkinleştir ve başlat
echo "SSH servisini etkinleştiriyoruz..."
sysrc sshd_enable="YES"
service sshd start

# PostgreSQL kullanıcısını oluştur
echo "PostgreSQL kullanıcısını oluşturuyoruz..."
pw user add postgres -c "PostgreSQL User" -u 999 -d /home/postgres -s /bin/sh -w yes

# PostgreSQL servisini etkinleştir ve başlat
echo "PostgreSQL servisini etkinleştiriyoruz..."
sysrc postgresql_enable="YES"
service postgresql initdb
service postgresql start

# PostgreSQL yapılandırması
echo "PostgreSQL yapılandırması yapılıyor..."
sudo -u postgres psql -c "ALTER USER postgres WITH PASSWORD '123456';"
sudo -u postgres createdb captive_portal -O postgres

# Nginx yapılandırması
echo "Nginx yapılandırması yapılıyor..."
cat <<EOF > /usr/local/etc/nginx/nginx.conf
worker_processes  1;

events {
    worker_connections  1024;
}

http {
    include       mime.types;
    default_type  application/octet-stream;
    sendfile        on;
    keepalive_timeout  65;

    server {
        listen 80;
        server_name _;

        location / {
            proxy_pass http://127.0.0.1:5000;  # Captive portal uygulamanızın çalıştığı port
            proxy_set_header Host \$host;
            proxy_set_header X-Real-IP \$remote_addr;
            proxy_set_header X-Forwarded-For \$proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto \$scheme;
        }
    }
}
EOF

sysrc nginx_enable="YES"
service nginx start

# PHP-FPM servisini başlat
echo "PHP-FPM yapılandırması yapılıyor..."
sysrc php_fpm_enable="YES"
service php-fpm start

# pf yapılandırması
echo "pf yapılandırması yapılıyor..."
cat <<EOF > /etc/pf.conf
ext_if = "em0"
captive_portal_ip = "172.16.16.18"

# Tüm DNS trafiğini captive portal sunucusuna yönlendir
rdr pass on \$ext_if proto udp from any to any port 53 -> \$captive_portal_ip port 53
rdr pass on \$ext_if proto tcp from any to any port 53 -> \$captive_portal_ip port 53

# Tüm HTTP ve HTTPS trafiğini captive portal sunucusuna yönlendir
rdr pass on \$ext_if proto tcp from any to any port 80 -> \$captive_portal_ip port 80
rdr pass on \$ext_if proto tcp from any to any port 443 -> \$captive_portal_ip port 443

# Captive portal sunucusuna izin ver
pass in on \$ext_if proto tcp from any to \$captive_portal_ip port 80
pass in on \$ext_if proto tcp from any to \$captive_portal_ip port 443
pass in on \$ext_if proto udp from any to \$captive_portal_ip port 53
pass in on \$ext_if proto tcp from any to \$captive_portal_ip port 53
pass out keep state
pass in keep state
EOF

sysrc pf_enable="YES"
service pf start

# Kullanıcı oluşturma ve şifre ayarlama
echo "freebsd kullanıcısının şifresini ayarlıyoruz..."
echo "freebsd:123456" | chpasswd

# DNS ayarlarını yapılandır
echo "DNS ayarları yapılandırılıyor..."
cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

# Servis durumlarını kontrol et ve ekrana yazdır
echo "Servis durumları:"
echo "SSH: $(service sshd status)"
echo "PostgreSQL: $(pg_ctl status)"
echo "Nginx: $(service nginx status)"
echo "PHP-FPM: $(service php-fpm status)"
echo "PF: $(pfctl -s info)"

# Kullanıcı bilgilerini ekrana yazdır
echo "Kullanıcı Bilgileri:"
echo "freebsd kullanıcısı şifresi: 123456"
echo "PostgreSQL kullanıcı adı: postgres"
echo "PostgreSQL veritabanı adı: captive_portal"
echo "PostgreSQL şifresi: 123456"

echo "Kurulum ve yapılandırma tamamlandı."
