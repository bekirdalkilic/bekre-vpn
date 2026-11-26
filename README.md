> **Proje Durumu:** Bu repo, kendi VPN altyapınızı kurmanız için kaynak kod ve referans kurulum adımları sunar. **Proje sahibinin canlı VPN sunucusuna erişim sağlamaz.** Gerçek sunucu adresleri, kimlik bilgileri, private key'ler, sertifikalar ve production kullanıcı yapılandırmaları bilerek dahil edilmemiştir — tüm config şablonları placeholder değerler içerir. Aşağıdaki kurulum adımları mimariyi ve yaklaşımı göstermek amaçlıdır; kendi sunucunuzda kurmak isterseniz kendi IP adresinizi, kendi anahtarlarınızı ve kendi sertifikalarınızı oluşturmanız gerekir. Kullanım koşulları için [NOTICE.md](NOTICE.md)'ye bakın.

# Bekre VPN

Linux VPS üzerinde çalışan, kişisel ve eğitim amaçlı **self-hosted VPN altyapısı**. WireGuard (UDP 443) ve TLS (Stunnel) tüneli içinde OpenVPN (TCP 443) birlikte sunulur; UDP'nin kısıtlandığı ağlarda da bağlantı kurabilmek hedeflenir. Repo; sunucu şablonlarını, kullanıcı yönetim betiklerini, bir GUI istemcisini ve EXE derleme hattını içerir.

> **Konumlandırma:** Kişisel ve eğitim amaçlı bir **teknik portföy projesidir**. Kurumsal veya üretim kullanımı için doğrulanmış bir ürün değildir. Güvenlik incelemeleri **yapay zekâ desteğiyle (Claude)** yapılmış kod incelemeleri ve mock testlerdir; bağımsız profesyonel güvenlik denetimi, sızma testi veya sertifikasyon **değildir**. Hangi özelliklerin gerçekten test edildiği [docs/TESTING.md](docs/TESTING.md) içinde ayrıdır; yapılmamış testler "Not Tested" olarak işaretlidir.

**Teknolojiler:** WireGuard, OpenVPN, Stunnel (TLS), Easy-RSA (PKI), iptables, Bash, Python 3 + CustomTkinter, PyInstaller, GitHub Actions

**Mevcut özellikler**
- İki modlu bağlantı: WireGuard ve Stunnel + OpenVPN
- Easy-RSA ile kullanıcı bazlı sertifika üretimi ve iptali
- Kullanıcı ekleme/silme/paketleme betikleri (ortak kilit, kısmi hata durumunda geri alma, mock testli — sınırlar aşağıda)
- Kullanıcıya özel yapılandırma paketi + SHA256
- Linux/Windows GUI istemcisi (Windows için PyInstaller EXE)
- Linux + WireGuard modunda iptables tabanlı kill switch (yalnızca IPv4; **gerçek ortamda test edilmedi**)

## Açık sorunlar ve bilinen sınırlar

Bunlar çözülmemiştir veya doğrulanmamıştır; ayrıntı ve önem derecesi için [docs/SECURITY.md](docs/SECURITY.md).

- **Sertifika iptali (CRL):** `remove-user.sh` sertifikayı iptal eder ve CRL üretir, ancak OpenVPN'in iptali uygulaması için `server.conf` içinde `crl-verify` bulunmalıdır. `server.conf` repoda **yoktur**; bu satır yoksa iptal edilen kullanıcı OpenVPN ile bağlanmaya devam edebilir. Gerçek ortamda test edilmedi.
- **Stunnel sertifika doğrulaması:** Üretilen istemci `stunnel.conf` sunucu sertifikasını doğrulamaz. Sunucu kimliğini yalnızca iç OpenVPN TLS katmanı (`remote-cert-tls server`, gömülü CA) doğrular.
- **Anahtar saklama mimarisi:** İstemci özel anahtarları (WireGuard ve OpenVPN, parolasız) sunucuda `/root/clients/` altında tutulur ve kullanıcı paketine (`.zip`) girer. CA anahtarı da internete açık sunucudadır (parola ile şifreli). Sunucu ele geçirilirse tüm kullanıcı anahtarları etkilenir.
- **Mevcut WireGuard yapılandırmasının üzerine yazma:** Linux istemcisi WireGuard modunda `/etc/wireguard/wg0.conf` dosyasının **üzerine yazar**; aynı adlı kendi yapılandırmanız varsa önce yedekleyin.
- **Kill switch / DNS / IPv6:** Kill switch yalnızca Linux + `wg-quick` + WireGuard modunda ve yalnızca IPv4 için vardır; Windows'ta ve OpenVPN modunda yoktur. DNS ve IPv6 sızıntı korumaları test edilmemiştir.
- **`add-user.sh` geri alma sınırları:** Sertifika üretildikten sonraki bir hatada sertifika **otomatik iptal edilmez** ve `ip_registry` sayacı **geri alınmaz** (IP numarası harcanır). `SIGKILL` veya ani kapanmada geri alma çalışmaz.
- **Kullanıcı paketleri:** `.zip` ve paket dizini özel anahtar içerir; `remove-user.sh` sunucudaki kopyaları siler, ancak kullanıcıya daha önce iletilmiş kopyalar geri alınamaz.
- Her kullanıcı ekleme/silme `wg-quick@wg0` servisini yeniden başlatır (aktif oturumlar kısa süre kesilir).

## Sürümler ve `main` dalı

- GitHub **Releases** sayfasında yayımlanmış sürümler varsa, bunlar (etiketli, EXE içeren) `main` dalındaki kaynak kodla **aynı değildir**.
- `main`, güvenlik incelemesi sonrası değişiklikleri içerir ([CHANGELOG](CHANGELOG.md) → `[Unreleased]`). Bu değişiklikler **mock/statik testlerden geçti, gerçek ortamda test edilmedi**; önceki bir Release'teki EXE bunları içermeyebilir.
- Yeni bir etiket/Release oluşturmadan önce [docs/TESTING.md](docs/TESTING.md) bölüm B'deki gerçek ortam testlerinin yapılması ve kayıt altına alınması önerilir; test edilmemiş bir sürüm GitHub'da **pre-release** olarak işaretlenmelidir.
- Kaynak koddan çalıştırırken `main`'i, EXE indirirken ilgili Release notlarını esas alın.

**Belgeler:** [Mimari](docs/ARCHITECTURE.md) · [Güvenlik](docs/SECURITY.md) · [Test durumu](docs/TESTING.md) · [Testler (`tests/`)](tests/README.md) · [Changelog](CHANGELOG.md) · [Kullanım koşulları](NOTICE.md)

> **Sorumluluk:** Bu altyapıyı kullanmak, bulunduğunuz ağın kullanım politikalarına ve yürürlükteki yasalara uygun olma sorumluluğunu size ait kılar.

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
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt

# Sunucu yöneticinizden configs/ klasörünü alın, sonra:
.venv/bin/python client/vpn_client.py
```

### Linux (Ubuntu/Debian)

```bash
sudo apt install -y wireguard-tools openvpn stunnel4 curl python3-tk python3-venv
python3 -m venv .venv
.venv/bin/pip install -r requirements.txt
.venv/bin/python client/vpn_client.py
```

> **Neden sanal ortam (venv)?** `pip --break-system-packages`, dağıtımın Python paket yöneticisini koruyan kısıtı (PEP 668) devre dışı bırakır ve sistem Python'unu (dnf/apt araçlarının da kullandığı) bozabilir. Bu projede yalnızca `customtkinter` gerekir; `.venv` içine kurulur. `tkinter` sistem paketi olarak kurulur; sanal ortamın sistem Python'unun standart kütüphanesini kullanması beklenir, ancak bu doğrulanmadı. `pip install -r requirements.txt` adımı bir sanal ortamda denendi (customtkinter 5.2.2 kuruldu); GUI'nin gerçek bir masaüstünde çalışması **test edilmedi**.

> **Linux notu:** İstemci yetkili işlemleri `pkexec` (polkit) ile çalıştırır ve WireGuard modunda `/etc/wireguard/wg0.conf` dosyasının **üzerine yazar**; aynı adlı kendi yapılandırmanız varsa önce yedekleyin. Windows'ta kill switch yoktur; OpenVPN modunda hiçbir platformda yoktur ([detay](docs/SECURITY.md)).

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
│   ├── ARCHITECTURE.md     # Mimari, PKI, sınırlar, Mermaid diyagramı
│   ├── SECURITY.md         # Önlemler, bulgular, bilinen riskler
│   └── TESTING.md          # Statik/mock sonuçlar, gerçek test kayıtları, Not Tested listesi
├── tests/                  # Betik mantığı testleri (mock; gerçek VPN testi değil) → tests/README.md
├── requirements.txt        # İstemci bağımlılığı (sabitlenmiş)
├── requirements-build.txt  # EXE derleme bağımlılıkları (sabitlenmiş)
├── CHANGELOG.md
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

# NAT'ın çalışması için IP yönlendirme açık olmalı (kalıcı):
echo 'net.ipv4.ip_forward=1' > /etc/sysctl.d/99-bekre-vpn.conf
sysctl --system

# Şablondaki NAT kuralı arayüz adını "eth0" varsayar; sunucunuzda farklıysa
# (ip route | grep default) wg0.conf içinde düzeltin.
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

OpenVPN yalnızca `127.0.0.1:1194` üzerinde dinlemeli (dışarıya Stunnel açar). `remove-user.sh` ile iptal edilen sertifikaların gerçekten reddedilmesi için `server.conf` içinde `crl-verify /etc/openvpn/easy-rsa/pki/crl.pem` satırı bulunmalıdır; aksi hâlde iptal etkisiz kalır.

Stunnel için `server/configs/stunnel-server.conf.template` şablonunu kullanın; TLS sertifikası ve anahtarı (`cert`, `key` alanları) kendi sunucunuzda üretmeniz veya Let's Encrypt ile almanız gerekir.

```bash
systemctl enable --now openvpn-server@server stunnel4
```

### 5. Scriptleri kopyala

```bash
mkdir -p /root/scripts
cp server/scripts/*.sh /root/scripts/
cp client/vpn_client.py /root/scripts/     # create-package.sh Linux paketine bunu ekler
chmod +x /root/scripts/*.sh
echo "3" > /etc/wireguard/ip_registry
```

Windows paketi için (isteğe bağlı) `BekreVPN.exe` dosyasını (Releases'tan indirip) `/root/scripts/` içine koyun. `create-package.sh` ayrıca `/root/installers/` altında WireGuard, OpenVPN ve Stunnel kurulum dosyalarını arar; eksikse uyarı verip devam eder.

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

> **Not:** `create-package.sh`, `/root/installers/`, `/root/scripts/BekreVPN.exe` ve `kur_template.bat` gibi repo dışı dosyalara referans verir; bunlar yoksa ilgili adım atlanır.

**Davranış ve sınırlar**
- **Eşzamanlılık:** `add-user.sh`, `remove-user.sh` ve `create-package.sh` aynı kilidi (`/etc/wireguard/.bekre-vpn.lock`) kullanır; aynı anda yalnızca biri çalışır. (`create-package.sh` kullanıcı yoksa önce `add-user.sh`'ı çağırır ve kilidi bundan sonra alır.)
- **`add-user.sh` geri alma:** Hata olursa peer, WireGuard anahtar dosyaları ve kullanıcı dizini geri alınır. **Alınmayanlar:** üretilmiş sertifika otomatik iptal edilmez (hata mesajındaki `easyrsa revoke` komutuyla elle iptal edin), `ip_registry` sayacı geri sarılmaz, `SIGKILL`/elektrik kesintisinde hiçbir geri alma çalışmaz.
- **Paketler ve anahtarlar:** `create-package.sh` çıktısı (`/root/packages/<kullanıcı>/` ve `.zip`) kullanıcının **özel anahtarlarını** içerir: güvenli kanaldan iletin, iletimden sonra sunucudaki kopyayı silin. `remove-user.sh` bu paketleri de siler; kullanıcıya daha önce iletilmiş kopyalar geri alınamaz, sertifika iptali ve peer silme yalnızca erişimi keser. Easy-RSA kendi `pki/` dizininde anahtar/sertifika kopyaları tutmaya devam edebilir. Dosya silme güvenli silme (secure erase) değildir.
- Daha önce silinmiş (iptal edilmiş) bir kullanıcı adını yeniden kullanmak Easy-RSA tarafında sorun çıkarabilir; yeni bir ad kullanın (bu davranış gerçek Easy-RSA ile test edilmedi).

## EXE Build (Manuel)

Tag push yapmadan kendiniz build etmek isterseniz:

```bash
# Windows'ta:
cd client
build_windows.bat
```

```bash
# Veya doğrudan komut satırından:
pip install -r requirements-build.txt
pyinstaller --onefile --windowed --name BekreVPN client/vpn_client.py
```

## Güvenlik Yaklaşımı

| Önlem | Detay | Doğrulama |
|---|---|---|
| CA key şifreleme | AES-256 parola (easyrsa) | Test edilmedi |
| Kullanıcı yönetimi | Ortak `flock` kilidi, kısmi hata geri alma (sınırlı), `umask 077`, kullanıcı adı doğrulama, silmede paket temizliği | Mock test (`tests/`) |
| Kill switch | İstemci wg0.conf'ta iptables; **yalnızca Linux/wg-quick, WireGuard modu, IPv4** | Test edilmedi |
| IPv6 | Sunucuda sysctl ile kapatılır; istemci sızıntı koruması olarak doğrulanmadı | Test edilmedi |
| Paket checksum | SHA256 (paket ve EXE) | Workflow çalıştırılmadı |
| Brute-force koruması, SSH hardening, DNS-over-TLS | Referans ortamda uygulandı; **repo bunları otomatikleştirmez** | — |

Ayrıntılar ve bulgu listesi: [docs/SECURITY.md](docs/SECURITY.md) · Test kapsamı: [docs/TESTING.md](docs/TESTING.md)

## Roadmap

- [ ] Offline CA mimarisi
- [ ] WebSocket obfuscation (wstunnel)
- [ ] Monitoring paneli
- [x] Kullanıcı adı input validasyonu (script güvenliği)
- [ ] OpenVPN `server.conf` şablonu ve `crl-verify` ayarı
- [ ] Windows için kill switch (WireGuard modu)
- [ ] Kill switch için `ip6tables` kuralları ve gerçek ortam testi
- [ ] Stunnel istemcisinde sunucu sertifikası doğrulaması (`verifyChain`)
- [ ] İstemcide anahtar üretimi (sunucuda özel anahtar saklamama)
- [ ] Ekleme/silmede `wg syncconf` ile oturumları kesmeden güncelleme
- [ ] GitHub Actions adımlarını commit SHA'sına sabitleme
- [ ] Gerçek ortam testlerinin (TESTING.md bölüm B) yapılıp kanıtla kaydedilmesi

## Lisans / Kullanım

Kişisel kullanım ve eğitim amaçlı. Ticari kullanım ve yeniden satış yasaktır. Detaylar için [NOTICE.md](NOTICE.md).
