#!/bin/bash
set -e

USERNAME=$1

if [ -z "$USERNAME" ]; then
    echo "❌ Kullanım: ./remove-user.sh <kullanıcı_adı>"
    exit 1
fi

# Kullanıcı adı validasyonu (path traversal / injection önleme)
if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Geçersiz kullanıcı adı. Sadece harf, sayı, alt çizgi (_) ve tire (-) kullanılabilir."
    exit 1
fi

if [ ! -d "/root/clients/$USERNAME" ]; then
    echo "❌ '$USERNAME' bulunamadı!"
    exit 1
fi

# WireGuard public key'i bul
WG_KEY_FILE="/etc/wireguard/${USERNAME}_public.key"

if [ -f "$WG_KEY_FILE" ]; then
    WG_PUBLIC=$(cat "$WG_KEY_FILE")

    # Python ile peer bloğunu güvenli sil (boş [Peer] artifact bırakmaz)
    python3 - "$WG_PUBLIC" << 'PYEOF'
import sys, re

pub_key = sys.argv[1]
conf_path = "/etc/wireguard/wg0.conf"

with open(conf_path, "r") as f:
    content = f.read()

# Peer bloklarını parçala, hedef public key'i içereni çıkar
blocks = re.split(r'(?=\[Peer\])', content)
filtered = [b for b in blocks if pub_key not in b]
result = "\n".join(b.rstrip() for b in filtered if b.strip())

with open(conf_path, "w") as f:
    f.write(result + "\n")

print(f"Peer silindi: {pub_key[:20]}...")
PYEOF

    systemctl restart wg-quick@wg0
fi

# OpenVPN sertifikasını iptal et (interaktif CA passphrase gerektirir)
cd /etc/openvpn/easy-rsa
./easyrsa revoke "$USERNAME" <<< "yes" 2>/dev/null || true
./easyrsa gen-crl 2>/dev/null || true

# Dosyaları sil
rm -rf "/root/clients/$USERNAME"
rm -f "/etc/wireguard/${USERNAME}_private.key"
rm -f "/etc/wireguard/${USERNAME}_public.key"

echo "✅ '$USERNAME' silindi!"
