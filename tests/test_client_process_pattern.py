#!/usr/bin/env python3
"""client/vpn_client.py icindeki proc_pattern() icin test (Linux).

Gercek `pkill -f` ve sahte surecler (bash `exec -a` ile komut satiri taklidi) kullanilir.
Bu bir VPN testi DEGILDIR; yalnizca "yalnizca kendi stunnel/openvpn surecini hedefler" desenini dogrular.
customtkinter gerekmez: fonksiyon kaynak koddan AST ile alinir. Windows (taskkill) yolu test EDILMEZ.
"""
import ast
import os
import re
import shutil
import subprocess
import sys
import tempfile
import time
import unittest

REPO = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(REPO, "client", "vpn_client.py")


def load_proc_pattern():
    with open(SRC, encoding="utf-8") as f:
        tree = ast.parse(f.read())
    for node in tree.body:
        if isinstance(node, ast.FunctionDef) and node.name == "proc_pattern":
            ns = {"re": re}
            exec(compile(ast.Module([node], []), SRC, "exec"), ns)
            return ns["proc_pattern"]
    raise AssertionError("proc_pattern bulunamadi")


def spawn(cmdline):
    """argv[0]=cmdline olan, 30 sn uyuyan sahte surec."""
    p = subprocess.Popen(["bash", "-c", 'exec -a "$0" sleep 30', cmdline])
    path = "/proc/%d/cmdline" % p.pid
    for _ in range(100):  # exec -a tamamlanana kadar bekle
        try:
            with open(path, "rb") as f:
                if f.read().startswith(cmdline.encode()):
                    break
        except OSError:
            pass
        time.sleep(0.02)
    return p


@unittest.skipUnless(sys.platform.startswith("linux") and shutil.which("pkill"), "Linux + pkill gerekli")
class ProcPatternTest(unittest.TestCase):
    def setUp(self):
        self.proc_pattern = load_proc_pattern()
        self.procs = []

    def tearDown(self):
        for p in self.procs:
            p.kill()
            p.wait()

    def sp(self, cmdline):
        p = spawn(cmdline)
        self.procs.append(p)
        return p

    def alive(self, p):
        return p.poll() is None

    def run_case(self, own_dir):
        own_st = os.path.join(own_dir, "configs", "stunnel.conf")
        own_ov = os.path.join(own_dir, "configs", "client.ovpn")
        mine = [self.sp("stunnel " + own_st), self.sp("openvpn --config " + own_ov)]
        others = [
            self.sp("stunnel /etc/stunnel/other.conf"),
            self.sp("openvpn --config /home/x/other.ovpn"),
            self.sp("vim stunnel-notes.txt"),
            # pkexec pkill -f <desen> komut satirinin kendisi desene uymamali:
            self.sp("pkexec pkill -f " + self.proc_pattern("stunnel", own_st)),
        ]
        subprocess.run(["pkill", "-f", self.proc_pattern("stunnel", own_st)])
        subprocess.run(["pkill", "-f", self.proc_pattern("openvpn", own_ov)])
        time.sleep(0.3)
        return mine, others

    def test_only_own_processes_are_killed(self):
        d = tempfile.mkdtemp(prefix="bekre-pat-")
        self.addCleanup(shutil.rmtree, d, True)
        mine, others = self.run_case(d)
        self.assertFalse(any(self.alive(p) for p in mine), "kendi surecleri olmeliydi")
        self.assertTrue(all(self.alive(p) for p in others), "baskasinin surecleri etkilendi")

    def test_path_with_space_and_special_chars(self):
        d = tempfile.mkdtemp(prefix="bekre pat (x)-")
        self.addCleanup(shutil.rmtree, d, True)
        mine, others = self.run_case(d)
        self.assertFalse(any(self.alive(p) for p in mine), "bosluk/ozel karakterli yolda kendi surecleri olmeliydi")
        self.assertTrue(all(self.alive(p) for p in others))


if __name__ == "__main__":
    unittest.main(verbosity=2)
