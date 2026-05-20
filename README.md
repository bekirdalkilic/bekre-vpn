# Bekre VPN

Kişisel self-hosted VPN altyapısı. DigitalOcean Frankfurt droplet üzerinde çalışır.

## Mimari

```
İstemci
├── [WG] HIZLI MOD     →  UDP 443   →  WireGuard (direkt)
└── [OVPN] GİZLİ MOD  →  TCP 443   →  Stunnel → OpenVPN
                                        (DPI bypass, kısıtlı ağlar için)
```

**Sunucu:** Ubuntu 24.04 LTS · DigitalOcean Frankfurt  
**İstemci:** Windows (BekreVPN.exe) · Linux (vpn_client.py)

---

## İstemci Kurulumu

### Windows (hazır EXE)

1. **[Releases](https://github.com/bekirdalkilic/bekre-vpn/releases/latest)** sayfasından `BekreVPN.exe` indir
2. Sunucu yöneticisinden `configs.zip` al, aç
3. Klasör yapısı şöyle olmalı:
   ```
   BekreVPN.exe
   configs/
   ├── wg0.conf
   ├── client.ovpn
   └── stunnel.conf
   ```
4. `BekreVPN.exe`'ye sağ tık → **Yönetici olarak çalıştır**

> **Not:** Windows Smart App Control açıksa EXE çalışmaz.  
> Ayarlar → Gizlilik ve Güvenlik → Windows Güvenliği → Smart App Control → Kapalı

### Linux (Fedora)

```bash
sudo dnf install -y wireguard-tools openvpn stunnel curl python3-tkinter
pip install customtkinter --break-system-packages

# Sunucu yöneticisinden configs/ klasörünü al, sonra:
python3 client/vpn_client.py
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install -y wireguard-tools openvpn stunnel4 curl python3-tk
pip install customtkinter --break-system-packages
python3 client/vpn_client.py
```

---

## Dizin Yapısı

```
bekre-vpn/
├── .github/workflows/
│   └── build-release.yml   # Tag push → otomatik EXE build + GitHub Release
├── client/
│   ├── vpn_client.py       # GUI istemci (CustomTkinter)
│   └── build_windows.bat   # Manuel EXE build (PyInstaller)
├── server/
│   ├── scripts/
│   │   ├── add-user.sh        # Kullanıcı ekle
│   │   ├── remove-user.sh     # Kullanıcı sil
│   │   ├── list-users.sh      # Kullanıcı listesi + bağlantı durumu
│   │   └── create-package.sh  # configs.zip oluştur (SHA256 dahil)
│   └── configs/
│       ├── wg0.conf.template
│       └── stunnel-server.conf.template
└── docs/
    └── SECURITY.md
```

---

## Sunucu Kurulumu

### 1. Paketler

```bash
apt install -y wireguard openvpn stunnel4 easy-rsa iptables-persistent python3
```

### 2. WireGuard

```bash
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

cp server/configs/wg0.conf.template /etc/wireguard/wg0.conf
# PrivateKey alanını doldur: cat /etc/wireguard/server_private.key

systemctl enable --now wg-quick@wg0
```

### 3. Easy-RSA PKI

```bash
cp -r /usr/share/easy-rsa /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca          # CA key AES-256 ile şifreli
./easyrsa build-server-full server nopass
./easyrsa gen-dh
```

### 4. OpenVPN + Stunnel

```bash
systemctl enable --now openvpn@server stunnel4
```

### 5. Scriptleri kopyala

```bash
cp server/scripts/*.sh /root/scripts/
chmod +x /root/scripts/*.sh
echo "3" > /etc/wireguard/ip_registry
```

---

## Kullanıcı Yönetimi (Sunucuda)

```bash
# Kullanıcı ekle (CA passphrase interaktif sorulur)
/root/scripts/add-user.sh ahmet

# configs.zip oluştur ve kullanıcıya gönder
/root/scripts/create-package.sh ahmet
# → /root/packages/ahmet.zip
# → /root/packages/ahmet.zip.sha256

# Kullanıcı sil
/root/scripts/remove-user.sh ahmet

# Aktif bağlantıları gör
/root/scripts/list-users.sh
```

---

## EXE Build (Manuel)

Tag push yapmadan kendin build etmek istersen:

```bash
# Windows'ta:
cd client
build_windows.bat

# Linux'ta (wine ile değil, doğrudan Windows runner'da):
pip install pyinstaller customtkinter
pyinstaller --onefile --windowed --name BekreVPN client/vpn_client.py
```

---

## Güvenlik

| Önlem | Detay |
|---|---|
| CA key şifreleme | AES-256 |
| IPv6 leak önleme | sysctl + AllowedIPs ::/0 |
| Race condition fix | flock + ip_registry |
| Peer silme | Python regex (boş blok bırakmaz) |
| Kill switch | istemci wg0.conf'ta iptables kuralları |
| WireGuard port | UDP 443 |
| Paket checksum | SHA256 |

Detaylar: [docs/SECURITY.md](docs/SECURITY.md)

---

## Roadmap

- [ ] Fail2Ban (SSH + OpenVPN brute-force koruması)
- [ ] Offline CA mimarisi
- [ ] WebSocket obfuscation (wstunnel)
- [ ] Monitoring paneli

## Lisans

Kişisel kullanım / eğitim amaçlı.
