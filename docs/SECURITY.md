# Güvenlik Notları

Bu belge projenin **gerçek güvenlik durumunu** özetler. Proje kişisel/eğitim amaçlı bir teknik portföy çalışmasıdır; ticari veya kurumsal olarak doğrulanmış bir güvenlik ürünü değildir.

> **İnceleme niteliği:** Buradaki bulgular, **yapay zekâ desteğiyle (Claude) yapılmış kod incelemeleri**, statik analiz ve mock testlerine dayanır. Bağımsız bir profesyonel güvenlik denetimi, sızma testi veya sertifikasyon **değildir**; gerçek ortamda doğrulanmamış hiçbir önlem "güvenli" olarak işaretlenmemiştir.

Terimler:
- **Kapsam:** önlemin bu repodaki kodla mı geldiği, yoksa referans sunucuda elle uygulanıp repoda otomatikleştirilmediği.
- **Doğrulama:** `Statik/Mock` = kod incelemesi, sözdizimi/ShellCheck veya sahte (mock) ikili dosyalarla betik testi; `Gerçek test` = gerçek WireGuard/OpenVPN/Stunnel ortamında yapılmış ve kanıtlanmış test; `Test edilmedi` = hiçbiri. Ayrıntı: [TESTING.md](TESTING.md).

## Mevcut Önlemler

| Önlem | Kapsam | Doğrulama | Detay |
|---|---|---|---|
| CA key şifreleme | Repo (komut) | Test edilmedi | `easyrsa build-ca` AES-256 parola ile; her easyrsa işleminde parola gerekir |
| Kullanıcı adı doğrulama | Repo | Mock | `^[a-zA-Z0-9_-]+$`; add-user, remove-user, create-package |
| Eşzamanlı yönetim kilidi | Repo | Mock | `/etc/wireguard/.bekre-vpn.lock` üzerinde `flock`; add-user, remove-user ve create-package tüm işlem boyunca tutar |
| Kısmi hata geri alma (sınırlı) | Repo | Mock | add-user hata/SIGTERM/SIGINT/SIGHUP durumunda peer, anahtar, dizin geri alınır. **Sertifika iptal edilmez, `ip_registry` geri alınmaz, SIGKILL kapsanmaz** (aşağıya bakın) |
| Silmede paket temizliği | Repo | Mock | remove-user `/root/packages/<kullanıcı>/`, `.zip` ve `.sha256` dosyalarını da siler |
| Sertifika iptali hata yönetimi | Repo | Mock | remove-user iptal başarısızsa hiçbir şey silmez |
| Dosya izinleri | Repo | Mock | `umask 077`; kullanıcı dizini `700`, anahtar/ovpn/zip/sha256 `600` |
| Peer silme | Repo | Mock | Python regex, boş `[Peer]` bırakmaz |
| İstemci süreç yönetimi | Repo | Linux: gerçek süreçlerle test; Windows: test edilmedi | Yalnızca kendi stunnel/openvpn süreçleri sonlandırılır |
| Paket / EXE checksum | Repo | Test edilmedi (workflow çalıştırılmadı) | SHA256; yalnızca bütünlük, gizlilik değil |
| Kill switch | Repo (sınırlı) | **Test edilmedi** | Aşağıya bakın |
| IPv6 kapatma | Repo (sunucu, sysctl) | **Test edilmedi** | Bu bir istemci IPv6 sızıntı **garantisi değildir**; aşağıya bakın |
| Brute-force koruması (Fail2Ban) | Repo dışı | — | Referans ortamda elle kuruldu |
| SSH hardening | Repo dışı | — | Referans ortamda elle (key-only) |
| DNS-over-TLS | Repo dışı | — | Referans ortamda elle (systemd-resolved) |

## Kill switch kapsamı

Kill switch, `add-user.sh`'in ürettiği istemci `wg0.conf` içindeki `PostUp`/`PreDown` iptables kurallarıyla sağlanır (`wg show %i fwmark` ile işaretlenmemiş, tünel dışı giden trafiği reddeder).

| Durum | Kill switch |
|---|---|
| Linux + `wg-quick` + WireGuard modu | Var (yalnızca **IPv4**; `ip6tables` kuralı yok) — **gerçek ortamda test edilmedi** |
| Windows (WireGuard) | Yok — `PostUp` betikleri varsayılan olarak çalışmaz, iptables yok |
| OpenVPN/Stunnel modu (Linux ve Windows) | Yok |
| Tünel yokken (bağlantı kopması dışında) | Kural yalnızca arayüz ayakta iken yüklüdür; tünel hiç kurulmadıysa koruma yok |
| `nftables` kullanan sistemler | `iptables` ön yüzünün nft arka ucuna bağlı olduğu varsayılır; doğrulanmadı |

## IPv6 notu

- İstemci `AllowedIPs = 0.0.0.0/0, ::/0` kullanır; IPv6 trafiği tünele yönlendirilir. Sunucu tarafında IPv6 çıkışı yapılandırılmadığı için bu trafik büyük olasılıkla düşer, ancak bu **doğrulanmamıştır**.
- Sunucuda `net.ipv6.conf.all.disable_ipv6=1` tüm sistem için IPv6'yı kapatır; bu istemci sızıntısını önlemez.
- OpenVPN/Stunnel modunda `client.ovpn` IPv6 için ek yönlendirme veya engelleme içermez; sızıntı durumu bilinmiyor.

## Bulgular (yapay zekâ destekli kod incelemesi özeti)

Buradaki tablo repoyla ilgili açık/kapalı durumu özetler.

| # | Konu | Önem | Durum |
|---|---|---|---|
| 1 | İstemci `pkill -f`/`taskkill /im` ile başkasının süreçlerini de sonlandırıyordu | Orta | Düzeltildi (Linux gerçek süreçlerle test; Windows test edilmedi) |
| 2 | `add-user.sh` kısmi hatada tutarsız durum bırakıyordu | Orta | Düzeltildi (mock test) |
| 3 | Kilit kapsamı dar, `remove-user.sh` kilitsizdi, kilit `/tmp`'de | Orta | Düzeltildi (mock test) |
| 4 | `remove-user.sh` iptal hatasını yutuyordu | Orta | Düzeltildi (mock test) |
| 5 | `ip_registry` bütünlüğü | Düşük | Kısmen: doğrulama eklendi; IP'ler yeniden kullanılmaz (bilinen sınır) |
| 6 | CRL'nin uygulanması `server.conf` içindeki `crl-verify`'a bağlı; repoda yok | Yüksek (yoksa) | **Açık**, belgelendi |
| 7 | Stunnel istemcisi sunucu sertifikasını doğrulamıyor | Düşük–Orta | **Açık**; iç OpenVPN TLS (`remote-cert-tls server`, gömülü CA) kimliği doğrular |
| 8 | Kill switch IPv4 + Linux + yalnızca WG | Orta | **Açık**, belgelendi; `ip6tables` eklenmedi (test edilemediği için) |
| 9 | İstemci özel anahtarları `nopass`, sunucuda `/root/clients` altında saklanıyor ve zip'e giriyor | Orta | **Açık**, belgelendi |
| 10 | CA anahtarı internete açık sunucuda | Orta | **Açık** (şifreli; offline CA roadmap'te) |
| 11 | Linux istemci `/etc/wireguard/wg0.conf` üzerine yazıyor | Orta | **Açık** |
| 12 | Windows GUI yönetici olarak çalışır; yürütülebilir dosyalar PATH ve Program Files araması ile bulunur | Düşük | **Açık** |
| 13 | Her ekleme/silme `wg-quick` yeniden başlatır, oturumlar kesilir | Düşük | **Açık** (`wg syncconf` önerilir) |
| 14 | GitHub Actions: geniş izin / sabitlenmemiş bağımlılık | Düşük | İzin ve pip bağımlılıkları düzeltildi; action'lar SHA ile sabitlenmedi (**açık**) |
| 15 | Boş `except:` blokları | Düşük | Düzeltildi |
| 16 | OpenVPN modunda DNS/yönlendirme `server.conf`'a bağlı, repoda yok | Orta | **Doğrulanamadı** |
| 17 | İstemci genel IP'yi `ifconfig.me` ile sorgular (üçüncü taraf) | Bilgi | Belgelendi |
| 18 | Repoda gizli anahtar, sertifika veya gerçek yapılandırma | — | Tarama: bulunamadı |
| 19 | `create-package.sh` kilitsizdi; add/remove ile yarışabilir, silinmiş kullanıcı için paket üretebilirdi | Orta | Düzeltildi (mock test) |
| 20 | `remove-user.sh` `/root/packages/` altındaki paket ve zip'leri (özel anahtar içerir) bırakıyordu | Orta | Düzeltildi (mock test); kullanıcıya iletilmiş kopyalar geri alınamaz |
| 21 | `add-user.sh` SIGTERM'de geri alma yapmıyordu (testle bulundu) | Düşük | Düzeltildi (mock test); SIGKILL kapsanmaz |
| 22 | Sertifika öncesi doğrulamalar (registry/IP) sertifika üretildikten sonra yapılıyordu | Düşük | Düzeltildi: artık sertifikadan önce (mock test) |
| 23 | Linux kurulumunda `pip --break-system-packages` | Düşük | Düzeltildi: venv; `pip install` sanal ortamda denendi, GUI çalışması test edilmedi |

## `add-user.sh` geri alma sınırları

Geri alınan: `wg0.conf`'a eklenen peer (ve servis yeniden başlatma), `/etc/wireguard/<kullanıcı>_*.key`, `/root/clients/<kullanıcı>`.

Geri **alınmayan**:
- **OpenVPN sertifikası:** Üretildikten sonraki bir hatada otomatik iptal edilmez; geçerli kalır. Betik elle çalıştırılacak `easyrsa revoke` komutunu yazdırır. (Registry/IP doğrulamaları artık sertifikadan **önce** yapıldığı için en sık hata nedenleri sertifika üretmeden durur; geriye `systemctl restart` gibi sonraki adım hataları kalır.)
- **`ip_registry` sayacı:** Peer eklendikten sonra yazılır ve geri sarılmaz; o noktadan sonraki hata bir IP numarasını harcar. IP'ler zaten yeniden kullanılmaz.
- **`SIGKILL` / elektrik kesintisi:** Trap çalışmaz, yarım kalan durum elle temizlenmelidir. `SIGTERM`/`SIGINT`/`SIGHUP`'ta geri alma çalışır ve o an çalışan alt komut bitene kadar beklenir.
- Geri alma sırasındaki `wg-quick` yeniden başlatma hatası sessizce geçilir.

## Eşzamanlılık

`add-user.sh`, `remove-user.sh` ve `create-package.sh` aynı kilidi (`/etc/wireguard/.bekre-vpn.lock`) tüm işlem boyunca tutar; bu yüzden aynı anda yalnızca biri çalışır. `create-package.sh` kullanıcı yoksa `add-user.sh`'ı çağırır ve kilidi bundan **sonra** alır (aksi hâlde kilitlenme olurdu). Kilit yalnızca bu üç betik arasında geçerlidir: `list-users.sh` kilit almaz (salt okunur), elle yapılan `wg0.conf` düzenlemeleri veya Easy-RSA'nın doğrudan çalıştırılması korunmaz. Kilit tutan betiklerin çocuk süreçleri (easyrsa, systemctl) kilit dosya tanıtıcısını miras alır. Test: mock (`tests/`); gerçek ortamda test edilmedi.

## Bilinen Riskler / Roadmap

### CA Private Key Sunucuda
- **Risk:** CA key internete açık sunucuda → sunucu ele geçirilirse tüm sertifikalar tehlikede.
- **Çözüm (planlı):** Offline CA; CSR transferi.

### İmzasız EXE Dağıtımı
- **Risk:** Windows imzasız EXE için "tanınmayan yayıncı" uyarısı gösterir.
- **Azaltma:** SHA256 yayımlanır; kullanıcı kendi derlemesini yapabilir.
- **Çözüm (planlı):** Code signing.

### Kullanıcı Paketinde ve Sunucuda Özel Anahtarlar
- **Risk:** `create-package.sh` çıktısı kullanıcının WireGuard ve OpenVPN özel anahtarlarını içerir. Sunucu da bu anahtarların kopyasını `/root/clients/` altında tutar; sunucu ele geçirilirse tüm kullanıcılar etkilenir. İstemci sertifikaları parolasızdır (`nopass`).
- **Azaltma:** Paketi güvenli kanaldan iletin, iletimden sonra sunucudaki zip'i silin. `remove-user.sh` kullanıcıyı silerken sunucudaki paket dizinini, zip'i ve sha256'yı da siler; kullanıcıya iletilmiş kopyalar geri alınamaz (OpenVPN için CRL, WireGuard için peer silme erişimi keser). Easy-RSA `pki/` altında anahtar/sertifika kopyaları tutabilir (sürüme göre değişir, doğrulanmadı). Dosya silme güvenli silme değildir.
- **Çözüm (planlı):** İstemcide anahtar üretimi / CSR, sunucuda özel anahtar saklamama.

### Sertifika İptalinin Etkisi
- **Risk:** `server.conf` içinde `crl-verify` yoksa iptal edilen sertifika kabul edilmeye devam eder; ayrıca CRL'nin süresi dolarsa OpenVPN tüm bağlantıları reddedebilir.
- **Çözüm:** `crl-verify /etc/openvpn/easy-rsa/pki/crl.pem` ekleyin; iptal sonrası eski `client.ovpn` ile bağlanmanın reddedildiğini test edin (TESTING.md #8).

### Linux İstemcisi Mevcut WireGuard Yapılandırmasının Üzerine Yazar
- **Risk:** İstemci `/etc/wireguard/wg0.conf` dosyasını `pkexec cp` ile değiştirir; kullanıcının aynı adlı kendi yapılandırması varsa kaybolur.
- **Azaltma:** Çalıştırmadan önce yedekleyin.

## Port Durumu

| Port | Protokol | Servis |
|---|---|---|
| 443/UDP | WireGuard | Hızlı mod |
| 443/TCP | Stunnel → OpenVPN | Engel atlatma modu |
| 1194/TCP | OpenVPN | Yalnızca `127.0.0.1` (dışarıya kapalı olmalı) |
| 22/TCP | SSH | Sunucu yönetimi (key-only) |

Port durumu dışarıdan doğrulanmamıştır (TESTING.md #6).
