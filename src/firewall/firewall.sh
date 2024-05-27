#!/bin/sh

# PF firewall yapılandırması
echo "PF yapılandırması uygulanıyor..."
pfctl -f /mnt/data/captive_portal_project/src/firewall/pf.conf
pfctl -e

echo "Firewall yapılandırması tamamlandı."
