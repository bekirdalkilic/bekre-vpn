#!/bin/bash
# create-package.sh mock testleri (P1-P4): paket icerigi, izinler ve add/remove ile kilit uyumu.
source "$(dirname "$0")/lib.sh"
need flock python3 zip unzip sha256sum base64 || { echo "gerekli arac yok"; exit 2; }
echo "== create-package.sh (mock) =="

echo "P1 mevcut kullanici icin paket"
new_sandbox; add_user alice
make_pkg alice
check "P1 cikis kodu 0" test "$LAST_RC" -eq 0
check "P1 zip 600" test "$(mode_of "$T/root/packages/alice.zip")" = 600
check "P1 sha256 600" test "$(mode_of "$T/root/packages/alice.zip.sha256")" = 600
check "P1 sha256 dogrulanir" bash -c "cd '$T/root/packages' && sha256sum -c alice.zip.sha256"
listing="$(unzip -Z1 "$T/root/packages/alice.zip")"
for f in configs/wg0.conf configs/client.ovpn configs/stunnel.conf kur.sh; do
    check "P1 zip icinde $f" grep -qx "alice/$f" <<<"$listing"
done
unzip -p "$T/root/packages/alice.zip" alice/kur.sh > "$T/kur.sh"
check_not "P1 kur.sh --break-system-packages KULLANMIYOR (yorum satirlari haric)" bash -c "grep -v '^#' '$T/kur.sh' | grep -q -- --break-system-packages"
check "P1 kur.sh sanal ortam (venv) kullaniyor" grep -q "python3 -m venv" "$T/kur.sh"
check "P1 kur.sh bash sozdizimi" bash -n "$T/kur.sh"
check "P1 UYARI: zip OZEL ANAHTAR iceriyor (bilinen risk)" bash -c "unzip -p '$T/root/packages/alice.zip' alice/configs/wg0.conf | grep -q '^PrivateKey'"

echo "P2 kullanici yoksa add-user.sh cagrilir (kilitlenme olmamali)"
new_sandbox
timeout 20 env PATH="$T/bin:$PATH" bash "$T/bin/create-package.sh" newbie >"$T/last.out" 2>&1; LAST_RC=$?
check "P2 cikis kodu 0 (zaman asimi/kilitlenme yok)" test "$LAST_RC" -eq 0
check "P2 kullanici olusturuldu" test -d "$T/root/clients/newbie"
check "P2 zip var" test -f "$T/root/packages/newbie.zip"

echo "P3 baska bir islem kilidi tutarken create-package bekler"
new_sandbox; add_user alice
( flock -x 9; sleep 2 ) 9>"$T/etc/wireguard/.bekre-vpn.lock" &
sleep 0.3
t0=$(date +%s.%N)
make_pkg alice
t1=$(date +%s.%N)
wait
check "P3 cikis kodu 0" test "$LAST_RC" -eq 0
check "P3 en az ~1.5 sn bekledi" python3 -c "import sys; sys.exit(0 if $t1-$t0 >= 1.5 else 1)"

echo "P4 kilit beklenirken kullanici silindi -> paket uretilmez"
new_sandbox; add_user alice
( flock -x 9; sleep 1.5; rm -rf "$T/root/clients/alice" ) 9>"$T/etc/wireguard/.bekre-vpn.lock" &
sleep 0.3
make_pkg alice
wait
check "P4 hata kodu" test "$LAST_RC" -ne 0
check_not "P4 zip uretilmedi" test -e "$T/root/packages/alice.zip"

summary create-package
