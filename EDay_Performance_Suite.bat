@echo off
setlocal EnableExtensions
chcp 65001 >nul
title E-DAY PERFORMANCE SUITE - UNIVERSAL EDITION
color 0B
cd /d "%~dp0"
:MENU
cls
echo ============================================================
echo       E-DAY PERFORMANCE SUITE - UNIVERSAL EDITION
echo ============================================================
echo.
echo OBJETIVO
echo   Instalar perfiles de rendimiento para Gears of War: E-Day.
echo   El perfil ULTRA prioriza FPS y conserva el humo funcional.
echo.
echo COMPATIBILIDAD Y REQUISITOS
echo   - Windows con PowerShell.
echo   - Este BAT debe estar junto al PS1, los INI y el manual PDF.
echo   - DLSS requiere una GPU NVIDIA RTX compatible.
echo   - Referencia objetivo: NVIDIA GeForce RTX 2050 Laptop GPU o superior.
echo   - La compatibilidad depende del juego, GPU y controlador.
echo   - No se garantiza un numero concreto de FPS.
echo.
echo AJUSTES MANUALES RECOMENDADOS PARA ULTRA
echo   Resolucion: 1920 x 1080 (Full HD).
echo   NVIDIA DLSS: activado, si esta disponible.
echo   Modo inicial sugerido: Ultra Performance.
echo   Si se ve borroso, comparar Performance y Balanced.
echo   V-Sync: desactivado.
echo   Ray Tracing: desactivado en el perfil ULTRA.
echo   Humo de granadas: debe permanecer funcional.
echo.
echo ============================================================
echo                       MENU PRINCIPAL
echo ============================================================
echo.
echo   [M] Abrir manual de uso (PDF)
echo   [S] Instalar o cambiar perfil de rendimiento
echo   [R] Restaurar valores por defecto
echo   [D] Diagnosticar rutas de configuracion
echo   [E] Salir
echo.
choice /C MSRDE /N /M "Selecciona una opcion [M/S/R/D/E]: "
if errorlevel 5 goto END
if errorlevel 4 goto DIAGNOSE
if errorlevel 3 goto RESTORE
if errorlevel 2 goto INSTALL
if errorlevel 1 goto MANUAL

:MANUAL
if exist "%~dp0Manual_EDay_Performance_Suite.pdf" (
    start "" "%~dp0Manual_EDay_Performance_Suite.pdf"
) else (
    echo [ERROR] No se encontro Manual_EDay_Performance_Suite.pdf
    pause
)
goto MENU

:INSTALL
if not exist "%~dp0EDay_Performance_Suite.ps1" (
    echo [ERROR] Falta EDay_Performance_Suite.ps1
    pause
    goto MENU
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0EDay_Performance_Suite.ps1"
echo.
pause
goto MENU

:RESTORE
cls
echo ============================================================
echo                RESTAURAR VALORES POR DEFECTO
echo ============================================================
echo.
echo Cierra Gears of War: E-Day antes de continuar.
echo Se utilizaran las copias de seguridad disponibles.
echo No borres los archivos .bak ni .eds-install-state.json.
echo.
if not exist "%~dp0EDay_Performance_Suite.ps1" (
    echo [ERROR] Falta EDay_Performance_Suite.ps1
    pause
    goto MENU
)
choice /C SN /N /M "Deseas continuar? [S/N]: "
if errorlevel 2 goto MENU
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%~dp0EDay_Performance_Suite.ps1" -Restore
echo.
pause
goto MENU

:DIAGNOSE
if not exist "%~dp0EDay_Performance_Suite.ps1" (
    echo [ERROR] Falta EDay_Performance_Suite.ps1
    pause
    goto MENU
)
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "& { . '%~dp0EDay_Performance_Suite.ps1' }"
echo.
echo Nota: esta accion abre el menu PowerShell; selecciona 5 para diagnosticar.
pause
goto MENU

:END
endlocal
exit /b
