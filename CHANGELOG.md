# Changelog

Biçim [Keep a Changelog](https://keepachangelog.com/tr/1.1.0/) yapısını izler.

> **Yayımlanmış sürümler ile `main` farklıdır.** Yayımlanmış sürümler için GitHub Releases sayfasına bakın. Aşağıdaki `[Unreleased]` bölümü `main` dalındaki değişiklikleri listeler; bunlar mock/statik testlerden geçti ancak **gerçek ortamda test edilmedi** ([docs/TESTING.md](docs/TESTING.md)) ve henüz bir Release'e dahil edilmemiş olabilir. Sürüm numarası uydurulmamıştır.

## [Unreleased]

### Güvenlik
- `create-package.sh`: ortak kilidi alıyor (kullanıcı yoksa `add-user.sh`'ı çağırdıktan sonra); kilit beklerken kullanıcı silinmişse paket üretmiyor.
- `remove-user.sh`: `/root/packages/<kullanıcı>/`, `.zip` ve `.sha256` (özel anahtar içerir) da siliniyor; istemci dizini yoksa yetim paketler için uyarı veriyor.
- `add-user.sh`: registry/IP doğrulamaları sertifika üretiminden önceye alındı; SIGTERM/SIGINT/SIGHUP'ta da geri alma çalışıyor (mock testle bulunan eksik); geri alma sınırları (sertifika iptal edilmez, `ip_registry` geri alınmaz, SIGKILL kapsanmaz) betik yorumunda ve belgelerde açıklandı.
- `add-user.sh`: sertifika üretimi WireGuard/IP değişikliklerinden önceye alındı; sonraki adımlar başarısız olursa peer, anahtar ve kullanıcı dizini geri alınıyor.
- `add-user.sh` / `remove-user.sh`: tüm işlem boyunca tutulan ortak kilit; kilit dosyası `/tmp` yerine root-only `/etc/wireguard/` altına taşındı.
- `add-user.sh`: `ip_registry` bütünlük kontrolleri (sayısal değer, 254 üst sınırı, `wg0.conf` içinde çakışma).
- `add-user.sh`, `create-package.sh`: `umask 077`; paket ve checksum dosyaları `600`.
- `remove-user.sh`: sertifika iptali hataları artık yutulmuyor; iptal başarısızsa hiçbir şey silinmiyor; zaten iptal edilmiş sertifika tekrar çalıştırmayı engellemiyor.
- `vpn_client.py`: `pkill -f stunnel/openvpn` ve `taskkill /im` yerine yalnızca bu istemcinin kendi sürecleri sonlandırılıyor.
- GitHub Actions: `contents: write` izni iş seviyesine indirildi.

### Değişti
- Linux kurulumu: `pip --break-system-packages` yerine sanal ortam (`python3 -m venv .venv`); `kur.sh` aynı şekilde `.venv` kuruyor (`set -e`, Debian için `python3-venv`).
- README: "Açık sorunlar ve bilinen sınırlar" ve "Sürümler ve `main` dalı" bölümleri; portföy/eğitim amaçlı konumlandırma; incelemelerin yapay zekâ destekli olduğu ve bağımsız denetim olmadığı notu.
- `vpn_client.py`: boş `except:` blokları `except Exception:` yapıldı.
- Bağımlılıklar sabitlendi (`requirements.txt`, `requirements-build.txt`).
- SHA256 dosyası standart `sha256sum` biçiminde üretiliyor (PowerShell `Get-FileHash`).
- README ve SECURITY.md: repo içi ve repo dışı önlemler ayrıldı; doğrulanmamış iddialar kaldırıldı veya "doğrulanmadı" olarak işaretlendi.

### Düzeltildi
- `stunnel-server.conf.template`: satır içi `;` yorumu (Stunnel desteklemez) ayrı satıra alındı.
- README: `net.ipv4.ip_forward`, `crl-verify`, `vpn_client.py` kopyalama adımları eklendi.
- `list-users.sh`: kullanılmayan değişken kaldırıldı.

### Eklendi
- `docs/ARCHITECTURE.md`, `docs/TESTING.md`, `CHANGELOG.md`, `requirements*.txt`.
- `tests/`: yeniden çalıştırılabilir mock/statik testler (`bash tests/run_all.sh`). Gerçek VPN testi değildir.
