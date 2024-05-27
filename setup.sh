#!/bin/sh

# Paket yöneticisini güncelliyoruz ve gerekli paketleri yüklüyoruz
echo "Paket yöneticisini güncelliyoruz ve gerekli paketleri yüklüyoruz..."
pkg update
pkg upgrade -y
pkg install -y nginx postgresql13-server postgresql13-client php83 php83-fpm php83-pgsql

# Ağ arayüzünü sabitliyoruz
echo "Ağ arayüzünü sabitliyoruz..."
sysrc ifconfig_le0="inet 172.16.16.18 netmask 255.255.255.0"
sysrc defaultrouter="172.16.16.1"
ifconfig le0 inet 172.16.16.18 netmask 255.255.255.0
route add default 172.16.16.1

# SSH servisini etkinleştiriyoruz
echo "SSH servisini etkinleştiriyoruz..."
sysrc sshd_enable=YES
service sshd start

# PostgreSQL kullanıcısını oluşturuyoruz
echo "PostgreSQL kullanıcısını oluşturuyoruz..."
pw useradd -n postgres -s /bin/sh -m -d /home/postgres -w yes || true

# PostgreSQL servisini etkinleştiriyoruz
echo "PostgreSQL servisini etkinleştiriyoruz..."
sysrc postgresql_enable=YES
service postgresql initdb
service postgresql start

# PostgreSQL yapılandırması yapılıyor
echo "PostgreSQL yapılandırması yapılıyor..."
su - postgres -c 'createuser -s freebsd'
su - postgres -c 'createdb captive_portal'
su - postgres -c 'psql -c "ALTER USER freebsd WITH ENCRYPTED PASSWORD '\''123456'\'';"'

# Nginx yapılandırması yapılıyor
echo "Nginx yapılandırması yapılıyor..."
sysrc nginx_enable=YES

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
        server_name 172.16.16.18;

        root /captive_portal_project/src/web_server;
        index index.php index.html;

        location / {
            try_files \$uri \$uri/ /index.php?\$query_string;
        }

        location ~ \.php$ {
            include fastcgi_params;
            fastcgi_pass 127.0.0.1:9000;
            fastcgi_index index.php;
            fastcgi_param SCRIPT_FILENAME \$document_root\$fastcgi_script_name;
        }
    }
}
EOF

service nginx restart

# PHP-FPM yapılandırması yapılıyor
echo "PHP-FPM yapılandırması yapılıyor..."
sysrc php_fpm_enable=YES
service php-fpm start

# pf yapılandırması yapılıyor
echo "pf yapılandırması yapılıyor..."
sysrc pf_enable=YES
service pf start

# freebsd kullanıcısının şifresini ayarlıyoruz
echo "freebsd kullanıcısının şifresini ayarlıyoruz..."
echo "freebsd:123456" | chpasswd

# DNS ayarları yapılandırılıyor
echo "DNS ayarları yapılandırılıyor..."
echo 'nameserver 8.8.8.8' > /etc/resolv.conf
echo 'nameserver 8.8.4.4' >> /etc/resolv.conf

# Servis durumlarını kontrol ediyoruz
echo "Servis durumları:"
echo "SSH:" $(service sshd status)
echo "PostgreSQL:" $(service postgresql status)
echo "Nginx:" $(service nginx status)
echo "PHP-FPM:" $(service php-fpm status)
echo "PF:" $(service pf status)

# Kullanıcı bilgilerini ekrana yazdırıyoruz
echo "Kullanıcı Bilgileri:"
echo "freebsd kullanıcısı şifresi: 123456"
echo "PostgreSQL kullanıcı adı: postgres"
echo "PostgreSQL veritabanı adı: captive_portal"
echo "PostgreSQL şifresi: 123456"

echo "Kurulum ve yapılandırma tamamlandı."
