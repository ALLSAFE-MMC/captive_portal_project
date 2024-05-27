#!/bin/sh

# Kök kullanıcı olup olmadığını kontrol et
if [ "$(id -u)" -ne 0 ]; then
    echo "Bu script'i çalıştırmak için root kullanıcısı olmanız gerekmektedir."
    exit 1
fi

echo "Paket yöneticisini güncelliyoruz ve gerekli paketleri yüklüyoruz..."
pkg update
pkg upgrade -y
pkg install -y sudo nano gcc git nginx postgresql13-server postgresql13-client php83 php83-fpm

echo "Ağ arayüzünü sabitliyoruz..."
sysrc ifconfig_le0="inet 192.168.1.100 netmask 255.255.255.0"
sysrc defaultrouter="192.168.1.1"

echo "SSH servisini etkinleştiriyoruz..."
sysrc sshd_enable="YES"
service sshd start

echo "PostgreSQL kullanıcısını oluşturuyoruz..."
if ! id "postgres" >/dev/null 2>&1; then
    pw user add postgres -c "PostgreSQL User" -d /home/postgresql -s /usr/sbin/nologin
fi

echo "PostgreSQL servisini etkinleştiriyoruz..."
sysrc postgresql_enable="YES"
service postgresql initdb
service postgresql start

echo "PostgreSQL yapılandırması yapılıyor..."
sudo -u postgres createuser freebsd --interactive <<EOF
y
EOF
sudo -u postgres createdb captive_portal -O freebsd
sudo -u postgres psql captive_portal -c "ALTER USER freebsd WITH PASSWORD '123456';"

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
            proxy_pass http://127.0.0.1:5000;
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

echo "PHP-FPM yapılandırması yapılıyor..."
sysrc php_fpm_enable="YES"
service php-fpm start

echo "pf yapılandırması yapılıyor..."
cat <<EOF > /etc/pf.conf
ext_if = "le0"
captive_portal_ip = "192.168.1.100"

rdr pass on \$ext_if proto udp from any to any port 53 -> \$captive_portal_ip port 53
rdr pass on \$ext_if proto tcp from any to any port 53 -> \$captive_portal_ip port 53
rdr pass on \$ext_if proto tcp from any to any port 80 -> \$captive_portal_ip port 80
rdr pass on \$ext_if proto tcp from any to any port 443 -> \$captive_portal_ip port 443

pass in on \$ext_if proto tcp from any to \$captive_portal_ip port 80
pass in on \$ext_if proto tcp from any to \$captive_portal_ip port 443
pass in on \$ext_if proto udp from any to \$captive_portal_ip port 53
pass in on \$ext_if proto tcp from any to \$captive_portal_ip port 53
pass out keep state
pass in keep state
EOF
sysrc pf_enable="YES"
service pf start

echo "freebsd kullanıcısının şifresini ayarlıyoruz..."
echo "freebsd:123456" | chpasswd

echo "DNS ayarları yapılandırılıyor..."
cat <<EOF > /etc/resolv.conf
nameserver 8.8.8.8
nameserver 8.8.4.4
EOF

echo "Servis durumları:"
service sshd status
service postgresql status
service nginx status
service php-fpm status
pfctl -s info

echo "Kullanıcı Bilgileri:"
echo "freebsd kullanıcısı şifresi: 123456"
echo "PostgreSQL kullanıcı adı: freebsd"
echo "PostgreSQL veritabanı adı: captive_portal"
echo "PostgreSQL şifresi: 123456"

echo "Kurulum ve yapılandırma tamamlandı."

