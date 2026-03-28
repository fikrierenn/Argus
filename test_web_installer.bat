@echo off
echo Web Installer Test Başlatılıyor...
echo.
echo Web installer'ı test etmek için:
echo 1. Installer'ı başlat
echo 2. "Web Interface (Detaylı Kurulum)" seçeneğini seç
echo 3. Tarayıcıda http://localhost:5555 açılacak
echo.
pause
cd src\BkmDenetim.Installer
dotnet run