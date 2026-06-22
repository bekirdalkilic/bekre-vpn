# Güvenlik Notları

## Mevcut Güvenlik Önlemleri

| Önlem | Durum | Detay |
|---|---|---|
| CA key şifreleme | ✅ | AES-256, her easyrsa işleminde passphrase gerekir |
| IPv6 leak önleme | ✅ | sysctl ile IPv6 kapatılıyor |
| Race condition fix | ✅ | flock + /etc/wireguard/ip_registry |
| Peer silme güvenliği | ✅ | Python regex, boş [Peer] bloğu bırakmaz |
| Kill switch | ✅ | İstemci wg0.conf'ta iptables PostUp/PreDown |
| WireGuard port | ✅ | UDP 443 |
| Paket checksum | ✅ | SHA256, her create-package sonrası |
| Brute-force koruması | ✅ | Fail2Ban (referans ortamda aktif; repo bu kurulumu otomatikleştirmez) |
| DNS-over-TLS | ✅ | systemd-resolved üzerinden Cloudflare/Google DoT |
| SSH hardening | ✅ | Key-only auth, şifre girişi kapalı |

## Bilinen Riskler / Roadmap

### CA Private Key Sunucuda
- **Risk:** CA key internet-facing sunucuda → sunucu ele geçirilirse tüm sertifikalar tehlike altında
- **Çözüm:** Offline CA — CA sadece air-gapped bir makinede, CSR transfer ile (roadmap'te)

### İmzasız EXE Dağıtımı
- **Risk:** Windows imzasız EXE'ler için "tanınmayan yayıncı" uyarısı gösterir
- **Çözüm:** Code signing sertifikası, veya kullanıcının kaynak koddan kendi derlemesi

### Script Input Validasyonu
- **Risk:** `add-user.sh` / `remove-user.sh` kullanıcı adını doğrudan dosya yolunda kullanıyor, path traversal riski teorik olarak mevcut
- **Çözüm:** Kullanıcı adı için `^[a-zA-Z0-9_-]+$` regex kontrolü eklenmesi (roadmap'te)

## Port Durumu

| Port | Protokol | Servis |
|---|---|---|
| 443/UDP | WireGuard | Hızlı mod |
| 443/TCP | Stunnel → OpenVPN | Engel atlatma modu |
| 22/TCP | SSH | Sunucu yönetimi (key-only) |
