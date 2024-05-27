#!/bin/sh

# Kök kullanıcı olup olmadığını kontrol et
if [ "$(id -u)" -ne 0 ]; then
    echo "Bu script'i çalıştırmak için root kullanıcısı olmanız gerekmektedir."
    exit 1
fi

# Paket yöneticisini güncelle ve gerekli paketleri yükle
echo "Paket yöneticisini güncelliyoruz ve gerekli paketleri yüklüyoruz..."
pkg update
pkg install -y gcc git nginx postgresql13-server postgresql13-client php83

# Ağ arayüzünü sabitle
echo "Ağ arayüzünü sabitliyoruz..."
sysrc ifconfig_le0="inet 172.16.16.18 netmask 255.255.255.0"
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
su - postgres -c "psql -c \"ALTER USER postgres WITH PASSWORD '123456';\""
su - postgres -c "createdb captive_portal -O postgres"

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
            proxy_pass http://127.0.0.1:9000;  # PHP-FPM'in dinlediği adres
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

# PHP-FPM yapılandırması
echo "PHP-FPM yapılandırması yapılıyor..."
sysrc php_fpm_enable="YES"
service php-fpm start

# PF yapılandırması
echo "pf yapılandırması yapılıyor..."
sysrc pf_enable="YES"
service pf start

# freebsd kullanıcısının şifresini ayarla
echo "freebsd kullanıcısının şifresini ayarlıyoruz..."
echo "freebsd:123456" | pw usermod freebsd -h 0

# Servis durumlarını kontrol et ve ekrana yazdır
echo "Servis durumları:"
echo "SSH: $(service sshd status)"
echo "PostgreSQL: $(service postgresql status)"
echo "Nginx: $(service nginx status)"
echo "PHP-FPM: $(service php-fpm status)"
echo "PF: $(service pf status)"

echo "Kullanıcı Bilgileri:"
echo "freebsd kullanıcısı şifresi: 123456"
echo "PostgreSQL kullanıcı adı: postgres"
echo "PostgreSQL veritabanı adı: captive_portal"
echo "PostgreSQL şifresi: 123456"
echo "Kurulum ve yapılandırma tamamlandı."
