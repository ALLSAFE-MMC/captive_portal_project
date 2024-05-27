#!/bin/sh

# Başlatma script'i
service nginx start
service php-fpm start
sh /mnt/data/captive_portal_project/src/firewall/firewall.sh
