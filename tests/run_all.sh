#!/bin/bash
# Tum testleri calistirir. Gercek VPN testi DEGILDIR (bkz. tests/README.md).
cd "$(dirname "$0")" || exit 1
rc=0
for t in test_static.sh test_add_user.sh test_remove_user.sh test_create_package.sh; do
    bash "$t" || rc=1
    echo
done
echo "== client proc_pattern (python, gercek pkill + sahte surecler) =="
python3 -I test_client_process_pattern.py 2>&1 | tail -8 || rc=1
[ "${PIPESTATUS[0]}" -eq 0 ] || rc=1
echo
[ "$rc" -eq 0 ] && echo "TUM TESTLER GECTI (betik mantigi; gercek VPN dogrulamasi degil)" || echo "BAZI TESTLER BASARISIZ"
exit "$rc"
