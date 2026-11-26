# tests/

Yeniden çalıştırılabilir **betik mantığı** testleri.

```bash
bash tests/run_all.sh          # hepsi
bash tests/test_add_user.sh    # tek tek
```

Gereksinimler: `bash`, `flock`, `python3`, `zip`/`unzip`, `sha256sum`; ShellCheck ve flake8 varsa statik testlerde kullanılır. Root gerekmez; testler `/etc` veya `/root`'a yazmaz (geçici `/tmp/bekre-test.*` dizinleri).

## Ne test eder

| Dosya | Kapsam |
|---|---|
| `test_add_user.sh` | T1–T11: normal ekleme, izinler, çift kullanıcı, hata sonrası geri alma ve **bilinen sınırları**, registry/IP doğrulamaları, eşzamanlılık, geçersiz ad, SIGTERM |
| `test_remove_user.sh` | R1–R7: iptal hatası, normal silme (paket kalıntıları dahil), CRL hatası, eşzamanlı ekle+sil |
| `test_create_package.sh` | P1–P4: paket içeriği/izinleri, `kur.sh`, kilit davranışı |
| `test_client_process_pattern.py` | İstemcinin yalnızca kendi stunnel/openvpn süreçlerini hedeflemesi (gerçek `pkill -f`, sahte süreçler) |
| `test_static.sh` | `bash -n`, ShellCheck, flake8, YAML, gizli bilgi taraması, belge–kaynak tutarlılığı |

## Ne test ETMEZ — önemli

Bu testler **gerçek bir VPN bağlantısını test etmez.** `wg`, `systemctl` ve `easyrsa` sahte (mock) komutlarla değiştirilir; betiklerin yolları (`/etc/wireguard`, `/etc/openvpn`, `/root/`) test için geçici dizine yönlendirilmiş **kopyaları** çalıştırılır (başka bir değişiklik yapılmaz). Dolayısıyla şunları **doğrulamaz**: WireGuard/OpenVPN/Stunnel bağlantısı, Easy-RSA'nın gerçek davranışı, CRL'nin uygulanması, DNS/IPv6 sızıntısı, kill switch, systemd, Windows istemcisi, GUI. Bunlar için bkz. [docs/TESTING.md](../docs/TESTING.md) (Not Tested listesi ve gerçek ortam test prosedürleri).
