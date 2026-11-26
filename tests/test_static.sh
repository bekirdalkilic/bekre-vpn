#!/bin/bash
# Statik kontroller: sozdizimi, ShellCheck, Python, YAML, gizli bilgi taramasi, belge-kaynak tutarliligi.
# Bunlar kod/belge kontrolleridir; VPN'in calistigini KANITLAMAZ.
source "$(dirname "$0")/lib.sh"
cd "$REPO" || exit 1
echo "== statik kontroller =="

for f in server/scripts/*.sh tests/*.sh; do check "bash -n $f" bash -n "$f"; done
if command -v shellcheck >/dev/null; then
    check "ShellCheck (warning seviyesi) server/scripts" shellcheck -S warning server/scripts/*.sh
    check "ShellCheck (warning seviyesi) tests" shellcheck -S warning -x tests/*.sh
else skip "ShellCheck kurulu degil"; fi
check "py_compile client/vpn_client.py" python3 -c "import py_compile,sys; py_compile.compile('client/vpn_client.py', cfile='/tmp/_vc.pyc', doraise=True)"
if python3 -c "import flake8" 2>/dev/null || command -v flake8 >/dev/null; then
    check "flake8 client/ tests/" flake8 --max-line-length 160 client tests
else skip "flake8 kurulu degil"; fi
if python3 -c "import yaml" 2>/dev/null; then
    check "YAML gecerli (workflow)" python3 -c "import yaml; yaml.safe_load(open('.github/workflows/build-release.yml'))"
else skip "PyYAML kurulu degil"; fi

# Gizli bilgi taramasi
check_not "Ozel anahtar/token deseni yok" bash -c "grep -rIE 'BEGIN [A-Z ]*PRIVATE KEY|ghp_[A-Za-z0-9]{20,}|AKIA[0-9A-Z]{16}' --exclude-dir=.git --exclude=test_static.sh ."
check_not "Anahtar/sertifika dosyasi yok" bash -c "find . -name '*.key' -o -name '*.pem' -o -name '*.crt' -o -name '*.p12' | grep -q ."
check "SERVER_IP placeholder'i dolu degil" grep -q '^SERVER_IP="<SUNUCU_IP>"' server/scripts/add-user.sh

# Bagimlilik tutarliligi: requirements.txt <-> create-package.sh (kur.sh)
ver="$(grep -E '^customtkinter==' requirements.txt | cut -d= -f3)"
check "customtkinter surumu requirements.txt ve kur.sh'ta ayni ($ver)" grep -q "customtkinter==$ver" server/scripts/create-package.sh
check_not "Betiklerde --break-system-packages calistirilmiyor" bash -c "grep -rn -- '--break-system-packages' server client .github requirements*.txt | grep -v ':#' | grep -vE '^\S+:[0-9]+:\s*(#|echo|rem)' | grep -q ."

# Belge-kaynak tutarliligi
check "add-user.sh 7. satir SERVER_IP (hata mesaji '7. satirdaki' diyor)" bash -c "sed -n 7p server/scripts/add-user.sh | grep -q '^SERVER_IP='"
check "add-user.sh mesaji '7. satirdaki' diyor" grep -q "7. satirdaki" server/scripts/add-user.sh
for f in README.md CHANGELOG.md NOTICE.md docs/ARCHITECTURE.md docs/SECURITY.md docs/TESTING.md tests/README.md requirements.txt requirements-build.txt; do
    check "Dosya var: $f" test -f "$f"
done
# Markdown goreli baglantilar mevcut dosyalara gidiyor mu
broken=0
while IFS= read -r md; do
    d="$(dirname "$md")"
    while IFS= read -r link; do
        link="${link%%#*}"; [ -z "$link" ] && continue
        case "$link" in http*|mailto:*|../../releases) continue ;; esac
        [ -e "$d/$link" ] || { echo "    kirik baglanti: $md -> $link"; broken=1; }
    done < <(grep -oE '\]\([^)]+\)' "$md" | sed 's/^](//; s/)$//')
done < <(find . -name '*.md' -not -path './.git/*')
check "Markdown baglantilari kirik degil" test "$broken" -eq 0
# README dizin agacindaki dosyalar var mi
for f in server/scripts/add-user.sh server/scripts/remove-user.sh server/scripts/list-users.sh server/scripts/create-package.sh \
         server/configs/wg0.conf.template server/configs/stunnel-server.conf.template client/vpn_client.py client/build_windows.bat \
         .github/workflows/build-release.yml; do
    check "README'de anilan dosya var: $f" bash -c "grep -q '$(basename "$f")' README.md && test -f '$f'"
done
# Dogrulanmamis ozelliklerin 'dogrulandi' diye isaretlenmedigi: TESTING.md gercek test tablosu bos olmali (kayit eklenene kadar)
check "TESTING.md bolum B kanitsiz 'Gecti' satiri icermiyor" bash -c "! sed -n '/^## B\./,/^## C\./p' docs/TESTING.md | grep -E '^\| [0-9]+ \|' | grep -qiE 'gecti|geçti|pass|ok'"

summary static
