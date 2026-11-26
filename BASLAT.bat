@echo off
rem ============================================================
rem  BAYTEREK baslatici (Windows)
rem  Cift tikla. Godot 4.6.3'u bulur, ilk acilista modelleri ice
rem  aktarir, oyunu ya da editoru acar. Gri ekran / acilmama
rem  durumunda "uyumluluk modu"nu dene; ciktilar log klasorunde.
rem ============================================================
setlocal EnableExtensions EnableDelayedExpansion
chcp 65001 >nul
cd /d "%~dp0"
title BAYTEREK Baslatici
if not exist "log" mkdir "log"

set "GODOT="
if exist "godot_yolu.txt" set /p GODOT=<"godot_yolu.txt"
if defined GODOT if not exist "!GODOT!" set "GODOT="
if defined GODOT goto :found

echo Godot 4.6.3 araniyor...
for %%D in ("%~dp0." "%~dp0.." "%USERPROFILE%\Downloads" "%USERPROFILE%\Desktop" "%USERPROFILE%\Documents" "%USERPROFILE%\OneDrive\Desktop" "C:\Godot" "D:\Godot") do (
  if not defined GODOT if exist "%%~D" (
    for /f "delims=" %%G in ('where /r "%%~D" "Godot_v4.6*_win64.exe" 2^>nul') do (
      if not defined GODOT set "GODOT=%%G"
    )
  )
)
if defined GODOT goto :found

echo.
echo Godot bulunamadi.
echo Indir: https://github.com/godotengine/godot/releases/download/4.6.3-stable/Godot_v4.6.3-stable_win64.exe.zip
echo Zip'i ac, icindeki Godot_v4.6.3-stable_win64.exe dosyasini bu pencereye
echo surukleyip birak ve Enter'a bas:
set /p GODOT=">> "
set GODOT=!GODOT:"=!
if not exist "!GODOT!" (
  echo Dosya bulunamadi: !GODOT!
  pause
  exit /b 1
)

:found
> "godot_yolu.txt" echo !GODOT!
set "GODOT_CON=!GODOT:_win64.exe=_win64_console.exe!"
if not exist "!GODOT_CON!" set "GODOT_CON=!GODOT!"
echo Godot: !GODOT!
set "GVER="
for /f "delims=" %%V in ('call "!GODOT_CON!" --version 2^>nul') do set "GVER=%%V"
echo Surum: !GVER!
echo %GVER%| findstr /b "4.6" >nul
if errorlevel 1 (
  echo.
  echo UYARI: Proje Godot 4.6.x icin. Bu surumle acmak projeyi bozabilir.
  echo 4.6.3 indir: https://github.com/godotengine/godot/releases/tag/4.6.3-stable
  pause
)

if not exist ".godot\imported" (
  echo.
  echo Ilk kurulum: modeller ve dokular ice aktariliyor. Birkac dakika surebilir, pencereyi kapatma...
  "!GODOT_CON!" --headless --path "%~dp0." --import > "log\ice_aktarma.txt" 2>&1
  echo Bitti. Ayrinti: log\ice_aktarma.txt
)

:menu
echo.
echo ================= BAYTEREK =================
echo  1  Oyunu baslat
echo  2  Oyunu baslat - uyumluluk modu: gri/siyah ekran, eski veya dahili ekran karti
echo  3  Godot editorunde ac
echo  4  Godot editorunde ac - uyumluluk modu
echo  5  Ice aktarmayi yenile: yeni model/doku ekledikten sonra
echo  0  Cikis
echo ============================================
set "SEC="
set /p SEC="Secim: "
if "!SEC!"=="1" goto :play
if "!SEC!"=="2" goto :play_compat
if "!SEC!"=="3" goto :editor
if "!SEC!"=="4" goto :editor_compat
if "!SEC!"=="5" goto :reimport
if "!SEC!"=="0" exit /b 0
goto :menu

:play
echo Oyun aciliyor... Cikti: log\oyun.txt
"!GODOT_CON!" --path "%~dp0." > "log\oyun.txt" 2>&1
call :report "log\oyun.txt"
goto :menu

:play_compat
echo Oyun uyumluluk modunda aciliyor... Cikti: log\oyun_uyumlu.txt
"!GODOT_CON!" --path "%~dp0." --rendering-method gl_compatibility --rendering-driver opengl3 > "log\oyun_uyumlu.txt" 2>&1
call :report "log\oyun_uyumlu.txt"
goto :menu

:editor
start "" "!GODOT!" --path "%~dp0." --editor
goto :menu

:editor_compat
start "" "!GODOT!" --path "%~dp0." --editor --rendering-method gl_compatibility --rendering-driver opengl3
goto :menu

:reimport
echo Ice aktariliyor... Cikti: log\ice_aktarma.txt
"!GODOT_CON!" --headless --path "%~dp0." --import > "log\ice_aktarma.txt" 2>&1
echo Bitti.
goto :menu

:report
findstr /i /c:"SCRIPT ERROR" /c:"ERROR:" /c:"Vulkan" "%~1" >nul
if not errorlevel 1 (
  echo.
  echo Oyun kapandi; gunlukte hata satirlari var. Ilk birkaci:
  findstr /i /n /c:"SCRIPT ERROR" /c:"ERROR:" /c:"Vulkan" "%~1" | more +0
  echo Gri ekran olduysa 2 numarayi dene. Duzelmezse %~1 dosyasini Claude'a gonder.
)
exit /b 0
