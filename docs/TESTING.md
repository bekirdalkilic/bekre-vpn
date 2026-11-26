# Test ve Doğrulama Durumu

Bu belge üç şeyi birbirinden ayırır: (A) bu incelemede yapılan **statik analiz ve mock betik testleri** (`tests/` dizininde yeniden çalıştırılabilir), (B) **gerçek ortamda yapılan testler** (kanıtlı), (C) **planlanan ama yapılmamış** testler. Yapılmamış hiçbir test "geçti" olarak gösterilmez. Boş satır = test yapılmadı veya kanıtı bu repoda yok.

## A. Statik analiz ve mock testler (bu incelemede çalıştırıldı; `bash tests/run_all.sh`)

> Mock testler gerçek `wg`, `systemctl` veya `easyrsa` kullanmaz; bunların yerine sandbox'ta sahte (shim) komutlar kullanılır. Betik **mantığını** (sıralama, geri alma, kilit, izinler) doğrular; WireGuard/OpenVPN/Easy-RSA davranışını doğrulamaz.

| Kontrol | Araç | Sonuç |
|---|---|---|
| Bash sözdizimi (4 betik) | `bash -n` | Hata yok |
| Bash statik analiz | ShellCheck 0.11.0 | Uyarı seviyesi temiz; yalnızca 2 stil/info notu |
| Python sözdizimi | `py_compile` (3.13) | Hata yok |
| Python statik analiz | flake8 7.4.1 | Temiz |
| YAML geçerliliği | PyYAML 6.0.3 (workflow) | Geçerli |
| Gizli bilgi taraması | Python regex taraması | 0 eşleşme; repoda anahtar/sertifika dosyası yok |
| Belge–kaynak tutarlılığı | Elle inceleme | Dosya listesi ve betik davranışları belgelerle karşılaştırıldı |

Mock betik testleri `tests/` altındadır ve `bash tests/run_all.sh` ile yeniden çalıştırılır (root gerekmez, `/etc` veya `/root`'a yazmaz; ayrıntı: [tests/README.md](../tests/README.md)). Betiklerin yolları geçici dizine yönlendirilmiş kopyaları çalıştırılır.

| Dosya | Senaryolar |
|---|---|
| `test_add_user.sh` (T1–T11) | normal ekleme + izinler; aynı kullanıcı reddi; easyrsa hatasında durum değişmez; **sertifika sonrası hatada geri alma ve bilinen sınırlar** (sertifika iptal edilmez, `ip_registry` geri alınmaz); tutarsız/bozuk registry ve 254 sınırı (sertifika üretilmeden reddedilir); 5 eşzamanlı ekleme; geçersiz adlar; SERVER_IP placeholder; SIGTERM ile kesilme |
| `test_remove_user.sh` (R1–R7) | iptal hatasında hiçbir şey silinmez; normal silme **(paket dizini, zip ve sha256 dahil)**; zaten iptal edilmiş sertifika; CRL hatası; olmayan kullanıcı ve yetim paket uyarısı; eşzamanlı ekle+sil; geçersiz ad |
| `test_create_package.sh` (P1–P4) | paket içeriği, izinler (600), sha256 doğrulaması, `kur.sh` (venv, `--break-system-packages` yok); kullanıcı yoksa add-user çağrısı (kilitlenme yok); kilit tutulurken bekleme; kilit beklerken kullanıcı silinirse paket üretilmez |
| `test_client_process_pattern.py` | İstemcinin süreç eşleştirme deseni: gerçek `pkill -f` + sahte süreçlerle yalnızca kendi süreçleri sonlanır (başkasının stunnel/openvpn'i, ilgisiz `vim stunnel-notes.txt` ve desen komut satırı etkilenmez; boşluk/özel karakterli yol dahil). Windows `taskkill` yolu **test edilmez** |
| `test_static.sh` | `bash -n`, ShellCheck, flake8, YAML, gizli bilgi taraması, `requirements.txt` ↔ `kur.sh` sürüm eşleşmesi, `--break-system-packages` kullanımı, README/Markdown bağlantıları ve dosya listesi, "7. satır" referansı, bölüm B'de kanıtsız "geçti" olmaması |

Bu incelemedeki çalıştırma: statik 42, add-user 47, remove-user 33, create-package 19 kontrol ve 2 Python testi geçti. Bu sayılar yalnızca betik mantığı kontrolleridir.

> **Sınır:** Bu testler gerçek bir VPN bağlantısını, Easy-RSA/WireGuard/OpenVPN/Stunnel/systemd davranışını, DNS/IPv6 sızıntısını veya kill switch'i test **etmez**. Sahte komutlarla yazılan bir test, gerçek komutların aynı şekilde davranacağını kanıtlamaz.

Ek statik/ortam notu: `pip install -r requirements.txt` bir sanal ortamda çalıştırıldı (customtkinter 5.2.2 kuruldu); `import customtkinter` bu ortamda `tkinter` olmadığı için denenemedi.

## B. Gerçek ortam testleri (kanıtlı)

Bu repoda belgelenmiş gerçek ortam test kaydı **yoktur**. Testleri yapmış olmak ile kaydının bu repoda bulunması farklı şeylerdir; yapıldıysa tarih, ortam ve kanıtla aşağıya eklenmelidir.

| # | Test | Tarih | Ortam (OS / mod) | Sonuç | Kanıt |
|---|---|---|---|---|---|
| 1 | WireGuard el sıkışması | — | — | — | — |
| 2 | Çıkış IP'si | — | — | — | — |
| 3 | DNS sızıntısı | — | — | — | — |
| 4 | IPv6 sızıntısı | — | — | — | — |
| 5 | Kill switch | — | — | — | — |
| 6 | Port durumu (dışarıdan) | — | — | — | — |
| 7 | Gizli mod (Stunnel → OpenVPN) | — | — | — | — |
| 8 | Sertifika iptali (CRL uygulaması) | — | — | — | — |

## C. Not Tested (bu incelemede test edilmedi)

- Gerçek WireGuard, OpenVPN ve Stunnel bağlantıları (her iki mod)
- DNS sızıntısı; IPv4 ve IPv6 sızıntı koruması
- Kill switch davranışı (Linux iptables kuralları dahil), `nft` arka ucu
- CRL'nin OpenVPN tarafından gerçekten uygulanması
- Gerçek Easy-RSA ve systemd davranışı
- Windows istemcisi (`taskkill /pid` yolu, WireGuard tünel servisi)
- GUI çalışma zamanı (customtkinter sandbox'ta kurulu değil)
- `pkexec` / polkit akışı
- PyInstaller derlemesi ve GitHub Actions workflow'unun çalıştırılması
- GitHub Releases ve commit geçmişi (ZIP'ten doğrulanamaz)

## Canlı test kaydı şablonu

Gerçek ortamda bir test yapıldığında bölüm B tablosuna şunları ekleyin; kanıtsız satır "yapıldı" sayılmaz:

- Tarih ve **test edilen commit/etiket** (`git rev-parse --short HEAD` veya Release adı) — `main` ile Release'in karışmaması için
- Sunucu: dağıtım/sürüm, `wg --version`, `openvpn --version`, `stunnel -version`, Easy-RSA sürümü
- İstemci: OS/sürüm, mod (WireGuard / Stunnel+OpenVPN), IPv4/IPv6 durumu
- Komutlar ve ham çıktı (ekran görüntüsü veya log dosyası); beklenen ile gözlenen sonuç
- Başarısız veya beklenmeyen sonuçlar da olduğu gibi kaydedilir (ör. IPv6 sızıntısı, kill switch IPv6'da çalışmıyor)

Test edilmemiş bir sürüm GitHub'da **pre-release** olarak işaretlenmelidir.

## Test Prosedürleri (planlanan)

### 1. WireGuard el sıkışması
```bash
sudo wg show            # "latest handshake" görünmeli
```
Beklenen: handshake zamanı görünür, transfer sayaçları artar.

### 2. Çıkış IP'si
```bash
curl -s ifconfig.me
```
Beklenen: tünel kapalıyken yerel IP, açıkken sunucu IP'si.

### 3. DNS sızıntısı
```bash
sudo tcpdump -ni <fiziksel_arayuz> port 53
# başka terminalde:
dig example.com
```
Beklenen: fiziksel arayüzde DNS paketi yok. Ek olarak bir DNS leak test sitesinde yalnızca VPN çıkış DNS'i görünmeli. OpenVPN modunu ayrıca test edin (`client.ovpn` DNS itmez; `server.conf`'a bağlıdır).

### 4. IPv6 sızıntısı
```bash
curl -6 --max-time 5 ifconfig.co
```
Beklenen: istek başarısız olur. Hem WireGuard hem OpenVPN modunda test edin.

### 5. Kill switch (Linux, WireGuard modu)
Tünel açıkken sunucuda tüneli durdurun (`systemctl stop wg-quick@wg0`), istemcide:
```bash
sudo tcpdump -ni <fiziksel_arayuz> not udp port 443
ping -c 3 1.1.1.1
curl -6 --max-time 5 ifconfig.co   # IPv6 kural eksikliğini gösterir
```
Beklenen: IPv4 `ping` başarısız; fiziksel arayüzde şifrelenmemiş IPv4 trafiği yok. IPv6 için kural olmadığından sonucu olduğu gibi kaydedin. Test sonunda sunucuda tüneli geri açın. Windows ve OpenVPN modu için kill switch **yoktur**.

### 6. Port durumu
```bash
nmap -sU -p 443 <SUNUCU_IP>
nmap -sT -p 443,1194 <SUNUCU_IP>
```
Beklenen: 443/udp açık, 443/tcp açık, 1194/tcp dışarıdan kapalı.

### 7. Gizli mod
Stunnel ve OpenVPN ile bağlanıp test 2'yi tekrarlayın; Wireshark'ta 443/TCP trafiğinin TLS göründüğünü kontrol edin.

### 8. Sertifika iptali
`remove-user.sh` sonrası eski `client.ovpn` ile bağlanmayı deneyin. Beklenen: reddedilir (`server.conf` içinde `crl-verify` varsa). Sunucu günlüğünde iptal nedeni görülmeli.
