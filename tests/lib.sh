#!/bin/bash
# Test yardimcilari. Bu dosya dogrudan calistirilmaz; test_*.sh dosyalari "source" eder.
#
# KAPSAM: Bu testler BETIK MANTIGINI dogrular (siralama, geri alma, kilit, izinler).
# Gercek WireGuard / OpenVPN / Stunnel / Easy-RSA / systemd KULLANILMAZ; wg, systemctl ve easyrsa
# sahte (mock) komutlarla degistirilir. Gercek bir VPN baglantisi, sizinti veya kill switch
# testi DEGILDIR. Her test gecici bir dizinde calisir; /etc veya /root'a yazmaz, root gerekmez.

REPO="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SCRIPTS="$REPO/server/scripts"
PASS=0; FAIL=0; SKIP=0

ok()   { PASS=$((PASS+1)); echo "  PASS  $1"; }
bad()  { FAIL=$((FAIL+1)); echo "  FAIL  $1"; }
skip() { SKIP=$((SKIP+1)); echo "  SKIP  $1"; }

# check "aciklama" komut...   -> komut basariliysa PASS
check() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else bad "$d"; fi; }
# check_not "aciklama" komut... -> komut basarisizsa PASS
check_not() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then bad "$d"; else ok "$d"; fi; }

summary() {
    echo "  --- $1: $PASS passed, $FAIL failed, $SKIP skipped"
    [ "$FAIL" -eq 0 ]
}

need() { # need arac... ; eksikse 1 doner
    local c; for c in "$@"; do command -v "$c" >/dev/null 2>&1 || { echo "  (eksik arac: $c)"; return 1; }; done
}

# Yeni sandbox: $T altinda sahte /etc/wireguard, /etc/openvpn/easy-rsa, /root/* ve sahte komutlar
new_sandbox() {
    T="$(mktemp -d /tmp/bekre-test.XXXXXX)"
    mkdir -p "$T/etc/wireguard" "$T/etc/openvpn/easy-rsa/pki/issued" "$T/etc/openvpn/easy-rsa/pki/private" \
             "$T/root/clients" "$T/root/packages" "$T/root/scripts" "$T/root/installers" "$T/bin"
    cp "$REPO/server/configs/wg0.conf.template" "$T/etc/wireguard/wg0.conf"
    echo "SERVERPUBKEY=" > "$T/etc/wireguard/server_public.key"
    echo "FAKECA" > "$T/etc/openvpn/easy-rsa/pki/ca.crt"
    : > "$T/etc/openvpn/easy-rsa/pki/index.txt"
    : > "$T/systemctl.log"

    cat > "$T/etc/openvpn/easy-rsa/easyrsa" <<'EOS'
#!/bin/bash
# SAHTE easyrsa: gercek PKI islemi yapmaz, yalnizca dosya/dizin durumunu taklit eder.
cd "$(dirname "$0")" || exit 1
sleep "${FAKE_EASYRSA_DELAY:-0}"
case "$1" in
  build-client-full)
    [ "${FAKE_EASYRSA_FAIL:-}" = build ] && { echo "fake easyrsa: build failed" >&2; exit 1; }
    echo "FAKECERT-$2" > "pki/issued/$2.crt"
    echo "FAKEKEY-$2"  > "pki/private/$2.key"
    printf 'V\t300101000000Z\t\t01\tunknown\t/CN=%s\n' "$2" >> pki/index.txt ;;
  revoke)
    [ "${FAKE_EASYRSA_FAIL:-}" = revoke ] && { echo "fake easyrsa: revoke failed" >&2; exit 1; }
    sed -i "/\/CN=$2\$/s/^V/R/" pki/index.txt ;;
  gen-crl)
    [ "${FAKE_EASYRSA_FAIL:-}" = crl ] && { echo "fake easyrsa: gen-crl failed" >&2; exit 1; }
    echo crl > pki/crl.pem ;;
esac
exit 0
EOS
    cat > "$T/bin/wg" <<'EOS'
#!/bin/bash
# SAHTE wg
case "$1" in
  genkey) head -c 24 /dev/urandom | base64 | tr '+/' 'ab' ;;
  pubkey) read -r k; printf 'pub-%s\n' "$k" ;;
  *) exit 0 ;;
esac
EOS
    cat > "$T/bin/systemctl" <<'EOS'
#!/bin/bash
# SAHTE systemctl
echo "$*" >> "$(dirname "$0")/../systemctl.log"
if [ "$1" = restart ]; then
    sleep "${FAKE_SYSTEMCTL_DELAY:-0}"
    [ "${FAKE_SYSTEMCTL_FAIL:-}" = restart ] && exit 1
fi
exit 0
EOS
    chmod +x "$T/etc/openvpn/easy-rsa/easyrsa" "$T/bin/wg" "$T/bin/systemctl"

    # Betiklerin kopyalari: yalnizca yol on eki degistirilir (/etc, /root -> $T/...) ve test icin
    # SERVER_IP placeholder'i doldurulur. Betik mantigi ayni kalir.
    patch_script add-user.sh true
    patch_script remove-user.sh true
    patch_script create-package.sh true
    patch_script list-users.sh true
    cp "$T/bin/add-user.sh" "$T/root/scripts/add-user.sh"   # create-package.sh bunu cagirir
}

# patch_script ad fill_server_ip(true|false)
patch_script() {
    local name="$1" fill="$2" out="$T/bin/$1"
    sed -e "s#/etc/wireguard#$T/etc/wireguard#g" \
        -e "s#/etc/openvpn#$T/etc/openvpn#g" \
        -e "s#/root/#$T/root/#g" "$SCRIPTS/$name" > "$out"
    if [ "$fill" = true ]; then
        sed -i 's#^SERVER_IP="<SUNUCU_IP>"#SERVER_IP="203.0.113.10"#' "$out"
    fi
    chmod +x "$out"
}

# run komut... : cikti $T/last.out, cikis kodu LAST_RC
# shellcheck disable=SC2034  # LAST_RC test dosyalarinda kullanilir
run() { PATH="$T/bin:$PATH" "$@" >"$T/last.out" 2>&1; LAST_RC=$?; }

add_user()    { run bash "$T/bin/add-user.sh" "$1"; }
remove_user() { run bash "$T/bin/remove-user.sh" "$1"; }
make_pkg()    { run bash "$T/bin/create-package.sh" "$1"; }

peers()  { grep -c '^\[Peer\]' "$T/etc/wireguard/wg0.conf" || true; }
mode_of() { stat -c %a "$1"; }
cert_state() { awk -v u="/CN=$1" '$NF==u {print $1}' "$T/etc/openvpn/easy-rsa/pki/index.txt"; }
ips()    { grep -oE '^AllowedIPs = 10\.0\.0\.[0-9]+/32' "$T/etc/wireguard/wg0.conf" | sort; }
restarts() { grep -c '^restart' "$T/systemctl.log" || true; }
