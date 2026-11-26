#!/bin/bash
# add-user.sh mock testleri (T1-T11). Gercek VPN/PKI testi DEGILDIR; bkz. lib.sh ve docs/TESTING.md
source "$(dirname "$0")/lib.sh"
need flock python3 base64 || { echo "gerekli arac yok"; exit 2; }
echo "== add-user.sh (mock) =="

new_sandbox
echo "T1 normal ekleme"
add_user alice
check "T1 cikis kodu 0" test "$LAST_RC" -eq 0
check "T1 ilk IP 10.0.0.4 ve registry=4" grep -qx 4 "$T/etc/wireguard/ip_registry"
check "T1 peer eklendi" test "$(peers)" -eq 1
check "T1 kullanici dizini 700" test "$(mode_of "$T/root/clients/alice")" = 700
for f in wg0.conf client.ovpn stunnel.conf; do check "T1 $f 600" test "$(mode_of "$T/root/clients/alice/$f")" = 600; done
check "T1 WG ozel anahtar dosyasi 600" test "$(mode_of "$T/etc/wireguard/alice_private.key")" = 600
check "T1 client.ovpn gomulu anahtar iceriyor" grep -q "FAKEKEY-alice" "$T/root/clients/alice/client.ovpn"
check "T1 wg-quick yeniden baslatildi" test "$(restarts)" -ge 1

echo "T2 ayni kullanici tekrar"
before="$(cat "$T/etc/wireguard/wg0.conf")"
add_user alice
check "T2 reddedildi" test "$LAST_RC" -ne 0
check "T2 wg0.conf degismedi" test "$(cat "$T/etc/wireguard/wg0.conf")" = "$before"

echo "T3 easyrsa basarisiz -> hicbir durum degismez"
before="$(cat "$T/etc/wireguard/wg0.conf")"; reg="$(cat "$T/etc/wireguard/ip_registry")"
FAKE_EASYRSA_FAIL=build add_user bob
check "T3 hata kodu" test "$LAST_RC" -ne 0
check "T3 wg0.conf ayni" test "$(cat "$T/etc/wireguard/wg0.conf")" = "$before"
check "T3 registry ayni" test "$(cat "$T/etc/wireguard/ip_registry")" = "$reg"
check_not "T3 kullanici dizini yok" test -e "$T/root/clients/bob"
check_not "T3 WG anahtar dosyasi yok" test -e "$T/etc/wireguard/bob_private.key"

echo "T4 sertifika SONRASI hata (systemctl restart basarisiz) -> geri alma ve BILINEN SINIRLAR"
peers_before="$(peers)"; reg="$(cat "$T/etc/wireguard/ip_registry")"
FAKE_SYSTEMCTL_FAIL=restart add_user carol
check "T4 hata kodu" test "$LAST_RC" -ne 0
check "T4 peer geri alindi" test "$(peers)" -eq "$peers_before"
check_not "T4 WG anahtarlari silindi" test -e "$T/etc/wireguard/carol_private.key"
check_not "T4 kullanici dizini silindi" test -e "$T/root/clients/carol"
check "T4 SINIR: sertifika otomatik IPTAL EDILMEDI (hala V)" test "$(cert_state carol)" = V
check "T4 SINIR: ip_registry geri alinmadi (IP harcandi)" test "$(cat "$T/etc/wireguard/ip_registry")" -eq $((reg+1))
check "T4 iptal ipucu yazdirildi" grep -q "easyrsa revoke carol" "$T/last.out"

echo "T5 registry tutarsiz (wg0.conf'ta IP zaten var) -> sertifika URETILMEDEN reddedilir"
new_sandbox
printf '\n[Peer]\n# eski\nPublicKey = x\nAllowedIPs = 10.0.0.4/32\n' >> "$T/etc/wireguard/wg0.conf"
echo 3 > "$T/etc/wireguard/ip_registry"
add_user dave
check "T5 reddedildi" test "$LAST_RC" -ne 0
check "T5 sertifika uretilmedi" test -z "$(cert_state dave)"

echo "T6 bozuk registry"
new_sandbox; echo "abc" > "$T/etc/wireguard/ip_registry"
add_user erin
check "T6 reddedildi" test "$LAST_RC" -ne 0
check "T6 sertifika uretilmedi" test -z "$(cert_state erin)"

echo "T7 havuz siniri (254)"
new_sandbox; echo 254 > "$T/etc/wireguard/ip_registry"
add_user frank
check "T7 reddedildi" test "$LAST_RC" -ne 0
check "T7 sertifika uretilmedi" test -z "$(cert_state frank)"

echo "T8 eszamanli 5 ekleme"
new_sandbox
for i in 1 2 3 4 5; do ( FAKE_EASYRSA_DELAY=0.2 PATH="$T/bin:$PATH" bash "$T/bin/add-user.sh" "u$i" >"$T/out$i" 2>&1; echo $? > "$T/rc$i" ) & done
wait
rcs="$(cat "$T"/rc? | sort -u | tr -d '\n')"
check "T8 hepsi basarili" test "$rcs" = 0
check "T8 5 peer" test "$(peers)" -eq 5
check "T8 5 benzersiz IP" test "$(ips | sort -u | wc -l)" -eq 5
check "T8 registry=8" grep -qx 8 "$T/etc/wireguard/ip_registry"

echo "T9 gecersiz kullanici adlari"
new_sandbox
for bad_name in '../evil' 'a b' 'x;y' '$(id)'; do
    add_user "$bad_name"
    check "T9 '$bad_name' reddedildi" test "$LAST_RC" -ne 0
done
run bash "$T/bin/add-user.sh"
check "T9 bos ad reddedildi" test "$LAST_RC" -ne 0
check_not "T9 dizin disina yazilmadi" test -e "$T/root/evil"

echo "T10 SERVER_IP placeholder doldurulmamis"
new_sandbox; patch_script add-user.sh false
add_user gina
check "T10 reddedildi" test "$LAST_RC" -ne 0
check "T10 mesaj" grep -q "SERVER_IP" "$T/last.out"
check "T10 mesajdaki satir numarasi dogru (7. satir SERVER_IP)" bash -c "sed -n 7p '$SCRIPTS/add-user.sh' | grep -q '^SERVER_IP='"

echo "T11 SIGTERM ile kesilme (mock; SIGKILL/elektrik kesintisi KAPSANMAZ)"
new_sandbox
( FAKE_SYSTEMCTL_DELAY=2 PATH="$T/bin:$PATH" bash "$T/bin/add-user.sh" hank >"$T/out" 2>&1 ) &
sleep 1
pkill -TERM -f "$T/bin/add-user.sh hank"
wait
check "T11 SIGTERM sonrasi peer geri alindi" test "$(peers)" -eq 0
check_not "T11 SIGTERM sonrasi WG anahtar dosyasi kalmadi" test -e "$T/etc/wireguard/hank_private.key"
check_not "T11 SIGTERM sonrasi kullanici dizini kalmadi" test -e "$T/root/clients/hank"
check "T11 SINIR: sertifika yine iptal edilmedi" test "$(cert_state hank)" = V

summary add-user
