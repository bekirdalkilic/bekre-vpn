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
        
        # Uygulama ayarları (Daha geniş ve taktiksel)
        self.title("BekreVPN Client")
        self.geometry("450x580")
        self.resizable(False, False)
        
        # Tamamen karanlık tema
        ctk.set_appearance_mode("dark")
        
        # Durum değişkenleri
        self.connected = False
        self.connection_type = None
        self.ovpn_process = None
        self.stunnel_process = None
        self.monitoring = False
        
        # Config dosyalarının yolu
        if getattr(sys, 'frozen', False):
            self.base_path = os.path.dirname(sys.executable)
        else:
            self.base_path = os.path.dirname(os.path.abspath(__file__))
            
        self.config_path = os.path.join(self.base_path, "configs")
        
        # Config kontrolü
        self.has_wg = os.path.exists(os.path.join(self.config_path, "wg0.conf"))
        self.has_ovpn = os.path.exists(os.path.join(self.config_path, "client.ovpn"))
        self.has_stunnel = os.path.exists(os.path.join(self.config_path, "stunnel.conf"))
        
        # OS kontrolü
        self.is_linux = platform.system() == "Linux"
        self.is_windows = platform.system() == "Windows"
        
        self.build_ui()
        self.check_status()
        
        self.protocol("WM_DELETE_WINDOW", self.on_close)

    def build_ui(self):
        # Ana çerçeve (Mat koyu gri arka plan)
        main = ctk.CTkFrame(self, fg_color="#121212", corner_radius=0)
        main.pack(fill="both", expand=True, padx=0, pady=0)
        
        inner_frame = ctk.CTkFrame(main, fg_color="transparent")
        inner_frame.pack(fill="both", expand=True, padx=30, pady=25)

        # Başlık
        ctk.CTkLabel(inner_frame, text="BEKRE VPN", font=("Consolas", 32, "bold"), text_color="#e5e5e5").pack(pady=(0, 2))
        ctk.CTkLabel(inner_frame, text="SECURE CONNECTION ESTABLISHED", font=("Consolas", 11), text_color="#556b2f").pack(pady=(0, 20))

        # Durum kartı (Daha minimal)
        self.status_frame = ctk.CTkFrame(inner_frame, fg_color="#1a1a1a", border_width=1, border_color="#333333", corner_radius=6, height=70)
        self.status_frame.pack(fill="x", pady=(0, 20))
        self.status_frame.pack_propagate(False)
        
        status_inner = ctk.CTkFrame(self.status_frame, fg_color="transparent")
        status_inner.pack(expand=True)
        
        self.status_dot = ctk.CTkLabel(status_inner, text="■", font=("Consolas", 18), text_color="#ef4444")
        self.status_dot.pack(side="left", padx=(0, 10))
        self.status_label = ctk.CTkLabel(status_inner, text="OFFLINE", font=("Consolas", 16, "bold"), text_color="#a3a3a3")
        self.status_label.pack(side="left")

        self.ip_label = ctk.CTkLabel(inner_frame, text="IP: [ UNKNOWN ]", font=("Consolas", 12), text_color="#737373")
        self.ip_label.pack(pady=(0, 20))

        # Butonlar (Low-vis, mat renkler, köşeli tasarım)
        self.wg_btn = ctk.CTkButton(
            inner_frame, text="[WG] HIZLI BAĞLAN", height=45, corner_radius=4,
            font=("Consolas", 14, "bold"), 
            fg_color="#3f4a3c", hover_color="#4b5747", border_width=1, border_color="#5c6e5a",
            command=self.toggle_wireguard,
            state="normal" if self.has_wg else "disabled"
        )
        self.wg_btn.pack(fill="x", pady=(0, 10))

        self.ovpn_btn = ctk.CTkButton(
            inner_frame, text="[OVPN] GİZLİ BAĞLAN", height=45, corner_radius=4,
            font=("Consolas", 14, "bold"), 
            fg_color="#2b2d30", hover_color="#36393d", border_width=1, border_color="#4a4d52",
            command=self.toggle_openvpn,
            state="normal" if (self.has_ovpn and self.has_stunnel) else "disabled"
        )
        self.ovpn_btn.pack(fill="x", pady=(0, 10))

        self.disconnect_btn = ctk.CTkButton(
            inner_frame, text="BAĞLANTIYI KES", height=40, corner_radius=4,
            font=("Consolas", 13, "bold"), 
            fg_color="#592020", hover_color="#732b2b", border_width=1, border_color="#8c3333",
            command=self.disconnect, state="disabled"
        )
        self.disconnect_btn.pack(fill="x", pady=(0, 20))

        # Log alanı (Hacker Terminal Stili)
        ctk.CTkLabel(inner_frame, text="> SYSTEM_LOGS", font=("Consolas", 11, "bold"), text_color="#737373", anchor="w").pack(fill="x")
        self.log_box = ctk.CTkTextbox(
            inner_frame, height=110, font=("Consolas", 11), 
            fg_color="#0a0a0a", text_color="#22c55e", border_width=1, border_color="#262626", corner_radius=4,
            state="disabled"
        )
        self.log_box.pack(fill="both", expand=True, pady=(3, 0))

        if not self.has_wg and not self.has_ovpn:
            self.log("ERR: Config dosyalari eksik!")
            self.log(f"DIR: {self.config_path}/")

    def log(self, msg):
        self.log_box.configure(state="normal")
        timestamp = time.strftime("%H:%M:%S")
        self.log_box.insert("end", f"[{timestamp}] {msg}\n")
        self.log_box.see("end")
        self.log_box.configure(state="disabled")

    def set_status(self, connected, conn_type=None):
        self.connected = connected
        self.connection_type = conn_type if connected else None
        
        if connected:
            self.status_dot.configure(text_color="#22c55e")
            mode = "WIREGUARD" if conn_type == "wg" else "OPENVPN (STEALTH)"
            self.status_label.configure(text=f"ONLINE - {mode}", text_color="#e5e5e5")
            self.disconnect_btn.configure(state="normal")
            self.wg_btn.configure(state="disabled")
            self.ovpn_btn.configure(state="disabled")
        else:
            self.status_dot.configure(text_color="#ef4444")
            self.status_label.configure(text="OFFLINE", text_color="#a3a3a3")
            self.ip_label.configure(text="IP: [ UNKNOWN ]")
            self.disconnect_btn.configure(state="disabled")
            if self.has_wg:
                self.wg_btn.configure(state="normal")
            if self.has_ovpn and self.has_stunnel:
                self.ovpn_btn.configure(state="normal")

    def run_cmd(self, cmd, check=False):
        try:
            if self.is_windows:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=15, creationflags=subprocess.CREATE_NO_WINDOW)
            else:
                result = subprocess.run(cmd, capture_output=True, text=True, timeout=15)
            return result
        except subprocess.TimeoutExpired:
            return None
        except Exception as e:
            self.log(f"ERR: {e}")
            return None

    def get_sudo_cmd(self, cmd_list):
        if self.is_linux:
            return ["pkexec"] + cmd_list
        return cmd_list

    def check_ip(self):
        try:
            result = subprocess.run(["curl", "-s", "--max-time", "10", "ifconfig.me"], capture_output=True, text=True, timeout=15)
            if result.returncode == 0:
                ip = result.stdout.strip()
                self.ip_label.configure(text=f"IP: [ {ip} ]")
                return ip
        except:
            pass
        self.ip_label.configure(text="IP: [ FAILED TO FETCH ]")
        return None

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
        if self.connected: return
        self.wg_btn.configure(state="disabled")
        self.ovpn_btn.configure(state="disabled")
        self.log("INIT: WireGuard protocol...")
        threading.Thread(target=self._connect_wireguard, daemon=True).start()

    def _connect_wireguard(self):
        wg_conf = os.path.join(self.config_path, "wg0.conf")
        if self.is_linux:
            self.run_cmd(self.get_sudo_cmd(["wg-quick", "down", "wg0"]))
            time.sleep(1)
            self.run_cmd(self.get_sudo_cmd(["cp", wg_conf, "/etc/wireguard/wg0.conf"]))
            result = self.run_cmd(self.get_sudo_cmd(["wg-quick", "up", "wg0"]))
            if result and result.returncode == 0:
                self.after(0, lambda: self.log("SUCCESS: WireGuard active."))
                self.after(0, lambda: self.set_status(True, "wg"))
                self.after(1000, self.check_ip)
            else:
                err = result.stderr if result else "Unknown error"
                self.after(0, lambda: self.log(f"ERR: WG failure: {err}"))
                self.after(0, lambda: self.set_status(False))
        elif self.is_windows:
            result = self.run_cmd(["wireguard", "/installtunnelservice", wg_conf])
            if result and result.returncode == 0:
                self.after(0, lambda: self.log("SUCCESS: WireGuard active."))
                self.after(0, lambda: self.set_status(True, "wg"))
                self.after(2000, self.check_ip)
            else:
                self.after(0, lambda: self.log("ERR: WG failure. Run as Admin."))
                self.after(0, lambda: self.set_status(False))

    def toggle_openvpn(self):
        if self.connected: return
        self.wg_btn.configure(state="disabled")
        self.ovpn_btn.configure(state="disabled")
        self.log("INIT: OpenVPN Stealth mode...")
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
        
        self.after(0, lambda: self.log("EXEC: Starting stunnel..."))
        try:
            if self.is_linux:
                self.stunnel_process = subprocess.Popen(self.get_sudo_cmd(["stunnel", stunnel_conf]), stdout=subprocess.PIPE, stderr=subprocess.PIPE)
            else:
                self.stunnel_process = subprocess.Popen(["stunnel", stunnel_conf], stdout=subprocess.PIPE, stderr=subprocess.PIPE, creationflags=subprocess.CREATE_NO_WINDOW)
        except FileNotFoundError:
            self.after(0, lambda: self.log("ERR: stunnel not found!"))
            self.after(0, lambda: self.set_status(False))
            return
            
        time.sleep(2)
        self.after(0, lambda: self.log("EXEC: Starting OpenVPN..."))
        try:
            if self.is_linux:
                self.ovpn_process = subprocess.Popen(self.get_sudo_cmd(["openvpn", "--config", ovpn_conf]), stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
            else:
                self.ovpn_process = subprocess.Popen(["openvpn", "--config", ovpn_conf], stdout=subprocess.PIPE, stderr=subprocess.STDOUT, creationflags=subprocess.CREATE_NO_WINDOW)
        except FileNotFoundError:
            self.after(0, lambda: self.log("ERR: openvpn not found!"))
            self.after(0, lambda: self.set_status(False))
            return
            
        self.monitoring = True
        threading.Thread(target=self._monitor_openvpn, daemon=True).start()

    def _monitor_openvpn(self):
        if not self.ovpn_process: return
        for line in iter(self.ovpn_process.stdout.readline, b''):
            if not self.monitoring: break
            decoded = line.decode("utf-8", errors="ignore").strip()
            if "Initialization Sequence Completed" in decoded:
                self.after(0, lambda: self.log("SUCCESS: OpenVPN active."))
                self.after(0, lambda: self.set_status(True, "ovpn"))
                self.after(2000, self.check_ip)
            elif "Connection reset" in decoded:
                self.after(0, lambda: self.log("WARN: Connection reset, retrying..."))
            elif "AUTH_FAILED" in decoded:
                self.after(0, lambda: self.log("ERR: Auth failed!"))
                self.after(0, lambda: self.set_status(False))
                break

    def disconnect(self):
        self.disconnect_btn.configure(state="disabled")
        self.log("EXEC: Terminating connection...")
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
                try: self.ovpn_process.terminate()
                except: pass
            if self.stunnel_process:
                try: self.stunnel_process.terminate()
                except: pass
                
        time.sleep(1)
        self.after(0, lambda: self.log("SUCCESS: Connection terminated."))
        self.after(0, lambda: self.set_status(False))

    def on_close(self):
        if self.connected:
            self._disconnect()
        self.destroy()

if __name__ == "__main__":
    app = VPNClient()
    app.mainloop()
