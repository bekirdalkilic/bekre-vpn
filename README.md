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

## Dizin Yapısı

```
bekre-vpn/
├── server/
│   ├── scripts/
│   │   ├── add-user.sh        # Kullanıcı ekle (WG peer + OVPN sertifikası)
│   │   ├── remove-user.sh     # Kullanıcı sil (peer temizleme + sertifika iptali)
│   │   ├── list-users.sh      # Kullanıcı listesi + bağlantı durumu
│   │   └── create-package.sh  # İstemci ZIP paketi oluştur (checksum dahil)
│   └── configs/
│       ├── wg0.conf.template           # WireGuard sunucu şablonu
│       └── stunnel-server.conf.template
├── client/
│   └── vpn_client.py          # GUI istemci (CustomTkinter)
├── build_windows.bat          # PyInstaller — BekreVPN.exe
└── docs/
    └── SECURITY.md
```

## Sunucu Kurulumu

### 1. Paketler

```bash
apt install -y wireguard openvpn stunnel4 easy-rsa iptables-persistent python3
```

### 2. WireGuard

```bash
wg genkey | tee /etc/wireguard/server_private.key | wg pubkey > /etc/wireguard/server_public.key
chmod 600 /etc/wireguard/server_private.key

# wg0.conf.template'i kopyala, private key'i doldur
cp server/configs/wg0.conf.template /etc/wireguard/wg0.conf
# PrivateKey alanını doldur: cat /etc/wireguard/server_private.key

systemctl enable --now wg-quick@wg0
```

### 3. Easy-RSA PKI

```bash
cp -r /usr/share/easy-rsa /etc/openvpn/easy-rsa
cd /etc/openvpn/easy-rsa
./easyrsa init-pki
./easyrsa build-ca          # CA key AES-256 ile şifreli oluşturulur
./easyrsa build-server-full server nopass
./easyrsa gen-dh
```

### 4. OpenVPN + Stunnel

```bash
# /etc/openvpn/server.conf — temel konfigürasyon
# /etc/stunnel/stunnel.conf — stunnel-server.conf.template'den

systemctl enable --now openvpn@server stunnel4
```

### 5. Scriptleri Kopyala

```bash
cp server/scripts/*.sh /root/scripts/
chmod +x /root/scripts/*.sh

# IP registry başlat
echo "3" > /etc/wireguard/ip_registry
```

## Kullanıcı Yönetimi

```bash
# Kullanıcı ekle (CA passphrase interaktif sorulur)
./add-user.sh ahmet

# Kullanıcı sil
./remove-user.sh ahmet

# Kullanıcı listesi
./list-users.sh

# İstemci paketi oluştur (ZIP + SHA256)
./create-package.sh ahmet
# → /root/packages/ahmet.zip
# → /root/packages/ahmet.zip.sha256
```

## İstemci Kurulumu

### Windows

1. `BekreVPN.exe`'yi admin olarak çalıştır  
   *(Windows Smart App Control açıksa: Ayarlar → Gizlilik ve Güvenlik → devre dışı bırak)*
2. `configs/` klasörünü EXE ile aynı dizine koy
3. Bağlan

### Linux (Fedora)

```bash
sudo dnf install -y wireguard-tools openvpn stunnel curl python3-tkinter
pip install customtkinter --break-system-packages
python3 vpn_client.py
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install -y wireguard-tools openvpn stunnel4 curl python3-tk
pip install customtkinter --break-system-packages
python3 vpn_client.py
```

## Güvenlik Notları

- WireGuard: **UDP 443** (firewall bypass)
- Stunnel/OpenVPN: **TCP 443** (HTTPS gibi görünür, DPI bypass)
- Aynı port numarası — farklı protokol, çakışma yok
- CA private key sunucuda şifreli tutulur (AES-256)
- IPv6 leak koruması: `sysctl` + `AllowedIPs ::/0`
- Kill switch: istemci configinde iptables kuralları
- IP ataması `flock` + `ip_registry` ile atomik (race condition yok)
- Peer silme Python ile yapılır (boş `[Peer]` bloğu bırakmaz)

Detaylar için: [docs/SECURITY.md](docs/SECURITY.md)

## Roadmap

- [ ] Gerçek GUI log streaming (fake animasyon → process stdout)
- [ ] Gerçek connection state doğrulaması (handshake + route check)
- [ ] Fail2Ban (SSH + OpenVPN brute-force koruması)
- [ ] Offline CA mimarisi (CA'yı internet-facing sunucudan ayır)
- [ ] WebSocket obfuscation (wstunnel)
- [ ] Monitoring paneli (bağlı kullanıcılar, trafik istatistikleri)

## Lisans

Kişisel kullanım / eğitim amaçlı.
