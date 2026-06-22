@echo off
echo ============================================
echo    BEKRE VPN - Windows EXE Build
echo ============================================

pip install pyinstaller customtkinter --quiet

pyinstaller --onefile --windowed --name "BekreVPN" vpn_client.py

echo.
echo Build tamamlandi: dist\BekreVPN.exe
echo.
echo Not: Ikon eklemek isterseniz, bir .ico dosyasi bu klasore
echo koyup yukaridaki komuta --icon=dosyaadi.ico ekleyebilirsiniz.
pause
