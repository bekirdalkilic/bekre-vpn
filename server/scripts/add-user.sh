#!/bin/bash
set -e

USERNAME=$1
SERVER_IP="<SUNUCU_IP>"
SERVER_WG_PUBLIC=$(cat /etc/wireguard/server_public.key)
IP_REGISTRY="/etc/wireguard/ip_registry"
LOCK_FILE="/tmp/bekre-vpn.lock"

if [ -z "$USERNAME" ]; then
    echo "❌ Kullanım: ./add-user.sh <kullanıcı_adı>"
    exit 1
fi

if [ -d "/root/clients/$USERNAME" ]; then
    echo "❌ '$USERNAME' zaten mevcut!"
    exit 1
fi

# Atomik IP atama (race condition önleme)
exec 200>"$LOCK_FILE"
flock -x 200

if [ ! -f "$IP_REGISTRY" ]; then
    echo "3" > "$IP_REGISTRY"
fi

LAST_IP=$(cat "$IP_REGISTRY")
NEXT_IP=$((LAST_IP + 1))
echo "$NEXT_IP" > "$IP_REGISTRY"

flock -u 200

echo "🔧 $USERNAME için config'ler oluşturuluyor... (IP: 10.0.0.$NEXT_IP)"

# --- WireGuard Anahtarları ---
wg genkey | tee /etc/wireguard/${USERNAME}_private.key | wg pubkey > /etc/wireguard/${USERNAME}_public.key
chmod 600 /etc/wireguard/${USERNAME}_private.key

WG_PRIVATE=$(cat /etc/wireguard/${USERNAME}_private.key)
WG_PUBLIC=$(cat /etc/wireguard/${USERNAME}_public.key)

# WireGuard sunucu config'ine peer ekle
cat >> /etc/wireguard/wg0.conf << WGEOF

[Peer]
# $USERNAME
PublicKey = $WG_PUBLIC
AllowedIPs = 10.0.0.${NEXT_IP}/32
WGEOF

systemctl restart wg-quick@wg0

# --- OpenVPN Sertifikası (interaktif CA passphrase gerektirir) ---
cd /etc/openvpn/easy-rsa
./easyrsa build-client-full "$USERNAME" nopass

# --- Çıktı Klasörü ---
OUTPUT_DIR=/root/clients/$USERNAME
mkdir -p "$OUTPUT_DIR"

# --- WireGuard Client Config ---
cat > "$OUTPUT_DIR/wg0.conf" << WGCLIENT
[Interface]
Address = 10.0.0.${NEXT_IP}/24
PrivateKey = $WG_PRIVATE
DNS = 1.1.1.1

# Kill switch
PostUp   = iptables -I OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT
PreDown  = iptables -D OUTPUT ! -o %i -m mark ! --mark \$(wg show %i fwmark) -m addrtype ! --dst-type LOCAL -j REJECT

[Peer]
PublicKey = $SERVER_WG_PUBLIC
Endpoint = ${SERVER_IP}:443
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
WGCLIENT

# --- OpenVPN Client Config (sertifikalar gömülü) ---
cat > "$OUTPUT_DIR/client.ovpn" << OVPNCLIENT
client
dev tun
proto tcp
remote 127.0.0.1 1194
route ${SERVER_IP} 255.255.255.255 net_gateway
resolv-retry infinite
nobind
persist-key
persist-tun
remote-cert-tls server
cipher AES-256-GCM
verb 3
OVPNCLIENT

echo "<ca>" >> "$OUTPUT_DIR/client.ovpn"
cat /etc/openvpn/easy-rsa/pki/ca.crt >> "$OUTPUT_DIR/client.ovpn"
echo "</ca>" >> "$OUTPUT_DIR/client.ovpn"
echo "<cert>" >> "$OUTPUT_DIR/client.ovpn"
cat /etc/openvpn/easy-rsa/pki/issued/${USERNAME}.crt >> "$OUTPUT_DIR/client.ovpn"
echo "</cert>" >> "$OUTPUT_DIR/client.ovpn"
echo "<key>" >> "$OUTPUT_DIR/client.ovpn"
cat /etc/openvpn/easy-rsa/pki/private/${USERNAME}.key >> "$OUTPUT_DIR/client.ovpn"
echo "</key>" >> "$OUTPUT_DIR/client.ovpn"

# --- Stunnel Client Config ---
cat > "$OUTPUT_DIR/stunnel.conf" << STUNCONF
[openvpn]
client = yes
accept = 127.0.0.1:1194
connect = ${SERVER_IP}:443
STUNCONF

echo ""
echo "✅ '$USERNAME' kullanıcısı oluşturuldu!"
echo "📁 Dosyalar: $OUTPUT_DIR/"
echo "   ├── wg0.conf       (WireGuard — hızlı mod, UDP 443)"
echo "   ├── client.ovpn    (OpenVPN — engel atlatma)"
echo "   └── stunnel.conf   (Stunnel — TCP 443 üzerinden)"
echo "🌐 WireGuard IP: 10.0.0.$NEXT_IP"
