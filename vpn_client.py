import os
import subprocess
import threading
import time
import shutil
import platform
import sys
import glob
import customtkinter as ctk

# --- TEMA ---
ctk.set_appearance_mode("dark")
ctk.set_default_color_theme("blue")


def find_executable(name):
    found = shutil.which(name)
    if found:
        return found
    if platform.system() != "Windows":
        return name
    search_paths = {
        "openvpn": [
            r"C:\Program Files\OpenVPN\bin\openvpn.exe",
            r"C:\Program Files (x86)\OpenVPN\bin\openvpn.exe",
        ],
        "stunnel": [
            r"C:\Program Files (x86)\stunnel\bin\stunnel.exe",
            r"C:\Program Files\stunnel\bin\stunnel.exe",
        ],
        "wireguard": [
            r"C:\Program Files\WireGuard\wireguard.exe",
            r"C:\Program Files (x86)\WireGuard\wireguard.exe",
        ],
        "curl": [
            r"C:\Windows\System32\curl.exe",
        ],
    }
    if name in search_paths:
        for path in search_paths[name]:
            if os.path.isfile(path):
                return path
    for base in [r"C:\Program Files", r"C:\Program Files (x86)"]:
        pattern = os.path.join(base, "**", name + ".exe")
        results = glob.glob(pattern, recursive=True)
        if results:
            return results[0]
    return name


class App(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("BekreVPN Client")
        self.geometry("420x680")
        self.resizable(False, False)

        self.connected = False
        self.connection_type = None
        self.ovpn_process = None
        self.stunnel_process = None
        self.monitoring = False
        self.speed_monitoring = False

        if getattr(sys, 'frozen', False):
            self.base_path = os.path.dirname(sys.executable)
        else:
            self.base_path = os.path.dirname(os.path.abspath(__file__))
        self.config_path = os.path.join(self.base_path, "configs")

        self.has_wg = os.path.exists(os.path.join(self.config_path, "wg0.conf"))
        self.has_ovpn = os.path.exists(os.path.join(self.config_path, "client.ovpn"))
        self.has_stunnel = os.path.exists(os.path.join(self.config_path, "stunnel.conf"))

        self.is_linux = platform.system() == "Linux"
        self.is_windows = platform.system() == "Windows"

        self.openvpn_exe = find_executable("openvpn")
        self.stunnel_exe = find_executable("stunnel")
        self.wireguard_exe = find_executable("wireguard")
        self.curl_exe = find_executable("curl")

        self._build_ui()
        self._check_status()
        self.protocol("WM_DELETE_WINDOW", self._on_close)

    def _build_ui(self):
        self.main_frame = ctk.CTkFrame(self, corner_radius=15, fg_color="#1a1a1a")
        self.main_frame.pack(padx=15, pady=15, fill="both", expand=True)

        # Baslik
        ctk.CTkLabel(
            self.main_frame, text="BEKRE  VPN",
            font=ctk.CTkFont(size=28, weight="bold")
        ).pack(pady=(20, 2))

        ctk.CTkLabel(
            self.main_frame, text="SECURE CONNECTION ESTABLISHED",
            font=ctk.CTkFont(size=9), text_color="#555555"
        ).pack(pady=(0, 15))

        # Durum paneli
        self.status_box = ctk.CTkFrame(self.main_frame, corner_radius=10, fg_color="#262626", height=55)
        self.status_box.pack(padx=20, fill="x")
        self.status_box.pack_propagate(False)

        self.status_dot = ctk.CTkLabel(
            self.status_box, text="■", text_color="#ff3b30",
            font=ctk.CTkFont(size=14)
        )
        self.status_dot.place(relx=0.08, rely=0.5, anchor="center")

        self.status_label = ctk.CTkLabel(
            self.status_box, text="OFFLINE",
            font=ctk.CTkFont(size=14, weight="bold")
        )
        self.status_label.place(relx=0.55, rely=0.5, anchor="center")

        # IP
        self.ip_label = ctk.CTkLabel(
            self.main_frame, text="IP: [ UNKNOWN ]",
            font=ctk.CTkFont(size=11, family="Consolas"), text_color="#666666"
        )
        self.ip_label.pack(pady=(8, 2))

        # Hiz gostergesi
        self.speed_frame = ctk.CTkFrame(self.main_frame, corner_radius=8, fg_color="#262626", height=32)
        self.speed_frame.pack(padx=20, fill="x", pady=(4, 10))
        self.speed_frame.pack_propagate(False)

        self.speed_label = ctk.CTkLabel(
            self.speed_frame, text="↓ 0.0 KB/s   ↑ 0.0 KB/s",
            font=ctk.CTkFont(size=10, family="Consolas"), text_color="#555555"
        )
        self.speed_label.place(relx=0.5, rely=0.5, anchor="center")

        # Butonlar
        self.wg_button = ctk.CTkButton(
            self.main_frame, text="[WG]  HIZLI BAGLAN",
            fg_color="#2a4d2a", hover_color="#3a6d3a",
            height=48, font=ctk.CTkFont(size=13, weight="bold"),
            command=self._connect_wg_click,
            state="normal" if self.has_wg else "disabled"
        )
        self.wg_button.pack(padx=25, pady=(5, 8), fill="x")

        self.ovpn_button = ctk.CTkButton(
            self.main_frame, text="[OVPN]  GIZLI BAGLAN",
            fg_color="#2a2a4d", hover_color="#3a3a6d",
            height=48, font=ctk.CTkFont(size=13, weight="bold"),
            command=self._connect_ovpn_click,
            state="normal" if (self.has_ovpn and self.has_stunnel) else "disabled"
        )
        self.ovpn_button.pack(padx=25, pady=(0, 8), fill="x")

        self.disconnect_button = ctk.CTkButton(
            self.main_frame, text="BAGLANTIYI KES",
            fg_color="#4d2a2a", hover_color="#6d3a3a",
            height=42, font=ctk.CTkFont(size=12, weight="bold"),
            command=self._disconnect_click, state="disabled"
        )
        self.disconnect_button.pack(padx=25, pady=(0, 10), fill="x")

        # Log
        ctk.CTkLabel(
            self.main_frame, text="> SYSTEM_LOGS",
            font=ctk.CTkFont(size=10, weight="bold"), text_color="#444444"
        ).pack(padx=22, anchor="w")

        self.log_box = ctk.CTkTextbox(
            self.main_frame, corner_radius=10, fg_color="#0d0d0d",
            text_color="#34c759", font=ctk.CTkFont(family="Consolas", size=10),
            state="disabled"
        )
        self.log_box.pack(padx=20, pady=(3, 15), fill="both", expand=True)

        self.log("SYS: BekreVPN Client v1.2")
        self.log("SYS: OS=" + platform.system())

        if not self.has_wg and not self.has_ovpn:
            self.log("ERR: Config dosyalari bulunamadi!")
            self.log("PATH: " + self.config_path)

    # ─── Log & Status ───
    def log(self, msg):
        self.log_box.configure(state="normal")
        ts = time.strftime("%H:%M:%S")
        self.log_box.insert("end", "[" + ts + "] " + msg + "\n")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    def _set_status(self, connected, conn_type=None):
        self.connected = connected
        self.connection_type = conn_type if connected else None

        if connected:
            mode = "WIREGUARD" if conn_type == "wg" else "OPENVPN (STEALTH)"
            self.status_label.configure(text="ONLINE - " + mode)
            self.status_dot.configure(text_color="#34c759")
            self.disconnect_button.configure(state="normal")
            self.wg_button.configure(state="disabled")
            self.ovpn_button.configure(state="disabled")
            self.speed_monitoring = True
            threading.Thread(target=self._speed_monitor, daemon=True).start()
        else:
            self.status_label.configure(text="OFFLINE")
            self.status_dot.configure(text_color="#ff3b30")
            self.ip_label.configure(text="IP: [ UNKNOWN ]")
            self.speed_label.configure(text="↓ 0.0 KB/s   ↑ 0.0 KB/s", text_color="#555555")
            self.disconnect_button.configure(state="disabled")
            self.speed_monitoring = False
            if self.has_wg:
                self.wg_button.configure(state="normal")
            if self.has_ovpn and self.has_stunnel:
                self.ovpn_button.configure(state="normal")

    # ─── Hiz Izleme ───
    def _speed_monitor(self):
        iface = "wg0" if self.connection_type == "wg" else "tun0"

        if self.is_linux:
            rx_path = "/sys/class/net/" + iface + "/statistics/rx_bytes"
            tx_path = "/sys/class/net/" + iface + "/statistics/tx_bytes"
            if not os.path.exists(rx_path):
                return
            prev_rx = int(open(rx_path).read().strip())
            prev_tx = int(open(tx_path).read().strip())
            while self.speed_monitoring and self.connected:
                time.sleep(1)
                try:
                    cur_rx = int(open(rx_path).read().strip())
                    cur_tx = int(open(tx_path).read().strip())
                    dl = cur_rx - prev_rx
                    ul = cur_tx - prev_tx
                    prev_rx, prev_tx = cur_rx, cur_tx
                    dl_s, ul_s = self._fmt_speed(dl), self._fmt_speed(ul)
                    c = "#34c759" if dl > 1024 else "#555555"
                    self.after(0, lambda d=dl_s, u=ul_s, clr=c: self.speed_label.configure(
                        text="↓ " + d + "   ↑ " + u, text_color=clr))
                except:
                    break

        elif self.is_windows:
            prev_rx, prev_tx = self._win_bytes()
            while self.speed_monitoring and self.connected:
                time.sleep(1)
                try:
                    cur_rx, cur_tx = self._win_bytes()
                    dl = max(0, cur_rx - prev_rx)
                    ul = max(0, cur_tx - prev_tx)
                    prev_rx, prev_tx = cur_rx, cur_tx
                    dl_s, ul_s = self._fmt_speed(dl), self._fmt_speed(ul)
                    c = "#34c759" if dl > 1024 else "#555555"
                    self.after(0, lambda d=dl_s, u=ul_s, clr=c: self.speed_label.configure(
                        text="↓ " + d + "   ↑ " + u, text_color=clr))
                except:
                    break

    def _win_bytes(self):
        try:
            r = subprocess.run(["netstat", "-e"], capture_output=True, text=True,
                               timeout=5, creationflags=subprocess.CREATE_NO_WINDOW if self.is_windows else 0)
            for line in r.stdout.split("\n"):
                if "Bytes" in line or "Bayt" in line:
                    parts = line.split()
                    return int(parts[1]), int(parts[2])
        except:
            pass
        return 0, 0

    def _fmt_speed(self, b):
        if b < 1024:
            return str(b) + " B/s"
        elif b < 1048576:
            return "{:.1f} KB/s".format(b / 1024)
        else:
            return "{:.2f} MB/s".format(b / 1048576)

    # ─── IP & Status Check ───
    def _check_ip(self):
        threading.Thread(target=self._check_ip_t, daemon=True).start()

    def _check_ip_t(self):
        try:
            curl = self.curl_exe if self.is_windows else "curl"
            r = subprocess.run([curl, "-s", "--max-time", "10", "ifconfig.me"],
                               capture_output=True, text=True, timeout=15)
            if r.returncode == 0:
                ip = r.stdout.strip()
                self.after(0, lambda: self.ip_label.configure(text="IP: [ " + ip + " ]"))
                self.after(0, lambda: self.log("NET: IP=" + ip))
        except:
            self.after(0, lambda: self.ip_label.configure(text="IP: [ ERROR ]"))

    def _check_status(self):
        threading.Thread(target=self._check_status_t, daemon=True).start()

    def _check_status_t(self):
        if self.is_linux:
            r = self._cmd(["ip", "link", "show", "wg0"])
            if r and r.returncode == 0:
                self.after(0, lambda: self._set_status(True, "wg"))
                self.after(0, self._check_ip)
                return
            r = self._cmd(["ip", "link", "show", "tun0"])
            if r and r.returncode == 0:
                self.after(0, lambda: self._set_status(True, "ovpn"))
                self.after(0, self._check_ip)

    # ─── Komut ───
    def _cmd(self, cmd):
        try:
            kw = {"capture_output": True, "text": True, "timeout": 15}
            if self.is_windows:
                kw["creationflags"] = subprocess.CREATE_NO_WINDOW
            return subprocess.run(cmd, **kw)
        except:
            return None

    def _sudo(self, cmd):
        return ["pkexec"] + cmd if self.is_linux else cmd

    # ─── stunnel fix ───
    def _fix_stunnel(self, path):
        if self.is_windows:
            try:
                with open(path, "r") as f:
                    content = f.read()
                if "pid" in content.lower():
                    lines = content.split("\n")
                    fixed = []
                    for line in lines:
                        if line.strip().lower().startswith("pid"):
                            fixed.append("; " + line)
                        else:
                            fixed.append(line)
                    with open(path, "w") as f:
                        f.write("\n".join(fixed))
            except:
                pass

    # ─── WireGuard ───
    def _connect_wg_click(self):
        if self.connected:
            return
        self.wg_button.configure(state="disabled")
        self.ovpn_button.configure(state="disabled")
        self.status_label.configure(text="CONNECTING...")
        self.status_dot.configure(text_color="#ffcc00")
        self.log("INIT: WireGuard protocol...")
        threading.Thread(target=self._connect_wg, daemon=True).start()

    def _connect_wg(self):
        wg_conf = os.path.join(self.config_path, "wg0.conf")

        if self.is_linux:
            self._cmd(self._sudo(["wg-quick", "down", "wg0"]))
            time.sleep(1)
            self._cmd(self._sudo(["cp", wg_conf, "/etc/wireguard/wg0.conf"]))
            r = self._cmd(self._sudo(["wg-quick", "up", "wg0"]))
            if r and r.returncode == 0:
                self.after(0, lambda: self.log("SUCCESS: WireGuard active"))
                self.after(0, lambda: self._set_status(True, "wg"))
                self.after(1000, self._check_ip)
            else:
                e = r.stderr[:60] if r and r.stderr else "Unknown"
                self.after(0, lambda x=e: self.log("ERR: " + x))
                self.after(0, lambda: self._set_status(False))

        elif self.is_windows:
            r = self._cmd([self.wireguard_exe, "/installtunnelservice", wg_conf])
            if r and r.returncode == 0:
                self.after(0, lambda: self.log("SUCCESS: WireGuard active"))
                self.after(0, lambda: self._set_status(True, "wg"))
                self.after(2000, self._check_ip)
            else:
                self.after(0, lambda: self.log("ERR: Admin olarak calistirin"))
                self.after(0, lambda: self._set_status(False))

    # ─── OpenVPN + Stunnel ───
    def _connect_ovpn_click(self):
        if self.connected:
            return
        self.wg_button.configure(state="disabled")
        self.ovpn_button.configure(state="disabled")
        self.status_label.configure(text="CONNECTING...")
        self.status_dot.configure(text_color="#ffcc00")
        self.log("INIT: OpenVPN Stealth mode...")
        threading.Thread(target=self._connect_ovpn, daemon=True).start()

    def _connect_ovpn(self):
        ovpn_conf = os.path.join(self.config_path, "client.ovpn")
        stunnel_conf = os.path.join(self.config_path, "stunnel.conf")

        if self.is_linux:
            self._cmd(self._sudo(["pkill", "-f", "stunnel"]))
            self._cmd(self._sudo(["pkill", "-f", "openvpn"]))
        elif self.is_windows:
            self._cmd(["taskkill", "/f", "/im", "stunnel.exe"])
            self._cmd(["taskkill", "/f", "/im", "openvpn.exe"])
        time.sleep(1)

        self._fix_stunnel(stunnel_conf)

        # Stunnel
        self.after(0, lambda: self.log("EXEC: Starting stunnel..."))
        stunnel = self.stunnel_exe if self.is_windows else "stunnel"
        try:
            kw = {"stdout": subprocess.PIPE, "stderr": subprocess.PIPE}
            if self.is_windows:
                kw["creationflags"] = subprocess.CREATE_NO_WINDOW
                cmd = [stunnel, stunnel_conf]
            else:
                cmd = self._sudo([stunnel, stunnel_conf])
            self.stunnel_process = subprocess.Popen(cmd, **kw)
        except FileNotFoundError:
            self.after(0, lambda: self.log("ERR: stunnel not found!"))
            self.after(0, lambda: self._set_status(False))
            return
        time.sleep(2)

        # OpenVPN
        self.after(0, lambda: self.log("EXEC: Starting OpenVPN..."))
        openvpn = self.openvpn_exe if self.is_windows else "openvpn"
        try:
            kw = {"stdout": subprocess.PIPE, "stderr": subprocess.STDOUT}
            if self.is_windows:
                kw["creationflags"] = subprocess.CREATE_NO_WINDOW
                cmd = [openvpn, "--config", ovpn_conf]
            else:
                cmd = self._sudo([openvpn, "--config", ovpn_conf])
            self.ovpn_process = subprocess.Popen(cmd, **kw)
        except FileNotFoundError:
            self.after(0, lambda: self.log("ERR: openvpn not found!"))
            self.after(0, lambda: self._set_status(False))
            return

        self.monitoring = True
        threading.Thread(target=self._monitor_ovpn, daemon=True).start()

    def _monitor_ovpn(self):
        if not self.ovpn_process:
            return
        for line in iter(self.ovpn_process.stdout.readline, b''):
            if not self.monitoring:
                break
            d = line.decode("utf-8", errors="ignore").strip()
            if "Initialization Sequence Completed" in d:
                self.after(0, lambda: self.log("SUCCESS: OpenVPN active"))
                self.after(0, lambda: self._set_status(True, "ovpn"))
                self.after(2000, self._check_ip)
            elif "Connection reset" in d:
                self.after(0, lambda: self.log("WARN: Retrying..."))
            elif "AUTH_FAILED" in d:
                self.after(0, lambda: self.log("ERR: Auth failed"))
                self.after(0, lambda: self._set_status(False))
                break

    # ─── Disconnect ───
    def _disconnect_click(self):
        self.disconnect_button.configure(state="disabled")
        self.status_label.configure(text="DISCONNECTING...")
        self.status_dot.configure(text_color="#ffcc00")
        self.log("EXEC: Terminating connection...")
        threading.Thread(target=self._disconnect, daemon=True).start()

    def _disconnect(self):
        self.monitoring = False
        self.speed_monitoring = False

        if self.connection_type == "wg":
            if self.is_linux:
                self._cmd(self._sudo(["wg-quick", "down", "wg0"]))
            elif self.is_windows:
                self._cmd([self.wireguard_exe, "/uninstalltunnelservice", "wg0"])
        elif self.connection_type == "ovpn":
            if self.is_linux:
                self._cmd(self._sudo(["pkill", "-f", "openvpn"]))
                self._cmd(self._sudo(["pkill", "-f", "stunnel"]))
            elif self.is_windows:
                self._cmd(["taskkill", "/f", "/im", "openvpn.exe"])
                self._cmd(["taskkill", "/f", "/im", "stunnel.exe"])
            for p in [self.ovpn_process, self.stunnel_process]:
                if p:
                    try:
                        p.terminate()
                    except:
                        pass

        time.sleep(1)
        self.after(0, lambda: self.log("SUCCESS: Connection terminated"))
        self.after(0, lambda: self._set_status(False))

    def _on_close(self):
        if self.connected:
            self._disconnect()
        self.destroy()


if __name__ == "__main__":
    app = App()
    app.mainloop()
