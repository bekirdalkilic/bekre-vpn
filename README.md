> **Proje Durumu:** Bu repo, kendi VPN altyapınızı kurmanız için kaynak kod ve referans kurulum adımları sunar. **Proje sahibinin canlı VPN sunucusuna erişim sağlamaz.** Gerçek sunucu adresleri, kimlik bilgileri, private key'ler, sertifikalar ve production kullanıcı yapılandırmaları bilerek dahil edilmemiştir — tüm config şablonları placeholder değerler içerir. Aşağıdaki kurulum adımları mimariyi ve yaklaşımı göstermek amaçlıdır; kendi sunucunuzda kurmak isterseniz kendi IP adresinizi, kendi anahtarlarınızı ve kendi sertifikalarınızı oluşturmanız gerekir. Kullanım koşulları için [NOTICE.md](NOTICE.md)'ye bakın.

# Bekre VPN

Dual-protocol self-hosted VPN altyapısı — kısıtlayıcı ağlarda (kurumsal, akademik, kamu) DPI (Deep Packet Inspection) tabanlı VPN engellerini aşmak için tasarlandı.

## Mimari

```
İstemci
├── [WG] HIZLI MOD     →  UDP 443   →  WireGuard (direkt)
└── [OVPN] GİZLİ MOD   →  TCP 443   →  Stunnel → OpenVPN
                                        (DPI bypass, kısıtlı ağlar için)
```

WireGuard ve Stunnel aynı 443 portunu paylaşır — biri UDP, diğeri TCP olduğu için çakışma olmaz. Bu, port bazlı engellemeleri ve protokol bazlı DPI filtrelemeyi aynı anda aşmaya yönelik bir tasarım kararıdır.

**Referans sunucu ortamı:** Ubuntu 24.04 LTS (genel bir Linux VPS — herhangi bir sağlayıcıda çalışır)
**İstemci:** Windows (derlenmiş EXE) · Linux (Python script)

## İstemci Kurulumu

> Aşağıdaki adımlar, sunucu yöneticisinden config dosyalarını almış olduğunuzu varsayar. Bu repo gerçek config dosyası içermez.

### Windows

**Gereken harici bağımlılıklar (önceden kurulu olmalı):**
- WireGuard (wireguard.com/install)
- OpenVPN (openvpn.net/community-downloads)
- Stunnel (stunnel.org/downloads.html)

1. [Releases](../../releases) sayfasından en güncel EXE'yi indirin
2. Sunucu yöneticinizden `configs.zip` alın, açın
3. Klasör yapısı şöyle olmalı:
   ```
   BekreVPN.exe
   configs/
   ├── wg0.conf
   ├── client.ovpn
   └── stunnel.conf
   ```
4. EXE'ye sağ tık → **Yönetici olarak çalıştır**

> **Not:** EXE imzasız bir build olduğu için Windows tarafından "tanınmayan yayıncı" uyarısı görebilirsiniz. Eğer bu sizi rahatsız ediyorsa, kaynak koddan kendiniz derleyebilirsiniz (aşağıda "EXE Build" bölümüne bakın) — bu durumda Windows'un güvenlik özelliklerini kapatmanıza gerek kalmaz.

### Linux (Fedora)

```bash
sudo dnf install -y wireguard-tools openvpn stunnel curl python3-tkinter
pip install customtkinter --break-system-packages

# Sunucu yöneticinizden configs/ klasörünü alın, sonra:
python3 client/vpn_client.py
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install -y wireguard-tools openvpn stunnel4 curl python3-tk
pip install customtkinter --break-system-packages
python3 client/vpn_client.py
```

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
│   │   ├── add-user.sh        # Kullanıcı ekle (referans script)
│   │   ├── remove-user.sh     # Kullanıcı sil
│   │   ├── list-users.sh      # Kullanıcı listesi + bağlantı durumu
│   │   └── create-package.sh  # configs.zip oluştur (SHA256 dahil)
│   └── configs/
│       ├── wg0.conf.template
│       └── stunnel-server.conf.template
├── docs/
│   └── SECURITY.md
└── NOTICE.md
```

> **Not:** `server/configs/` içinde sadece WireGuard ve Stunnel şablonları bulunur. OpenVPN sunucu konfigürasyonu (`server.conf`) ve sertifika üretim adımları aşağıda anlatılmıştır ancak repo içine dahil edilmemiştir — bunlar ortamınıza özgü olmalıdır.

## Referans Sunucu Kurulumu

Aşağıdaki adımlar genel bir yol haritasıdır; eksiksiz, kopyala-yapıştır bir production rehberi değildir. Her ortam farklı olduğu için kendi sunucunuza göre uyarlamanız gerekir.

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

OpenVPN sunucu konfigürasyonu (`server.conf`) bu repoya dahil değildir — OpenVPN'in resmi dokümantasyonundaki örnek server.conf temel alınarak, sertifika yollarının yukarıdaki Easy-RSA çıktılarına işaret ettiğinden emin olarak oluşturulmalıdır.

Stunnel için `server/configs/stunnel-server.conf.template` şablonunu kullanın; TLS sertifikası ve anahtarı (`cert`, `key` alanları) kendi sunucunuzda üretmeniz veya Let's Encrypt ile almanız gerekir.

```bash
systemctl enable --now openvpn-server@server stunnel4
```

### 5. Scriptleri kopyala

```bash
cp server/scripts/*.sh /root/scripts/
chmod +x /root/scripts/*.sh
echo "3" > /etc/wireguard/ip_registry
```

`add-user.sh` çalıştırmadan önce dosyanın başındaki `SERVER_IP` placeholder'ını kendi sunucu IP'inizle değiştirmeniz gerekir — script bu kontrolü otomatik yapar ve doldurulmadıysa uyarı verip durur.

## Kullanıcı Yönetimi (Referans Scriptler)

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

> **Not:** `create-package.sh`, `/root/installers/` ve `/root/scripts/BekreVPN.exe` gibi repo dışı dosyalara referans verir — bunlar kendi ortamınızda ayrıca hazırlanmalıdır.

## EXE Build (Manuel)

Tag push yapmadan kendiniz build etmek isterseniz:

```bash
# Windows'ta:
cd client
build_windows.bat
```

```bash
# Veya doğrudan komut satırından:
pip install pyinstaller customtkinter
pyinstaller --onefile --windowed --name BekreVPN client/vpn_client.py
```

## Güvenlik Yaklaşımı

| Önlem | Detay |
|---|---|
| CA key şifreleme | AES-256 |
| IPv6 leak önleme | sysctl ile IPv6 kapatılıyor |
| Race condition fix | flock + ip_registry |
| Peer silme | Python regex (boş blok bırakmaz) |
| Kill switch | istemci wg0.conf'ta iptables kuralları |
| WireGuard port | UDP 443 |
| Paket checksum | SHA256 |
| Brute-force koruması | Fail2Ban (referans ortamda aktif, repo dışı kurulum) |

Detaylar: [docs/SECURITY.md](docs/SECURITY.md)

## Roadmap

- [ ] Offline CA mimarisi
- [ ] WebSocket obfuscation (wstunnel)
- [ ] Monitoring paneli
- [ ] Kullanıcı adı input validasyonu (script güvenliği)

## Lisans / Kullanım

Kişisel kullanım ve eğitim amaçlı. Ticari kullanım ve yeniden satış yasaktır. Detaylar için [NOTICE.md](NOTICE.md).
