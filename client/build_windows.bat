@echo off
echo ============================================
echo    BEKRE VPN - Windows EXE Build
echo ============================================

pip install pyinstaller customtkinter --quiet

pyinstaller --onefile --windowed ^
    --name "BekreVPN" ^
    --icon=icon.ico ^
    vpn_client.py

echo.
echo Build tamamlandi: dist\BekreVPN.exe
pause
