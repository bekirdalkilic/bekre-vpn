import customtkinter as ctk
import subprocess
import threading
import os
import sys
import platform
import time


class VPNClient(ctk.CTk):
    def __init__(self):
        super().__init__()

        self.title("VPN Client")
        self.geometry("420x520")
        self.resizable(False, False)
        ctk.set_appearance_mode("dark")
        ctk.set_default_color_theme("blue")

        self.connected = False
        self.connection_type = None
        self.ovpn_process = None
        self.stunnel_process = None
        self.monitoring = False

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

        self.build_ui()
        self.check_status()
        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def build_ui(self):
        main = ctk.CTkFrame(self, fg_color="transparent")
        main.pack(fill="both", expand=True, padx=25, pady=20)

        ctk.CTkLabel(main, text="VPN Client", font=("", 28, "bold")).pack(pady=(0, 5))
        ctk.CTkLabel(main, text="Frankfurt, Almanya", font=("", 14), text_color="gray").pack(pady=(0, 20))

        self.status_frame = ctk.CTkFrame(main, corner_radius=12, height=80)
        self.status_frame.pack(fill="x", pady=(0, 20))
        self.status_frame.pack_propagate(False)

        status_inner = ctk.CTkFrame(self.status_frame, fg_color="transparent")
        status_inner.pack(expand=True)

        self.status_dot = ctk.CTkLabel(status_inner, text="●", font=("", 20), text_color="#ef4444")
        self.status_dot.pack(side="left", padx=(0, 8))

        self.status_label = ctk.CTkLabel(status_inner, text="Bagli Degil", font=("", 16, "bold"))
        self.status_label.pack(side="left")

        self.ip_label = ctk.CTkLabel(main, text="IP: ---", font=("", 13), text_color="gray")
        self.ip_label.pack(pady=(0, 20))

        self.wg_btn = ctk.CTkButton(
            main, text="Hizli Baglan  (WireGuard)", height=48,
            font=("", 15, "bold"), fg_color="#3b82f6", hover_color="#2563eb",
            command=self.toggle_wireguard,
            state="normal" if self.has_wg else "disabled"
        )
        self.wg_btn.pack(fill="x", pady=(0, 10))

        self.ovpn_btn = ctk.CTkButton(
            main, text="Engel Atlatma  (OpenVPN)", height=48,
            font=("", 15, "bold"), fg_color="#8b5cf6", hover_color="#7c3aed",
            command=self.toggle_openvpn,
            state="normal" if (self.has_ovpn and self.has_stunnel) else "disabled"
        )
        self.ovpn_btn.pack(fill="x", pady=(0, 10))

        self.disconnect_btn = ctk.CTkButton(
            main, text="Baglantiyi Kes", height=42,
            font=("", 14), fg_color="#ef4444", hover_color="#dc2626",
            command=self.disconnect, state="disabled"
        )
        self.disconnect_btn.pack(fill="x", pady=(0, 15))

        ctk.CTkLabel(main, text="Log", font=("", 12), text_color="gray", anchor="w").pack(fill="x")
        self.log_box = ctk.CTkTextbox(main, height=100, font=("Consolas", 11), state="disabled")
        self.log_box.pack(fill="both", expand=True, pady=(3, 0))

        if not self.has_wg and not self.has_ovpn:
            self.log("Config dosyalari bulunamadi!")
            self.log("Beklenen konum: " + self.config_path)
            self.log("   wg0.conf, client.ovpn, stunnel.conf")

    def log(self, msg):
        self.log_box.configure(state="normal")
        timestamp = time.strftime("%H:%M:%S")
        self.log_box.insert("end", "[" + timestamp + "] " + msg + "\n")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    def set_status(self, connected, conn_type=None):
        self.connected = connected
        self.connection_type = conn_type if connected else None

        if connected:
            self.status_dot.configure(text_color="#22c55e")
            mode = "WireGuard" if conn_type == "wg" else "OpenVPN+Stunnel"
            self.status_label.configure(text="Bagli - " + mode)
            self.disconnect_btn.configure(state="normal")
            self.wg_btn.configure(state="disabled")
            self.ovpn_btn.configure(state="disabled")
        else:
            self.status_dot.configure(text_color="#ef4444")
            self.status_label.configure(text="Bagli Degil")
            self.ip_label.configure(text="IP: ---")
            self.disconnect_btn.configure(state="disabled")
            if self.has_wg:
                self.wg_btn.configure(state="normal")
            if self.has_ovpn and self.has_stunnel:
                self.ovpn_btn.configure(state="normal")

    def run_cmd(self, cmd):
        try:
            if self.is_windows:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=15,
                                        creationflags=subprocess.CREATE_NO_WINDOW)
            else:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            return result
        except subprocess.TimeoutExpired:
            return None
        except Exception as e:
            self.log("Hata: " + str(e))
            return None

    def get_sudo_cmd(self, cmd_list):
        if self.is_linux:
            return ["pkexec"] + cmd_list
        else:
            return cmd_list

    def check_ip(self):
        threading.Thread(target=self._check_ip_thread, daemon=True).start()

    def _check_ip_thread(self):
        try:
            result = subprocess.run(["curl", "-s", "--max-time", "10", "ifconfig.me"],
                                     capture_output=True, text=True, timeout=15)
            if result.returncode == 0:
                ip = result.stdout.strip()
                self.after(0, lambda: self.ip_label.configure(text="IP: " + ip))
        except:
            self.after(0, lambda: self.ip_label.configure(text="IP: kontrol edilemedi"))

    def check_status(self):
        threading.Thread(target=self._check_status_thread, daemon=True).start()

    def _check_status_thread(self):
        if self.is_linux:
            result = self.run_cmd(["ip", "link", "show", "wg0"])
            if result and result.returncode == 0:
                self.after(0, lambda: self.set_status(True, "wg"))
                self.after(0, self.check_ip)
                return

            result = self.run_cmd(["ip", "link", "show", "tun0"])
            if result and result.returncode == 0:
                self.after(0, lambda: self.set_status(True, "ovpn"))
                self.after(0, self.check_ip)
                return

    def toggle_wireguard(self):
        if self.connected:
            return
        self.wg_btn.configure(state="disabled")
        self.ovpn_btn.configure(state="disabled")
        self.log("WireGuard baglaniyor...")
        threading.Thread(target=self._connect_wireguard, daemon=True).start()

    def _connect_wireguard(self):
        wg_conf = os.path.join(self.config_path, "wg0.conf")

        if self.is_linux:
            self.run_cmd(self.get_sudo_cmd(["wg-quick", "down", "wg0"]))
            time.sleep(1)
            self.run_cmd(self.get_sudo_cmd(["cp", wg_conf, "/etc/wireguard/wg0.conf"]))
            result = self.run_cmd(self.get_sudo_cmd(["wg-quick", "up", "wg0"]))

            if result and result.returncode == 0:
                self.after(0, lambda: self.log("WireGuard baglandi!"))
                self.after(0, lambda: self.set_status(True, "wg"))
                self.after(1000, self.check_ip)
            else:
                err = result.stderr if result else "Bilinmeyen hata"
                self.after(0, lambda e=err: self.log("WireGuard hatasi: " + e))
                self.after(0, lambda: self.set_status(False))

        elif self.is_windows:
            result = self.run_cmd(["wireguard", "/installtunnelservice", wg_conf])
            if result and result.returncode == 0:
                self.after(0, lambda: self.log("WireGuard baglandi!"))
                self.after(0, lambda: self.set_status(True, "wg"))
                self.after(2000, self.check_ip)
            else:
                self.after(0, lambda: self.log("WireGuard baglanamadi. Admin olarak calistirin."))
                self.after(0, lambda: self.set_status(False))

    def toggle_openvpn(self):
        if self.connected:
            return
        self.wg_btn.configure(state="disabled")
        self.ovpn_btn.configure(state="disabled")
        self.log("OpenVPN + Stunnel baglaniyor...")
        threading.Thread(target=self._connect_openvpn, daemon=True).start()

    def _connect_openvpn(self):
        ovpn_conf = os.path.join(self.config_path, "client.ovpn")
        stunnel_conf = os.path.join(self.config_path, "stunnel.conf")

        if self.is_linux:
            self.run_cmd(self.get_sudo_cmd(["pkill", "-f", "stunnel"]))
            self.run_cmd(self.get_sudo_cmd(["pkill", "-f", "openvpn"]))
        elif self.is_windows:
            self.run_cmd(["taskkill", "/f", "/im", "stunnel.exe"])
            self.run_cmd(["taskkill", "/f", "/im", "openvpn.exe"])

        time.sleep(1)

        self.after(0, lambda: self.log("Stunnel baslatiliyor..."))
        try:
            if self.is_linux:
                self.stunnel_process = subprocess.Popen(
                    self.get_sudo_cmd(["stunnel", stunnel_conf]),
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE
                )
            else:
                self.stunnel_process = subprocess.Popen(
                    ["stunnel", stunnel_conf],
                    stdout=subprocess.PIPE, stderr=subprocess.PIPE,
                    creationflags=subprocess.CREATE_NO_WINDOW
                )
        except FileNotFoundError:
            self.after(0, lambda: self.log("stunnel bulunamadi! Kurulu mu?"))
            self.after(0, lambda: self.set_status(False))
            return

        time.sleep(2)

        self.after(0, lambda: self.log("OpenVPN baslatiliyor..."))
        try:
            if self.is_linux:
                self.ovpn_process = subprocess.Popen(
                    self.get_sudo_cmd(["openvpn", "--config", ovpn_conf]),
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT
                )
            else:
                self.ovpn_process = subprocess.Popen(
                    ["openvpn", "--config", ovpn_conf],
                    stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                    creationflags=subprocess.CREATE_NO_WINDOW
                )
        except FileNotFoundError:
            self.after(0, lambda: self.log("openvpn bulunamadi! Kurulu mu?"))
            self.after(0, lambda: self.set_status(False))
            return

        self.monitoring = True
        threading.Thread(target=self._monitor_openvpn, daemon=True).start()

    def _monitor_openvpn(self):
        if not self.ovpn_process:
            return

        for line in iter(self.ovpn_process.stdout.readline, b''):
            if not self.monitoring:
                break
            decoded = line.decode("utf-8", errors="ignore").strip()
            if "Initialization Sequence Completed" in decoded:
                self.after(0, lambda: self.log("OpenVPN baglandi!"))
                self.after(0, lambda: self.set_status(True, "ovpn"))
                self.after(2000, self.check_ip)
            elif "Connection reset" in decoded:
                self.after(0, lambda: self.log("Baglanti sifirlandi, tekrar deneniyor..."))
            elif "AUTH_FAILED" in decoded:
                self.after(0, lambda: self.log("Kimlik dogrulama basarisiz!"))
                self.after(0, lambda: self.set_status(False))
                break

    def disconnect(self):
        self.disconnect_btn.configure(state="disabled")
        self.log("Baglanti kesiliyor...")
        threading.Thread(target=self._disconnect, daemon=True).start()

    def _disconnect(self):
        self.monitoring = False

        if self.connection_type == "wg":
            if self.is_linux:
                self.run_cmd(self.get_sudo_cmd(["wg-quick", "down", "wg0"]))
            elif self.is_windows:
                self.run_cmd(["wireguard", "/uninstalltunnelservice", "wg0"])

        elif self.connection_type == "ovpn":
            if self.is_linux:
                self.run_cmd(self.get_sudo_cmd(["pkill", "-f", "openvpn"]))
                self.run_cmd(self.get_sudo_cmd(["pkill", "-f", "stunnel"]))
            elif self.is_windows:
                self.run_cmd(["taskkill", "/f", "/im", "openvpn.exe"])
                self.run_cmd(["taskkill", "/f", "/im", "stunnel.exe"])

            if self.ovpn_process:
                try:
                    self.ovpn_process.terminate()
                except:
                    pass
            if self.stunnel_process:
                try:
                    self.stunnel_process.terminate()
                except:
                    pass

        time.sleep(1)
        self.after(0, lambda: self.log("Baglanti kesildi."))
        self.after(0, lambda: self.set_status(False))

    def on_close(self):
        if self.connected:
            self._disconnect()
        self.destroy()


if __name__ == "__main__":
    app = VPNClient()
    app.mainloop()
