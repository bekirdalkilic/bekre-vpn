# FRA VPN Client

Kisisel VPN istemcisi. Frankfurt sunucusuna WireGuard (hizli) veya OpenVPN+Stunnel (engel atlatma) ile baglanir.

## Gereksinimler

### Linux (Fedora/Ubuntu)
- wireguard-tools
- openvpn
- stunnel
- curl
- python3, python3-tkinter

Kurulum:
```
# Fedora
sudo dnf install wireguard-tools openvpn stunnel curl python3-tkinter -y
pip install customtkinter --break-system-packages

# Ubuntu/Debian
sudo apt install wireguard-tools openvpn stunnel4 curl python3-tk -y
pip install customtkinter --break-system-packages
```

### Windows
- WireGuard: https://wireguard.com/install
- OpenVPN: https://openvpn.net/community-downloads
- Stunnel: https://stunnel.org/downloads.html
- curl (Windows 10+ icinde var)

## Kullanim

1. `configs/` klasorune kendi config dosyalarini koy:
   - `wg0.conf` (WireGuard)
   - `client.ovpn` (OpenVPN)
   - `stunnel.conf` (Stunnel)

2. Uygulamayi calistir:
   - Linux: `python3 vpn_client.py`
   - Windows: `FRA_VPN.exe` cift tikla (admin olarak)

3. Mod sec:
   - **HIZLI BAGLAN**: WireGuard, UDP, dusuk gecikme
   - **ENGEL ATLATMA**: OpenVPN+Stunnel, TCP 443, HTTPS gibi gorunur

## Config dosyalari nereden gelir?
Sunucu yoneticisinden alinir. Her kullanici icin ayri config olusturulur.
