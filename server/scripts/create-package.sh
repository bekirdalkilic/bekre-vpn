#!/bin/bash
set -e

USERNAME=$1

if [ -z "$USERNAME" ]; then
    echo "Kullanim: ./create-package.sh <kullanici_adi>"
    exit 1
fi

# Kullanıcı adı validasyonu (path traversal / injection önleme)
if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Hata: Gecersiz kullanici adi. Sadece harf, sayi, alt cizgi (_) ve tire (-) kullanilabilir."
    exit 1
fi

if [ ! -d "/root/clients/$USERNAME" ]; then
    /root/scripts/add-user.sh "$USERNAME"
fi

PACK_DIR="/root/packages/$USERNAME"
rm -rf "$PACK_DIR"
mkdir -p "$PACK_DIR/configs" "$PACK_DIR/installers"

# Config dosyalari
cp /root/clients/$USERNAME/wg0.conf     "$PACK_DIR/configs/"
cp /root/clients/$USERNAME/client.ovpn  "$PACK_DIR/configs/"
cp /root/clients/$USERNAME/stunnel.conf "$PACK_DIR/configs/"

# Installer dosyalari (offline bundle)
cp /root/installers/wireguard-installer.msi "$PACK_DIR/installers/" 2>/dev/null || echo "UYARI: wireguard-installer.msi eksik"
cp /root/installers/openvpn-installer.msi   "$PACK_DIR/installers/" 2>/dev/null || echo "UYARI: openvpn-installer.msi eksik"
cp /root/installers/stunnel-installer.exe   "$PACK_DIR/installers/" 2>/dev/null || echo "UYARI: stunnel-installer.exe eksik"

# GUI EXE (Windows icin)
cp /root/scripts/BekreVPN.exe "$PACK_DIR/" 2>/dev/null || echo "UYARI: BekreVPN.exe bulunamadi"

# GUI Python script (Linux icin)
cp /root/scripts/vpn_client.py "$PACK_DIR/" 2>/dev/null || echo "UYARI: vpn_client.py bulunamadi"

# Kurulum scriptleri
cp /root/scripts/kur_template.bat "$PACK_DIR/kur.bat" 2>/dev/null || true

cat > "$PACK_DIR/kur.sh" << 'BASH'
#!/bin/bash
echo "============================================"
echo "   BEKRE VPN - Otomatik Kurulum (Linux)"
echo "============================================"
if [ -f /etc/fedora-release ]; then
    sudo dnf install -y wireguard-tools openvpn stunnel curl python3-tkinter
elif [ -f /etc/debian_version ]; then
    sudo apt install -y wireguard-tools openvpn stunnel4 curl python3-tk
fi
pip install customtkinter --break-system-packages 2>/dev/null || pip install customtkinter
echo "Kurulum tamamlandi! Calistir: python3 vpn_client.py"
BASH
chmod +x "$PACK_DIR/kur.sh"

# ZIP ve SHA256 checksum
cd /root/packages
rm -f "${USERNAME}.zip" "${USERNAME}.zip.sha256"
zip -r "${USERNAME}.zip" "$USERNAME/"
sha256sum "${USERNAME}.zip" > "${USERNAME}.zip.sha256"

echo ""
echo "✅ Paket hazır: /root/packages/${USERNAME}.zip"
echo "🔒 Checksum:   /root/packages/${USERNAME}.zip.sha256"
cat "/root/packages/${USERNAME}.zip.sha256"
