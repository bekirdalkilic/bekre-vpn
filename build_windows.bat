@echo off
pip install customtkinter pyinstaller
pyinstaller --onefile --windowed --name FRA_VPN --icon=NONE vpn_client.py
echo EXE dosyasi dist\FRA_VPN.exe konumunda
pause

