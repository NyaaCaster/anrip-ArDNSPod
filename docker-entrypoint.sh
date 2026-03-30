#!/bin/sh
set -e

echo "========================================="
echo "  DNSPod DDNS Client - Docker Container"
echo "========================================="
echo ""

if [ ! -f /app/dns.conf ]; then
    echo "ERROR: dns.conf not found!"
    echo "Please mount your dns.conf file to /app/dns.conf"
    exit 1
fi

cp /app/dns.conf /tmp/dns.conf
sed -i 's/\r$//' /tmp/dns.conf

echo "Configuration loaded from: /app/dns.conf"
echo "Cron schedule: $(cat /etc/crontabs/root | grep -v '^#' | grep -v '^$')"
echo ""
echo "Starting DDNS client..."
echo "Logs will be written to: /var/log/ddns.log"
echo ""

exec "$@"
