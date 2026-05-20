# Güvenlik Notları

## Mevcut Güvenlik Önlemleri

| Önlem | Durum | Detay |
|---|---|---|
| CA key şifreleme | ✅ | AES-256, her easyrsa işleminde passphrase gerekir |
| IPv6 leak önleme | ✅ | sysctl ile IPv6 kapatılıyor |
| Race condition fix | ✅ | flock + /etc/wireguard/ip_registry |
| Peer silme güvenliği | ✅ | Python regex, boş [Peer] bloğu bırakmaz |
| Kill switch | ✅ | İstemci wg0.conf'ta iptables PostUp/PreDown |
| WireGuard port | ✅ | UDP 443 (eski: 51820) |
| Paket checksum | ✅ | SHA256, her create-package sonrası |

## Bilinen Riskler / Roadmap

### CA Private Key Sunucuda
- **Risk:** CA key internet-facing sunucuda → sunucu ele geçirilirse tüm sertifikalar tehlike altında
- **Çözüm:** Offline CA — CA sadece air-gapped bir makinede, CSR transfer ile

### Brute-Force Koruması Yok
- **Risk:** SSH ve OpenVPN portlarına sözlük saldırısı
- **Durum:** Fail2Ban aktif ve çalışıyor ✅

### İmzasız EXE Dağıtımı
- **Risk:** Windows Smart App Control BekreVPN.exe'yi bloke eder
- **Çözüm:** Code signing sertifikası veya kullanıcıya Smart App Control kapatma talimatı

## Port Durumu

| Port | Protokol | Servis |
|---|---|---|
| 443/UDP | WireGuard | Hızlı mod |
| 443/TCP | Stunnel → OpenVPN | Engel atlatma modu |
| 22/TCP | SSH | Sunucu yönetimi |
