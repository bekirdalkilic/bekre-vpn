#!/bin/bash
# remove-user.sh mock testleri (R1-R8). Gercek VPN/PKI testi DEGILDIR; bkz. lib.sh ve docs/TESTING.md
source "$(dirname "$0")/lib.sh"
need flock python3 zip sha256sum base64 || { echo "gerekli arac yok"; exit 2; }
echo "== remove-user.sh (mock) =="

setup_two() { new_sandbox; add_user alice; add_user bob; make_pkg alice; }

echo "R1 sertifika iptali basarisiz -> hicbir sey silinmez"
setup_two
n="$(peers)"
FAKE_EASYRSA_FAIL=revoke remove_user alice
check "R1 hata kodu" test "$LAST_RC" -ne 0
check "R1 istemci dizini duruyor" test -d "$T/root/clients/alice"
check "R1 peer sayisi ayni" test "$(peers)" -eq "$n"
check "R1 WG anahtari duruyor" test -f "$T/etc/wireguard/alice_private.key"
check "R1 paket zip duruyor" test -f "$T/root/packages/alice.zip"
check "R1 sertifika hala gecerli (V)" test "$(cert_state alice)" = V

echo "R2 normal silme (paketler dahil)"
setup_two
n="$(peers)"; r0="$(restarts)"
check "R2 oncesi: paket dizini, zip ve sha256 var" test -d "$T/root/packages/alice" -a -f "$T/root/packages/alice.zip" -a -f "$T/root/packages/alice.zip.sha256"
remove_user alice
check "R2 cikis kodu 0" test "$LAST_RC" -eq 0
check "R2 peer -1" test "$(peers)" -eq $((n-1))
check_not "R2 istemci dizini silindi" test -e "$T/root/clients/alice"
check_not "R2 WG ozel anahtari silindi" test -e "$T/etc/wireguard/alice_private.key"
check "R2 sertifika iptal (R)" test "$(cert_state alice)" = R
check_not "R2 paket dizini silindi" test -e "$T/root/packages/alice"
check_not "R2 paket zip silindi" test -e "$T/root/packages/alice.zip"
check_not "R2 paket sha256 silindi" test -e "$T/root/packages/alice.zip.sha256"
check "R2 baska kullanici (bob) etkilenmedi" test -d "$T/root/clients/bob" -a -f "$T/etc/wireguard/bob_private.key"
check "R2 wg-quick yeniden baslatildi" test "$(restarts)" -gt "$r0"
check "R2 SINIR: sertifika/anahtar kopyalari Easy-RSA pki/ altinda kalir" test -f "$T/etc/openvpn/easy-rsa/pki/private/alice.key"

echo "R3 sertifika zaten iptal edilmis"
setup_two
( cd "$T/etc/openvpn/easy-rsa" && ./easyrsa revoke alice )
remove_user alice
check "R3 cikis kodu 0" test "$LAST_RC" -eq 0
check "R3 mesaj" grep -q "zaten iptal" "$T/last.out"
check_not "R3 istemci dizini silindi" test -e "$T/root/clients/alice"

echo "R4 CRL uretimi basarisiz -> hata, hicbir sey silinmez"
setup_two
FAKE_EASYRSA_FAIL=crl remove_user alice
check "R4 hata kodu" test "$LAST_RC" -ne 0
check "R4 istemci dizini duruyor" test -d "$T/root/clients/alice"
check "R4 paket zip duruyor" test -f "$T/root/packages/alice.zip"

echo "R5 olmayan kullanici (+ yetim paket uyarisi)"
new_sandbox
remove_user ghost
check "R5 reddedildi" test "$LAST_RC" -ne 0
mkdir -p "$T/root/packages/ghost"; echo secret > "$T/root/packages/ghost.zip"
remove_user ghost
check "R5 yetim paket icin uyari" grep -q "paket kalintilari" "$T/last.out"
check "R5 yetim paket OTOMATIK silinmedi (bilinen davranis)" test -f "$T/root/packages/ghost.zip"

echo "R6 eszamanli: 3 kullanici varken 1 silme + 3 ekleme"
new_sandbox; for u in a1 a2 a3; do add_user $u; done
( FAKE_EASYRSA_DELAY=0.2 PATH="$T/bin:$PATH" bash "$T/bin/remove-user.sh" a2 >"$T/o0" 2>&1; echo $? > "$T/rc0" ) &
for i in 1 2 3; do ( FAKE_EASYRSA_DELAY=0.2 PATH="$T/bin:$PATH" bash "$T/bin/add-user.sh" n$i >"$T/o$i" 2>&1; echo $? > "$T/rc$i" ) & done
wait
check "R6 hepsi basarili" test "$(cat "$T"/rc? | sort -u | tr -d '\n')" = 0
check "R6 5 peer (3-1+3)" test "$(peers)" -eq 5
check "R6 IP'ler benzersiz" test "$(ips | sort -u | wc -l)" -eq "$(ips | wc -l)"
check_not "R6 silinen kullanicinin peer'i yok" grep -q "# a2" "$T/etc/wireguard/wg0.conf"

echo "R7 gecersiz ad"
new_sandbox
remove_user '../x'
check "R7 reddedildi" test "$LAST_RC" -ne 0
run bash "$T/bin/remove-user.sh"
check "R7 bos ad reddedildi" test "$LAST_RC" -ne 0

summary remove-user
