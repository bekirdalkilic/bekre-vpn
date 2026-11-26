#!/bin/bash
set -euo pipefail

USERNAME=${1:-}
WG_CONF="/etc/wireguard/wg0.conf"
LOCK_FILE="/etc/wireguard/.bekre-vpn.lock"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

if [ -z "$USERNAME" ]; then
    echo "❌ Kullanım: ./remove-user.sh <kullanıcı_adı>"
    exit 1
fi

# Kullanıcı adı validasyonu (path traversal / injection önleme)
if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Geçersiz kullanıcı adı. Sadece harf, sayı, alt çizgi (_) ve tire (-) kullanılabilir."
    exit 1
fi

# add-user.sh ile ayni kilit: wg0.conf uzerindeki oku-degistir-yaz islemleri birbirini ezmesin
exec 200>"$LOCK_FILE"
flock -x 200

PACKAGES_DIR="/root/packages"

if [ ! -d "/root/clients/$USERNAME" ]; then
    echo "❌ '$USERNAME' bulunamadı!"
    # Istemci dizini yoksa paket kalintilari otomatik silinmez (kullanici dogrulanamadi);
    # ozel anahtar icerdikleri icin varsa uyar.
    if [ -e "$PACKAGES_DIR/$USERNAME" ] || [ -e "$PACKAGES_DIR/${USERNAME}.zip" ]; then
        echo "⚠️  $PACKAGES_DIR altinda '$USERNAME' paket kalintilari var (ozel anahtar icerir); elle silin." >&2
    fi
    exit 1
fi

# --- 1) OpenVPN sertifikasını iptal et (interaktif CA passphrase gerektirir) ---
# Hata sessizce yutulmaz. Iptal basarisizsa hicbir sey silinmeden durulur;
# boylece sorun giderildikten sonra script tekrar calistirilabilir.
cd "$EASYRSA_DIR"
if grep -qE "^R[[:space:]].*/CN=${USERNAME}\$" pki/index.txt 2>/dev/null; then
    echo "ℹ️  Sertifika zaten iptal edilmiş, CRL yenileniyor."
else
    if ! ./easyrsa revoke "$USERNAME" <<< "yes"; then
        echo "❌ OpenVPN sertifikası iptal edilemedi (CA parolası hatalı olabilir)."
        echo "   '$USERNAME' için hiçbir şey silinmedi. Sorunu giderip scripti tekrar çalıştırın."
        exit 1
    fi
fi
if ! ./easyrsa gen-crl; then
    echo "❌ CRL üretilemedi. Sertifika iptal edildi ancak CRL güncellenmedi; './easyrsa gen-crl' komutunu elle çalıştırın."
    exit 1
fi

# --- 2) WireGuard peer'ini sil ---
WG_KEY_FILE="/etc/wireguard/${USERNAME}_public.key"

if [ -f "$WG_KEY_FILE" ]; then
    WG_PUBLIC=$(cat "$WG_KEY_FILE")

    # Python ile peer bloğunu güvenli sil (boş [Peer] artifact bırakmaz)
    python3 - "$WG_PUBLIC" "$WG_CONF" << 'PYEOF'
import sys, re

pub_key = sys.argv[1]
conf_path = sys.argv[2]

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

# --- 3) Dosyaları sil ---
rm -rf "/root/clients/$USERNAME"
# create-package.sh ciktilari: WireGuard ozel anahtari ve OpenVPN istemci anahtari icerir.
# Sunucudaki kopyalar silinir; kullaniciya daha once iletilmis kopyalar geri alinamaz
# (OpenVPN icin sertifika iptali, WireGuard icin peer silme koruma saglar).
rm -rf "${PACKAGES_DIR:?}/${USERNAME:?}"
rm -f "$PACKAGES_DIR/${USERNAME}.zip" "$PACKAGES_DIR/${USERNAME}.zip.sha256"
rm -f "/etc/wireguard/${USERNAME}_private.key"
rm -f "/etc/wireguard/${USERNAME}_public.key"

echo "✅ '$USERNAME' silindi!"
