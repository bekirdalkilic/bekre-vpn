#!/bin/bash

echo "═══════════════════════════════════════"
echo "       BEKRE VPN — Kullanıcı Listesi"
echo "═══════════════════════════════════════"

if [ ! -d /root/clients ] || [ -z "$(ls /root/clients 2>/dev/null)" ]; then
    echo "Kayıtlı kullanıcı yok."
    exit 0
fi

for USER_DIR in /root/clients/*/; do
    USERNAME=$(basename "$USER_DIR")
    WG_IP=$(grep -oP 'AllowedIPs = 10\.0\.0\.\K[0-9]+' /etc/wireguard/wg0.conf | head -1 || echo "?")

    # wg show ile aktif handshake kontrolü
    WG_PUB=$(cat /etc/wireguard/${USERNAME}_public.key 2>/dev/null || echo "")
    STATUS="offline"
    if [ -n "$WG_PUB" ]; then
        HANDSHAKE=$(wg show wg0 latest-handshakes 2>/dev/null | grep "$WG_PUB" | awk '{print $2}')
        if [ -n "$HANDSHAKE" ] && [ "$HANDSHAKE" -gt 0 ] 2>/dev/null; then
            AGO=$(( $(date +%s) - HANDSHAKE ))
            if [ "$AGO" -lt 180 ]; then
                STATUS="🟢 aktif (~${AGO}s önce)"
            else
                STATUS="🔴 bağlı değil"
            fi
        fi
    fi

    echo "  👤 $USERNAME  |  $STATUS"
done

echo "═══════════════════════════════════════"
echo "Toplam: $(ls /root/clients/ | wc -l) kullanıcı"
