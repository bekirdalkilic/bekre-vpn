#!/bin/bash
set -euo pipefail
# Olusturulan anahtar ve config dosyalari sadece root tarafindan okunabilsin
umask 077

USERNAME=${1:-}
SERVER_IP="<SUNUCU_IP>"

if [ "$SERVER_IP" = "<SUNUCU_IP>" ]; then
    echo "HATA: SERVER_IP placeholder doldurulmadi."
    echo "Bu scripti calistirmadan once 7. satirdaki SERVER_IP degerini kendi sunucu IP'inle degistir:"
    echo '  SERVER_IP="203.0.113.10"'
    exit 1
fi

WG_CONF="/etc/wireguard/wg0.conf"
SERVER_WG_PUBLIC=$(cat /etc/wireguard/server_public.key)
IP_REGISTRY="/etc/wireguard/ip_registry"
# Kilit dosyasi root-only dizinde (world-writable /tmp'de symlink saldirisina aciktir)
LOCK_FILE="/etc/wireguard/.bekre-vpn.lock"
EASYRSA_DIR="/etc/openvpn/easy-rsa"

if [ -z "$USERNAME" ]; then
    echo "❌ Kullanım: ./add-user.sh <kullanıcı_adı>"
    exit 1
fi

# Kullanıcı adı validasyonu (path traversal / injection önleme)
if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "❌ Geçersiz kullanıcı adı. Sadece harf, sayı, alt çizgi (_) ve tire (-) kullanılabilir."
    exit 1
fi

OUTPUT_DIR="/root/clients/$USERNAME"

# Tum islem boyunca kilit tutulur: ayni anda calisan add-user/remove-user
# wg0.conf, ip_registry ve kullanici dizinini bozamaz.
exec 200>"$LOCK_FILE"
flock -x 200

if [ -d "$OUTPUT_DIR" ]; then
    echo "❌ '$USERNAME' zaten mevcut!"
    exit 1
fi

# --- Hata durumunda geri alma (SINIRLARI) ---
# Geri alinan: wg0.conf'a eklenen peer (+ wg-quick yeniden baslatma), /etc/wireguard/<kullanici>_*.key,
#              olusturulan /root/clients/<kullanici> dizini.
# Geri ALINMAYAN:
#  - OpenVPN sertifikasi: uretildikten sonraki bir hatada OTOMATIK IPTAL EDILMEZ; sertifika
#    gecerli kalir (pki/ altinda). Kullanilmayacaksa elle iptal edin (hata mesajindaki komut).
#  - ip_registry sayaci: peer eklendikten sonra yazilir ve geri alinmaz; o noktadan sonra
#    bir hata olursa IP numarasi harcanmis sayilir (havuzdan bir adres kaybolur).
#  - Surec SIGKILL ile oldurulur veya sunucu aniden kapanirsa trap calismaz; yarim kalan
#    durum elle temizlenmelidir. (SIGTERM/SIGINT/SIGHUP geri almayi calistirir; o an calisan
#    alt komut bitene kadar beklenir.)
#  - Geri alma sirasindaki wg-quick yeniden baslatma hatasi (|| true) sessizce gecilir.
CERT_ISSUED=0
PEER_ADDED=0
DIR_CREATED=0
WG_PUBLIC=""
DONE=0

cleanup() {
    local rc=$?
    if [ "$rc" -ne 0 ] && [ "$DONE" -ne 1 ]; then
        echo "❌ Hata (kod $rc): yarım kalan işlem geri alınıyor..." >&2
        if [ "$PEER_ADDED" -eq 1 ] && [ -n "$WG_PUBLIC" ]; then
            python3 - "$WG_PUBLIC" "$WG_CONF" << 'PYEOF' || true
import sys, re
pub_key, conf_path = sys.argv[1], sys.argv[2]
with open(conf_path, "r") as f:
    content = f.read()
blocks = re.split(r'(?=\[Peer\])', content)
filtered = [b for b in blocks if pub_key not in b]
with open(conf_path, "w") as f:
    f.write("\n".join(b.rstrip() for b in filtered if b.strip()) + "\n")
PYEOF
            systemctl restart wg-quick@wg0 || true
        fi
        rm -f "/etc/wireguard/${USERNAME}_private.key" "/etc/wireguard/${USERNAME}_public.key"
        if [ "$DIR_CREATED" -eq 1 ]; then
            rm -rf "$OUTPUT_DIR"
        fi
        if [ "$CERT_ISSUED" -eq 1 ]; then
            echo "⚠️  OpenVPN sertifikası '$USERNAME' için üretilmişti. Kullanılmayacaksa iptal edin:" >&2
            echo "    cd $EASYRSA_DIR && ./easyrsa revoke $USERNAME && ./easyrsa gen-crl" >&2
        fi
    fi
}
trap cleanup EXIT
# SIGTERM/SIGINT/SIGHUP ile kesilirse de geri alma calissin (bash varsayilan olarak SIGTERM'de
# EXIT trap'ini CALISTIRMAZ). Calisan alt komut (easyrsa, systemctl...) bitene kadar beklenir.
trap 'exit 143' TERM
trap 'exit 130' INT
trap 'exit 129' HUP

# --- IP atama (salt-okunur kontroller; sertifika uretilmeden ONCE yapilir) ---
# Kilit tutuldugu icin bu degerler asagidaki adimlar boyunca degismez.
# Kayit dosyasi yalnizca peer eklendikten sonra yazilir.
LAST_IP=3
if [ -f "$IP_REGISTRY" ]; then
    LAST_IP=$(cat "$IP_REGISTRY")
fi
if ! [[ "$LAST_IP" =~ ^[0-9]+$ ]]; then
    echo "❌ $IP_REGISTRY bozuk (sayı bekleniyordu)."
    exit 1
fi
NEXT_IP=$((LAST_IP + 1))
if [ "$NEXT_IP" -gt 254 ]; then
    echo "❌ IP havuzu doldu (10.0.0.0/24). Yeni kullanıcı eklenemez."
    exit 1
fi
# Kayit ile gercek durumun tutarliligi: zaten kullanilan bir IP atanmaz
if grep -qE "^AllowedIPs = 10\.0\.0\.${NEXT_IP}/32" "$WG_CONF"; then
    echo "❌ 10.0.0.${NEXT_IP} wg0.conf içinde zaten kullanımda; ip_registry tutarsız."
    exit 1
fi

# --- OpenVPN Sertifikası (interaktif CA passphrase gerektirir) ---
# En olasi hata noktasi (yanlis parola) oldugu icin WireGuard/IP durumuna dokunmadan ONCE yapilir.
cd "$EASYRSA_DIR"
./easyrsa build-client-full "$USERNAME" nopass
CERT_ISSUED=1

echo "🔧 $USERNAME için config'ler oluşturuluyor... (IP: 10.0.0.$NEXT_IP)"

# --- WireGuard Anahtarları ---
wg genkey | tee "/etc/wireguard/${USERNAME}_private.key" | wg pubkey > "/etc/wireguard/${USERNAME}_public.key"
chmod 600 "/etc/wireguard/${USERNAME}_private.key"

WG_PRIVATE=$(cat "/etc/wireguard/${USERNAME}_private.key")
WG_PUBLIC=$(cat "/etc/wireguard/${USERNAME}_public.key")

# WireGuard sunucu config'ine peer ekle
cat >> "$WG_CONF" << WGEOF

[Peer]
# $USERNAME
PublicKey = $WG_PUBLIC
AllowedIPs = 10.0.0.${NEXT_IP}/32
WGEOF
PEER_ADDED=1
echo "$NEXT_IP" > "$IP_REGISTRY"

systemctl restart wg-quick@wg0

# --- Çıktı Klasörü ---
mkdir -p "$OUTPUT_DIR"
DIR_CREATED=1

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

{
    echo "<ca>"
    cat "$EASYRSA_DIR/pki/ca.crt"
    echo "</ca>"
    echo "<cert>"
    cat "$EASYRSA_DIR/pki/issued/${USERNAME}.crt"
    echo "</cert>"
    echo "<key>"
    cat "$EASYRSA_DIR/pki/private/${USERNAME}.key"
    echo "</key>"
} >> "$OUTPUT_DIR/client.ovpn"

# --- Stunnel Client Config ---
cat > "$OUTPUT_DIR/stunnel.conf" << STUNCONF
[openvpn]
client = yes
accept = 127.0.0.1:1194
connect = ${SERVER_IP}:443
STUNCONF

DONE=1

echo ""
echo "✅ '$USERNAME' kullanıcısı oluşturuldu!"
echo "📁 Dosyalar: $OUTPUT_DIR/"
echo "   ├── wg0.conf       (WireGuard — hızlı mod, UDP 443)"
echo "   ├── client.ovpn    (OpenVPN — engel atlatma)"
echo "   └── stunnel.conf   (Stunnel — TCP 443 üzerinden)"
echo "🌐 WireGuard IP: 10.0.0.$NEXT_IP"
