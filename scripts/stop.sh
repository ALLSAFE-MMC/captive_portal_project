#!/bin/sh

# Durdurma script'i
service nginx stop
service php-fpm stop
pfctl -d
