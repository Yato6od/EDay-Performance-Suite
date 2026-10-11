[CmdletBinding()]
param(
    [switch]$Restore
)

$ErrorActionPreference = 'Stop'

$script:ScriptPath = $PSCommandPath
$root = Split-Path -Parent $script:ScriptPath

# ============================================================
# E-DAY PERFORMANCE SUITE | UNIVERSAL EDITION
#
# PERF  : Rendimiento estable / humo funcional
# ULTRA : Super Ultra Rendimiento / humo funcional
# RT    : Perfil compatible con RT
#
# Incluye:
# - Deteccion de configuraciones
# - Copias de seguridad
# - Restauracion
# - Diagnostico de rutas
# - Resolucion 1920x1080 para ULTRA
#
# IMPORTANTE:
# El perfil no garantiza un FPS determinado ni fuerza
# un modo DLSS que el juego no reconozca.
# ============================================================

$script:InstallStateName = '.eds-install-state.json'


# ============================================================
# FUNCIONES GENERALES
# ============================================================

function Write-PathLine {
    param(
        [string]$Label,
        [string]$Path,
        [ConsoleColor]$Color = [ConsoleColor]::Gray
    )

    Write-Host ("{0,-30} {1}" -f ($Label + ':'), $Path) `
        -ForegroundColor $Color
}


function Get-SearchRoots {

    $roots = @(
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Gears of War E-Day\Steam'),
        (Join-Path $env:LOCALAPPDATA 'Microsoft\Gears of War E-Day'),
        (Join-Path $env:LOCALAPPDATA 'Gears of War E-Day'),
        (Join-Path $env:LOCALAPPDATA 'FairlightConcept'),
        (Join-Path $env:LOCALAPPDATA 'Packages'),
        (Join-Path $env:APPDATA 'Gears of War E-Day'),
        (Join-Path $env:USERPROFILE 'Documents\My Games'),
        (Join-Path $env:USERPROFILE 'Saved Games')
    )

    return @(
        $roots |
        Where-Object { $_ } |
        Select-Object -Unique
    )
}


# ============================================================
# COMPROBACION DE ARCHIVOS DEL INSTALADOR
# ============================================================

function Show-InstallerPaths {

    Write-Host "`n========== RUTAS DEL INSTALADOR ==========" `
        -ForegroundColor Cyan

    Write-PathLine 'Carpeta del script' $root
    Write-PathLine 'Script PowerShell' $script:ScriptPath

    Write-Host "`nArchivos de perfil esperados:" `
        -ForegroundColor Cyan

    $profiles = @(
        'Engine_Performance_SmokeSafe.ini',
        'Engine_Performance_Plus_SmokeSafe.ini',
        'Engine_RT_SmokeSafe.ini',
        'Scalability_Low_SmokeSafe.ini',
        'Scalability_Enhanced.ini'
    )

    foreach ($name in $profiles) {

        $path = Join-Path $root $name

        if (Test-Path -LiteralPath $path -PathType Leaf) {

            Write-Host "[OK] $path" -ForegroundColor Green

        }
        else {

            Write-Host "[FALTA] $path" -ForegroundColor Red

        }
    }
}


# ============================================================
# BUSQUEDA DE CONFIGURACIONES DEL JUEGO
# ============================================================

function Find-ConfigDirs {

    $found = @()
    $roots = @(Get-SearchRoots)

    Write-Host "`n========== RUTAS EXAMINADAS ==========" `
        -ForegroundColor Cyan

    foreach ($r in $roots) {

        if (Test-Path -LiteralPath $r -PathType Container) {

            Write-Host "[EXISTE] $r" -ForegroundColor DarkGray

            try {

                $files = Get-ChildItem `
                    -LiteralPath $r `
                    -Filter 'GameUserSettings.ini' `
                    -File `
                    -Recurse `
                    -ErrorAction SilentlyContinue

                foreach ($file in $files) {

                    $found += $file.Directory.FullName

                }
            }
            catch {

                Write-Host "[AVISO] No se pudo examinar: $r" `
                    -ForegroundColor Yellow

            }
        }
        else {

            Write-Host "[NO EXISTE] $r" -ForegroundColor DarkGray

        }
    }

    return @($found | Select-Object -Unique)
}


function Find-ConfigDir {

    $dirs = @(Find-ConfigDirs)

    if ($dirs.Count -eq 0) {

        return $null

    }

    if ($dirs.Count -eq 1) {

        return $dirs[0]

    }

    Write-Host "`nSe encontraron varias configuraciones:" `
        -ForegroundColor Yellow

    for ($i = 0; $i -lt $dirs.Count; $i++) {

        Write-Host "[$($i + 1)] $($dirs[$i])"

    }

    $selection = Read-Host 'Selecciona la carpeta correcta'
    $number = 0

    if (
        [int]::TryParse($selection, [ref]$number) -and
        $number -ge 1 -and
        $number -le $dirs.Count
    ) {

        return $dirs[$number - 1]

    }

    throw 'Seleccion de carpeta no valida. No se modificaron archivos.'
}


# ============================================================
# MODIFICAR UNA CLAVE DENTRO DE UNA SECCION INI
# ============================================================

function Set-SectionValue(
    [string]$txt,
    [string]$section,
    [string]$key,
    [string]$value
) {

    $escaped = [regex]::Escape($section)

    $pattern = '(?ms)(^\[' + $escaped + '\][ \t]*\r?\n)(.*?)(?=^\[|\z)'

    $m = [regex]::Match($txt, $pattern)

    if (-not $m.Success) {

        return $txt.TrimEnd() +
            "`r`n[$section]`r`n$key=$value`r`n"

    }

    $body = $m.Groups[2].Value

    $keyPattern = '(?m)^[ \t]*' +
        [regex]::Escape($key) +
        '[ \t]*=.*$'

    $lines = @($body -split "\r?\n")
    $newLines = New-Object System.Collections.Generic.List[string]
    $seen = $false

    foreach ($line in $lines) {

        if ($line -match $keyPattern) {

            if (-not $seen) {

                $newLines.Add($key + '=' + $value)
                $seen = $true

            }

            # Elimina duplicados de la misma clave.
            continue

        }

        $newLines.Add($line)

    }

    if (-not $seen) {

        $newLines.Add($key + '=' + $value)

    }

    $newBody = ($newLines -join "`r`n").TrimEnd() + "`r`n"

    return $txt.Substring(0, $m.Index) +
        $m.Groups[1].Value +
        $newBody +
        $txt.Substring($m.Index + $m.Length)
}


# ============================================================
# ESTABLECER VARIAS CLAVES SIN DUPLICADOS
# ============================================================

function Set-UniqueSectionValues(
    [string]$txt,
    [string]$section,
    [hashtable]$values
) {

    $escaped = [regex]::Escape($section)

    $pattern = '(?ms)(^\[' + $escaped + '\][ \t]*\r?\n)(.*?)(?=^\[|\z)'

    $m = [regex]::Match($txt, $pattern)

    if (-not $m.Success) {

        $newBody = ''

        foreach ($key in $values.Keys) {

            $newBody += "$key=$($values[$key])`r`n"

        }

        return $txt.TrimEnd() +
            "`r`n[$section]`r`n" +
            $newBody
    }

    $lines = @($m.Groups[2].Value -split "\r?\n")

    $newLines = New-Object System.Collections.Generic.List[string]
    $seen = @{}

    foreach ($key in $values.Keys) {

        $seen[$key] = $false

    }

    foreach ($line in $lines) {

        $matchedKey = $null

        foreach ($key in $values.Keys) {

            $keyPattern = '^[ \t]*' +
                [regex]::Escape([string]$key) +
                '[ \t]*='

            if ($line -match $keyPattern) {

                $matchedKey = [string]$key
                break

            }
        }

        if ($null -eq $matchedKey) {

            $newLines.Add($line)
            continue

        }

        if (-not $seen[$matchedKey]) {

            $newLines.Add(
                $matchedKey + '=' + [string]$values[$matchedKey]
            )

            $seen[$matchedKey] = $true

        }
    }

    foreach ($key in $values.Keys) {

        if (-not $seen[$key]) {

            $newLines.Add(
                [string]$key + '=' + [string]$values[$key]
            )

        }
    }

    $newBody = ($newLines -join "`r`n").TrimEnd() + "`r`n"

    return $txt.Substring(0, $m.Index) +
        $m.Groups[1].Value +
        $newBody +
        $txt.Substring($m.Index + $m.Length)
}


# ============================================================
# AJUSTES INTERNOS GUARDADOS POR EL JUEGO
# ============================================================

function Set-PackedBoolSetting(
    [string]$txt,
    [string]$settingName,
    [bool]$value
) {
    # Solo modifica el booleano si la clave ya existe en SaveValuesBool.
    # No crea identificadores internos ni altera enumeraciones desconocidas.
    $escapedName = [regex]::Escape($settingName)
    $pattern = '(\("' + $escapedName + '_\d+"\s*,\s*)(?:True|False)(\s*\))'
    $replacementValue = if ($value) { 'True' } else { 'False' }
    $updated = [regex]::Replace(
        $txt,
        $pattern,
        [System.Text.RegularExpressions.MatchEvaluator]{
            param($m)
            return $m.Groups[1].Value + $replacementValue + $m.Groups[2].Value
        }
    )
    return [pscustomobject]@{
        Text = $updated
        Found = ($updated -ne $txt) -or ($txt -match $pattern)
    }
}

# ============================================================
# PERMISOS DE ARCHIVOS
# ============================================================

function Set-FileWritable([string]$path) {

    if (Test-Path -LiteralPath $path -PathType Leaf) {

        $item = Get-Item -LiteralPath $path

        if ($item.IsReadOnly) {

            $item.IsReadOnly = $false

        }
    }
}


# ============================================================
# VALIDAR ARCHIVOS PARA CADA PERFIL
# ============================================================

function Test-ProfileFiles([string]$profile) {

    switch ($profile) {

        'ULTRA' {

            $engineSrc = 'Engine_Performance_Plus_SmokeSafe.ini'
            $scalSrc = 'Scalability_Low_SmokeSafe.ini'

        }

        'RT' {

            $engineSrc = 'Engine_RT_SmokeSafe.ini'
            $scalSrc = 'Scalability_Enhanced.ini'

        }

        default {

            $engineSrc = 'Engine_Performance_SmokeSafe.ini'
            $scalSrc = 'Scalability_Low_SmokeSafe.ini'

        }
    }

    foreach ($name in @($engineSrc, $scalSrc)) {

        $path = Join-Path $root $name

        if (-not (Test-Path -LiteralPath $path -PathType Leaf)) {

            throw "Falta un archivo requerido del perfil: $path"

        }
    }
}


# ============================================================
# ESTADO DE INSTALACION
# ============================================================

function Get-InstallStatePath([string]$dir) {

    return (Join-Path $dir $script:InstallStateName)

}


function Read-InstallState([string]$dir) {

    $statePath = Get-InstallStatePath $dir

    if (Test-Path -LiteralPath $statePath -PathType Leaf) {

        try {

            return (
                Get-Content -LiteralPath $statePath -Raw |
                ConvertFrom-Json
            )

        }
        catch {

            Write-Host `
                "No se pudo leer el registro: $statePath" `
                -ForegroundColor Yellow

        }
    }

    return $null
}


# ============================================================
# DIAGNOSTICO
# ============================================================

function Diagnose {

    Show-InstallerPaths

    $dirs = @(Find-ConfigDirs)

    Write-Host "`n========== CONFIGURACIONES ENCONTRADAS ==========" `
        -ForegroundColor Cyan

    if ($dirs.Count -eq 0) {

        Write-Host `
            'No se encontro GameUserSettings.ini en las rutas examinadas.' `
            -ForegroundColor Red

        Write-Host 'No se modifico ningun archivo.'
        return

    }

    foreach ($dir in $dirs) {

        Write-Host "`nConfiguracion: $dir" `
            -ForegroundColor Green

        foreach ($name in @(
            'GameUserSettings.ini',
            'Engine.ini',
            'Scalability.ini'
        )) {

            $path = Join-Path $dir $name

            if (Test-Path -LiteralPath $path -PathType Leaf) {

                Write-Host "[EXISTE] $path" -ForegroundColor Green

            }
            else {

                Write-Host "[NO EXISTE] $path" -ForegroundColor Yellow

            }

            $backup = "$path.eds-original.bak"

            if (Test-Path -LiteralPath $backup -PathType Leaf) {

                Write-Host "  Respaldo: $backup"

            }
        }

        $statePath = Get-InstallStatePath $dir

        if (Test-Path -LiteralPath $statePath -PathType Leaf) {

            Write-Host "Registro de instalacion: $statePath"

        }
    }
}


# ============================================================
# INSTALACION DE PERFILES
# ============================================================

function Install([string]$profile) {

    Show-InstallerPaths

    Test-ProfileFiles $profile

    $dir = Find-ConfigDir

    if (-not $dir) {

        throw 'No se encontro GameUserSettings.ini. Ejecuta primero el juego y vuelve a intentarlo.'

    }

    $gus = Join-Path $dir 'GameUserSettings.ini'
    $engine = Join-Path $dir 'Engine.ini'
    $scal = Join-Path $dir 'Scalability.ini'

    if (-not (Test-Path -LiteralPath $gus -PathType Leaf)) {

        throw "No existe la configuracion principal: $gus"

    }

    Write-Host "`n========== DESTINOS DE INSTALACION ==========" `
        -ForegroundColor Cyan

    Write-PathLine 'Carpeta de configuracion' $dir Green
    Write-PathLine 'GameUserSettings.ini' $gus
    Write-PathLine 'Engine.ini destino' $engine
    Write-PathLine 'Scalability.ini destino' $scal

    $statePath = Get-InstallStatePath $dir
    $state = Read-InstallState $dir

    # Crear respaldos solamente durante la primera instalacion.
    # No reemplazar el estado original en instalaciones posteriores.

    if (-not $state) {

        $entries = @()

        foreach ($name in @(
            'Engine.ini',
            'GameUserSettings.ini',
            'Scalability.ini'
        )) {

            $path = Join-Path $dir $name
            $backup = "$path.eds-original.bak"

            $existed = Test-Path -LiteralPath $path -PathType Leaf

            if (
                $existed -and
                -not (Test-Path -LiteralPath $backup -PathType Leaf)
            ) {

                Copy-Item -LiteralPath $path -Destination $backup

                Write-Host "Copia creada: $backup" `
                    -ForegroundColor Green

            }

            $entries += [pscustomobject]@{
                Name = $name
                ExistedBeforeInstall = [bool]$existed
                BackupPath = $backup
            }
        }

        $state = [pscustomobject]@{
            Version = 1
            ConfigDirectory = $dir
            CreatedAt = (Get-Date).ToString('o')
            Files = $entries
        }

        $state |
            ConvertTo-Json -Depth 5 |
            Set-Content -LiteralPath $statePath -Encoding UTF8

        Write-Host "Registro creado: $statePath" `
            -ForegroundColor Green

    }
    else {

        Write-Host `
            "Se conserva el registro original: $statePath" `
            -ForegroundColor DarkYellow

    }

    foreach ($path in @($engine, $scal, $gus)) {

        Set-FileWritable $path

    }

    # Elegir los archivos fuente del perfil.

    switch ($profile) {

        'ULTRA' {

            $engineSrc = 'Engine_Performance_Plus_SmokeSafe.ini'
            $scalSrc = 'Scalability_Low_SmokeSafe.ini'

        }

        'RT' {

            $engineSrc = 'Engine_RT_SmokeSafe.ini'
            $scalSrc = 'Scalability_Enhanced.ini'

        }

        default {

            $engineSrc = 'Engine_Performance_SmokeSafe.ini'
            $scalSrc = 'Scalability_Low_SmokeSafe.ini'

        }
    }

    Write-Host "`n========== ARCHIVOS DE PERFIL ==========" `
        -ForegroundColor Cyan

    Write-PathLine 'Engine fuente' (Join-Path $root $engineSrc)
    Write-PathLine 'Scalability fuente' (Join-Path $root $scalSrc)

    # Copiar perfiles al directorio del juego.

    Copy-Item `
        -LiteralPath (Join-Path $root $engineSrc) `
        -Destination $engine `
        -Force

    Copy-Item `
        -LiteralPath (Join-Path $root $scalSrc) `
        -Destination $scal `
        -Force

    # Leer la configuracion principal.

    $txt = [IO.File]::ReadAllText($gus)

    # Configuracion comun:
    # - FPS sin limite desde este archivo.
    # - VSync desactivado.
    # - Resolucion dinamica desactivada.

    $baseSettings = @{
        'FrameRateLimit' = '0.000000'
        'bUseVSync' = 'False'
        'bUseDynamicResolution' = 'False'
    }

    # Solo el perfil ULTRA impone 1920x1080.
    # No se cambia la resolucion de los otros perfiles.

    if ($profile -eq 'ULTRA') {

        $baseSettings['ResolutionSizeX'] = '1920'
        $baseSettings['ResolutionSizeY'] = '1080'
        $baseSettings['LastUserConfirmedResolutionSizeX'] = '1920'
        $baseSettings['LastUserConfirmedResolutionSizeY'] = '1080'
        $baseSettings['DesiredScreenWidth'] = '1920'
        $baseSettings['DesiredScreenHeight'] = '1080'

    }

    $txt = Set-UniqueSectionValues `
        $txt `
        '/Script/Engine.GameUserSettings' `
        $baseSettings

    # Escala de resolucion del motor.
    # No equivale a activar un modo DLSS concreto.

    $resolutionQuality = '100.000000'

    if ($profile -eq 'ULTRA') {

        $resolutionQuality = '100.000000'

    }

    $txt = Set-SectionValue `
        $txt `
        'ScalabilityGroups' `
        'sg.ResolutionQuality' `
        $resolutionQuality

    # Grupos de calidad bajos.
    # En ULTRA se prioriza el rendimiento.
    # En RT se conservan los ajustes especiales del perfil.

    $low = @(
        'ViewDistance',
        'AntiAliasing',
        'Shadow',
        'GlobalIllumination',
        'Reflection',
        'PostProcess',
        'Texture',
        'Effects',
        'Foliage',
        'Shading',
        'Landscape',
        'VolumetricCloud',
        'Hair',
        'Nanite',
        'RayTracing',
        'RayTracingReflections',
        'RayTracingShadows',
        'RayTracingGlobalIllumination'
    )

    foreach ($name in $low) {

        $quality = '0'

        if (
            $profile -eq 'RT' -and
            $name -in @(
                'GlobalIllumination',
                'Reflection',
                'PostProcess'
            )
        ) {

            $quality = '2'

        }

        if ($profile -eq 'RT' -and $name -eq 'Shadow') {

            $quality = '1'

        }

        $txt = Set-SectionValue `
            $txt `
            'ScalabilityGroups' `
            ('sg.' + $name + 'Quality') `
            $quality
    }

    # EXCEPCION DE HUMO:
    # Se conserva VolumetricFogQuality=1.
    # No se desactiva deliberadamente la niebla volumetrica.

    $txt = Set-SectionValue `
        $txt `
        'ScalabilityGroups' `
        'sg.VolumetricFogQuality' `
        '1'

    # Ajustes internos conocidos que se guardan dentro de SaveValuesBool.
    # No se modifican SaveValuesUInt8 ni el modo DLSS: sus enumeraciones
    # no se pueden deducir de forma segura solo por el nombre de la clave.
    $packedBoolSettings = @(
        @{ Name = 'Settings.Graphics.VSync'; Value = $false },
        @{ Name = 'Settings.Graphics.FilmGrain'; Value = $false },
        @{ Name = 'Settings.Graphics.DetailObjects'; Value = $false },
        @{ Name = 'Setting.CinematicWidescreen.Enabled'; Value = $false }
    )

    foreach ($setting in $packedBoolSettings) {
        $before = $txt
        $result = Set-PackedBoolSetting `
            $txt `
            ([string]$setting.Name) `
            ([bool]$setting.Value)
        $txt = $result.Text

        if ($txt -match ('\("' + [regex]::Escape([string]$setting.Name) + '_\d+"\s*,\s*' + [string]$setting.Value + '\s*\)')) {
            Write-Host "[OK] Ajuste interno: $($setting.Name) = $($setting.Value)" -ForegroundColor Green
        }
        else {
            Write-Host "[INFO] No se encontró la clave interna: $($setting.Name). Se deja sin cambios." -ForegroundColor DarkYellow
        }
    }

    # Guardar configuracion.

    [IO.File]::WriteAllText($gus, $txt)

    # Mostrar resultado.

    Write-Host "`n========== RESULTADO ==========" `
        -ForegroundColor Cyan

    switch ($profile) {

        'ULTRA' {

            Write-Host `
                'PERFIL SUPER ULTRA RENDIMIENTO APLICADO' `
                -ForegroundColor Green

            Write-Host 'Resolucion configurada: 1920x1080'
            Write-Host 'Objetivo: priorizar FPS y reducir carga grafica.'
            Write-Host 'Humo: se conserva VolumetricFogQuality=1.'

        }

        'RT' {

            Write-Host `
                'PERFIL RT-COMPATIBLE APLICADO' `
                -ForegroundColor Green

        }

        default {

            Write-Host `
                'PERFIL PERFORMANCE SMOKE SAFE APLICADO' `
                -ForegroundColor Green

        }
    }

    Write-Host 'FrameRateLimit: 0.000000'
    Write-Host 'bUseVSync: False'
    Write-Host 'bUseDynamicResolution: False'

    Write-Host ''
    Write-Host '========== CONFIGURACION MANUAL RECOMENDADA ==========' `
        -ForegroundColor Cyan

    if ($profile -eq 'ULTRA') {
        Write-Host 'En el menu de Graficos/Pantalla del juego, verifica:' `
            -ForegroundColor Yellow
        Write-Host '1. Resolucion: 1920 x 1080 (Full HD 1080p).'
        Write-Host '2. NVIDIA DLSS: Activado.'
        Write-Host '3. Modo DLSS: Ultra Performance (si priorizas FPS).'
        Write-Host '4. V-Sync / Sincronizacion vertical: Desactivado (No).'
        Write-Host '5. Resolucion dinamica: Desactivada, si el juego ofrece esa opcion.'
        Write-Host ''
        Write-Host 'Nota: 1920 x 1080 es Full HD; 1920 x 1980 no es la resolucion Full HD estandar.'
    }

    Write-Host 'DLSS: el modo debe validarse en el menu grafico del juego.'
    Write-Host 'El script no modifica la enumeracion interna de DLSS porque no esta validada.'
    Write-Host 'Los archivos no se marcaron como solo lectura.'

    Write-Host ''
    Write-Host 'Si el juego ignora la resolucion o la cambia al iniciar,'
    Write-Host 'revisa GameUserSettings.ini despues de cerrar el juego.'

    Write-Host ''
    Write-Host 'No se garantiza una cifra concreta de FPS.'
}


# ============================================================
# RESTAURAR CONFIGURACION
# ============================================================

function Restore {

    Show-InstallerPaths

    $dir = Find-ConfigDir

    if (-not $dir) {

        throw 'No se encontro la carpeta de configuracion.'

    }

    Write-Host "`n========== RESTAURACION ==========" `
        -ForegroundColor Cyan

    Write-PathLine 'Carpeta de configuracion' $dir Green

    $state = Read-InstallState $dir

    foreach ($name in @(
        'Engine.ini',
        'GameUserSettings.ini',
        'Scalability.ini'
    )) {

        $path = Join-Path $dir $name
        $legacyBackup = "$path.eds-original.bak"
        $mellyBackup = "$path.melly-stock-backup"

        Set-FileWritable $path

        # Prioridad 1: copia de seguridad pre-Melly.

        if (Test-Path -LiteralPath $mellyBackup -PathType Leaf) {

            Copy-Item `
                -LiteralPath $mellyBackup `
                -Destination $path `
                -Force

            Write-Host "Restaurado respaldo pre-Melly: $mellyBackup" `
                -ForegroundColor Green

            continue

        }

        # Prioridad 2: copia de seguridad original de la suite.

        if (Test-Path -LiteralPath $legacyBackup -PathType Leaf) {

            Copy-Item `
                -LiteralPath $legacyBackup `
                -Destination $path `
                -Force

            Write-Host "Restaurado respaldo de la suite: $legacyBackup" `
                -ForegroundColor Green

            continue

        }

        # Prioridad 3: eliminar archivos creados por la suite
        # cuando se haya registrado que no existian antes.

        $entry = $null

        if ($state -and $state.Files) {

            $entry = $state.Files |
                Where-Object { $_.Name -eq $name } |
                Select-Object -First 1

        }

        if ($entry -and -not [bool]$entry.ExistedBeforeInstall) {

            if (Test-Path -LiteralPath $path -PathType Leaf) {

                Remove-Item -LiteralPath $path -Force

                Write-Host "Eliminado archivo creado por la suite: $path" `
                    -ForegroundColor Yellow

            }
            else {

                Write-Host "No existe archivo que restaurar: $path"

            }
        }
        else {

            Write-Host `
                "No se encontro respaldo para $path; se deja sin cambios." `
                -ForegroundColor Yellow

        }
    }

    if ($state) {

        Write-Host `
            "Registro conservado: $(Get-InstallStatePath $dir)" `
            -ForegroundColor DarkGray

    }

    Write-Host ''
    Write-Host 'Proceso de restauracion finalizado.' `
        -ForegroundColor Green
}


# ============================================================
# EJECUCION DIRECTA DE RESTAURACION (llamada desde el BAT con -Restore)
# ============================================================

if ($Restore) {
    try {
        Clear-Host
        Write-Host "E-DAY PERFORMANCE SUITE | RESTAURACION" -ForegroundColor Cyan
        Write-Host ""
        Write-Host "Se restauraran los respaldos disponibles para la configuracion detectada." -ForegroundColor Yellow
        Write-Host "Cierra Gears of War: E-Day antes de continuar."
        $confirmation = Read-Host "Escribe RESTAURAR para confirmar"
        if ($confirmation -cne 'RESTAURAR') {
            Write-Host "Operacion cancelada. No se solicitaron cambios." -ForegroundColor Yellow
            exit 2
        }

        Restore
        Write-Host ""
        Write-Host "Restauracion finalizada. Revisa los mensajes anteriores." -ForegroundColor Green
        Read-Host "Presiona Enter para cerrar"
        exit 0
    }
    catch {
        Write-Host "`nERROR durante la restauracion: $($_.Exception.Message)" -ForegroundColor Red
        Read-Host "Presiona Enter para cerrar"
        exit 1
    }
}

# ============================================================
# MENU PRINCIPAL
# ============================================================

Clear-Host

Show-InstallerPaths

Write-Host "`n============================================" `
    -ForegroundColor Cyan

Write-Host ' E-DAY PERFORMANCE SUITE | UNIVERSAL EDITION' `
    -ForegroundColor Cyan

Write-Host '============================================' `
    -ForegroundColor Cyan

Write-Host ''
Write-Host '1 - PERFORMANCE / RT OFF / SMOKE SAFE'
Write-Host '2 - SUPER ULTRA RENDIMIENTO / HUMO FUNCIONAL' `
    -ForegroundColor Green
Write-Host '3 - RT-COMPATIBLE PERFORMANCE / SMOKE SAFE'
Write-Host '4 - RESTAURAR COPIAS DE SEGURIDAD'
Write-Host '5 - DIAGNOSTICAR RUTAS DE CONFIGURACION'
Write-Host '6 - SALIR'

$choice = Read-Host 'Selecciona una opcion (1-6)'

try {

    switch ($choice) {

        '1' {

            Install 'PERF'

        }

        '2' {

            Install 'ULTRA'

        }

        '3' {

            Install 'RT'

        }

        '4' {

            Restore

        }

        '5' {

            Diagnose

        }

        '6' {

            exit

        }

        default {

            throw 'Seleccion no valida.'

        }
    }
}
catch {

    Write-Host "`nERROR: $($_.Exception.Message)" `
        -ForegroundColor Red

    Write-Host ''
    Write-Host 'No ignores este error. Revisa la ruta y los archivos.'
}

Read-Host 'Presiona Enter para cerrar'