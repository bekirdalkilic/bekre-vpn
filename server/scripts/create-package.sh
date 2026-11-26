#!/bin/bash
set -euo pipefail
# Paket kullanicinin ozel anahtarlarini icerir: sadece root okuyabilsin
umask 077

USERNAME=${1:-}

if [ -z "$USERNAME" ]; then
    echo "Kullanim: ./create-package.sh <kullanici_adi>"
    exit 1
fi

# Kullanıcı adı validasyonu (path traversal / injection önleme)
if ! [[ "$USERNAME" =~ ^[a-zA-Z0-9_-]+$ ]]; then
    echo "Hata: Gecersiz kullanici adi. Sadece harf, sayi, alt cizgi (_) ve tire (-) kullanilabilir."
    exit 1
fi

# Kullanici yoksa add-user.sh olusturur. add-user.sh kilidi kendisi alir; bu yuzden
# asagidaki kilit bu cagridan SONRA alinmalidir (aksi halde kilitlenme olur).
if [ ! -d "/root/clients/$USERNAME" ]; then
    /root/scripts/add-user.sh "$USERNAME"
fi

# add-user.sh / remove-user.sh ile ayni kilit: paketleme sirasinda kullanici dizini
# yazilmaz veya silinmez; ayni kullanici icin iki paketleme birbirini ezmez.
LOCK_FILE="/etc/wireguard/.bekre-vpn.lock"
exec 200>"$LOCK_FILE"
flock -x 200

# Kilidi beklerken kullanici silinmis olabilir
if [ ! -d "/root/clients/$USERNAME" ]; then
    echo "Hata: '$USERNAME' kilit beklenirken silindi veya olusturulamadi."
    exit 1
fi

PACK_DIR="/root/packages/$USERNAME"
rm -rf "$PACK_DIR"
mkdir -p "$PACK_DIR/configs" "$PACK_DIR/installers"

# Config dosyalari
cp "/root/clients/$USERNAME/wg0.conf"     "$PACK_DIR/configs/"
cp "/root/clients/$USERNAME/client.ovpn"  "$PACK_DIR/configs/"
cp "/root/clients/$USERNAME/stunnel.conf" "$PACK_DIR/configs/"

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
set -e
echo "============================================"
echo "   BEKRE VPN - Otomatik Kurulum (Linux)"
echo "============================================"
if [ -f /etc/fedora-release ]; then
    sudo dnf install -y wireguard-tools openvpn stunnel curl python3-tkinter
elif [ -f /etc/debian_version ]; then
    sudo apt install -y wireguard-tools openvpn stunnel4 curl python3-tk python3-venv
else
    echo "Desteklenmeyen dagitim: paketleri elle kurun (wireguard-tools, openvpn, stunnel, curl, tkinter)."
fi
# Sistem Python'una dokunmamak icin sanal ortam (--break-system-packages KULLANILMAZ).
# Surum, repodaki requirements.txt ile ayni tutulmalidir.
python3 -m venv .venv
.venv/bin/pip install customtkinter==5.2.2
echo "Kurulum tamamlandi! Calistir: .venv/bin/python vpn_client.py"
BASH
chmod +x "$PACK_DIR/kur.sh"

# ZIP ve SHA256 checksum
cd /root/packages
rm -f "${USERNAME}.zip" "${USERNAME}.zip.sha256"
zip -r "${USERNAME}.zip" "$USERNAME/"
sha256sum "${USERNAME}.zip" > "${USERNAME}.zip.sha256"
chmod 600 "${USERNAME}.zip" "${USERNAME}.zip.sha256"

echo ""
echo "✅ Paket hazır: /root/packages/${USERNAME}.zip"
echo "🔒 Checksum:   /root/packages/${USERNAME}.zip.sha256"
cat "/root/packages/${USERNAME}.zip.sha256"
