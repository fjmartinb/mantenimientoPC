


#Requires -RunAsAdministrator

# ============================================================
# Autor:        Francisco Javier Martín
# Empresa:      Konica Minolta Business Solutions Spain
# Fecha:        Abril - 2026
# Descripcion:  Script de mantenimiento y limpieza para Windows               
# Opciones:
#          [1]  Limpiar archivos temporales
#          [2]  Vaciar Papelera de reciclaje
#          [3]  Limpiar cache de Windows Update
#          [4]  Eliminar cache de miniaturas
#          [5]  Limpiar carpeta Prefetch
#          [6]  Eliminar archivos de volcado (dumps)
#          [7]  Ejecutar Liberador de espacio (cleanmgr)
#          [8]  Limpiar logs de eventos antiguos
#          [9]  Limpiar cache de navegadores
#          [10] Optimizar discos (Defrag/TRIM)
#          [11] Verificar integridad del sistema (SFC + DISM)
#          [12] Ver programas de inicio
#          [13] Verificar salud SMART de discos
# ============================================================

param(
    [switch]$Silent,
    [switch]$Full,
    [string]$EmailTo
)

$version = "2.0"
$logFile = "$env:C:\logs\Mantenimiento_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
$transcriptFile = "$env:C:\logs\Transcript_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"
$totalLiberado = 0
$resultados = @()

# Verificar privilegios de administrador
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "Este script requiere privilegios de administrador. Reiniciando con elevacion..." -ForegroundColor Yellow
    Start-Process powershell.exe -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" -Verb RunAs
    exit
}

Start-Transcript -Path $transcriptFile -Append | Out-Null

#Si ves un error de politica de ejecucion, descomenta la siguiente linea:
#Set-ExecutionPolicy RemoteSigned -Scope CurrentUser

function Write-Header {
    Clear-Host
    Write-Host ""
    Write-Host "  +==================================================+" -ForegroundColor Cyan
    Write-Host "  |                                                  |" -ForegroundColor Cyan
    Write-Host "  |         MANTENIMIENTO DEL SISTEMA  v$version          |" -ForegroundColor Cyan
    Write-Host "  |           Windows Cleaner & Optimizer            |" -ForegroundColor Cyan
    Write-Host "  |                                                  |" -ForegroundColor Cyan
    Write-Host "  +==================================================+" -ForegroundColor Cyan
    Write-Host ""
}

function Write-Step($mensaje) {
    Write-Host "  > " -NoNewline -ForegroundColor Yellow
    Write-Host $mensaje -ForegroundColor White
}

function Write-OK($mensaje) {
    Write-Host "  OK " -NoNewline -ForegroundColor Green
    Write-Host $mensaje -ForegroundColor Gray
}

function Write-Info($mensaje) {
    Write-Host "  i  " -NoNewline -ForegroundColor Blue
    Write-Host $mensaje -ForegroundColor Gray
}

function Write-Warn($mensaje) {
    Write-Host "  !  " -NoNewline -ForegroundColor DarkYellow
    Write-Host $mensaje -ForegroundColor Gray
}

function Write-Separador {
    Write-Host "  --------------------------------------------------" -ForegroundColor DarkGray
}

function Write-ProgressBar {
    param([int]$Percent, [string]$Activity)
    $width = 40
    $completed = [math]::Round($width * $Percent / 100)
    $bar = "[" + ("=" * $completed) + (" " * ($width - $completed)) + "] $Percent%"
    Write-Host "`r  $Activity $bar" -NoNewline -ForegroundColor Cyan
    if ($Percent -eq 100) { Write-Host "" }
}

function Get-TamanoCarpeta($ruta) {
    if (Test-Path $ruta) {
        $bytes = (Get-ChildItem $ruta -Recurse -Force -ErrorAction SilentlyContinue |
                  Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
        return [math]::Round($bytes / 1MB, 2)
    }
    return 0
}

function Format-Tamano($mb) {
    if ($mb -ge 1024) { return "$([math]::Round($mb/1024, 2)) GB" }
    return "$mb MB"
}

function Log-Accion($texto) {
    $timestamp = Get-Date -Format "HH:mm:ss"
    Add-Content -Path $logFile -Value "[$timestamp] $texto"
}

function Test-EspacioSuficiente {
    $discoC = Get-PSDrive C
    $libreGB = [math]::Round($discoC.Free / 1GB, 2)
    if ($libreGB -lt 1) {
        Write-Warn "¡Atencion! Solo quedan $libreGB GB libres en C:. Algunas operaciones pueden fallar."
        return $false
    }
    return $true
}

function Backup-Registro {
    Write-Step "Creando backup del registro..."
    $backupPath = "$env:C:\logs\RegBackup_$(Get-Date -Format 'yyyyMMdd_HHmmss').reg"
    try {
        reg export "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches" "$backupPath" /y
        if ($LASTEXITCODE -eq 0) {
            Write-OK "Backup del registro guardado en: $backupPath"
            Log-Accion "Backup registro creado: $backupPath"
        } else {
            Write-Warn "reg export devolvio codigo de error: $LASTEXITCODE"
        }
    } catch {
        Write-Warn "No se pudo crear backup del registro: $($_.Exception.Message)"
    }
}

function Limpiar-Temporales {
    Write-Separador
    Write-Step "Limpiando archivos temporales del sistema..."

    $rutas = @(
        "$env:TEMP",
        "$env:TMP",
        "C:\Windows\Temp",
        "$env:USERPROFILE\AppData\Local\Temp"
    )

    $liberado = 0
    $i = 0
    foreach ($ruta in $rutas) {
        $i++
        Write-ProgressBar -Percent ([math]::Round($i / $rutas.Count * 100)) -Activity "Procesando temporales..."
        if (Test-Path $ruta) {
            $antes = Get-TamanoCarpeta $ruta
            Get-ChildItem -Path $ruta -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
            $despues = Get-TamanoCarpeta $ruta
            $diff = $antes - $despues
            $liberado += $diff
            Write-OK "$(Split-Path $ruta -Leaf): liberado $(Format-Tamano $diff)"
            Log-Accion "Temporales ($ruta): liberado $diff MB"
        }
    }
    Write-ProgressBar -Percent 100 -Activity "Procesando temporales..."

    $script:totalLiberado += $liberado
    $script:resultados += [PSCustomObject]@{ Tarea = "Temporales"; LiberadoMB = $liberado }
    Write-Info "Total temporales: $(Format-Tamano $liberado) liberados"
}

function Vaciar-Papelera {
    Write-Separador
    Write-Step "Vaciando la Papelera de reciclaje..."

    try {
        $shell = New-Object -ComObject Shell.Application
        $papelera = $shell.Namespace(0xA)
        $antes = ($papelera.Items() | Measure-Object -Property Size -Sum -ErrorAction SilentlyContinue).Sum
        $antesMB = [math]::Round($antes / 1MB, 2)
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Write-OK "Papelera vaciada - aprox. $(Format-Tamano $antesMB) eliminados"
        $script:totalLiberado += $antesMB
        $script:resultados += [PSCustomObject]@{ Tarea = "Papelera"; LiberadoMB = $antesMB }
        Log-Accion "Papelera vaciada: ~$antesMB MB"
    }
    catch {
        Write-Warn "No se pudo calcular el tamano de la papelera, pero fue vaciada"
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
        Log-Accion "Papelera vaciada (tamano no calculado)"
    }
}

function Limpiar-WindowsUpdate {
    Write-Separador
    Write-Step "Limpiando cache de Windows Update..."
    Write-Warn "Se detendran temporalmente los servicios de actualizacion..."

    $servicios = @("wuauserv", "bits", "cryptsvc", "msiserver")
    $liberado = 0

    try {
        foreach ($svc in $servicios) {
            Stop-Service -Name $svc -Force -ErrorAction SilentlyContinue
            Write-Info "Servicio detenido: $svc"
        }

        $ruta = "C:\Windows\SoftwareDistribution\Download"
        $antes = Get-TamanoCarpeta $ruta
        Remove-Item "$ruta\\*" -Recurse -Force -ErrorAction SilentlyContinue
        $liberado = $antes - (Get-TamanoCarpeta $ruta)

        Write-OK "Cache de Windows Update: $(Format-Tamano $liberado) liberados"
        Log-Accion "WU Cache: $liberado MB liberados"
    }
    catch [System.ServiceProcess.ServiceControllerException] {
        Write-Warn "No se pudieron detener algunos servicios de Windows Update"
        Log-Accion "ERROR WU Servicios: $($_.Exception.Message)"
    }
    catch {
        Write-Warn "Error inesperado en Windows Update: $($_.Exception.Message)"
        Log-Accion "ERROR WU: $($_.Exception.Message)"
    }
    finally {
        foreach ($svc in $servicios) {
            Start-Service -Name $svc -ErrorAction SilentlyContinue
        }
        Write-Info "Servicios de actualizacion reiniciados"
    }

    $script:totalLiberado += $liberado
    $script:resultados += [PSCustomObject]@{ Tarea = "Windows Update"; LiberadoMB = $liberado }
}

function Limpiar-Miniaturas {
    Write-Separador
    Write-Step "Eliminando cache de miniaturas..."

    $ruta = "$env:USERPROFILE\AppData\Local\Microsoft\Windows\Explorer"
    $antes = Get-TamanoCarpeta $ruta

    Get-ChildItem -Path $ruta -Filter "thumbcache_*.db" -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue

    $liberado = $antes - (Get-TamanoCarpeta $ruta)
    $script:totalLiberado += $liberado
    $script:resultados += [PSCustomObject]@{ Tarea = "Miniaturas"; LiberadoMB = $liberado }

    Write-OK "Miniaturas eliminadas: $(Format-Tamano $liberado) liberados"
    Log-Accion "Miniaturas: $liberado MB"
}

function Limpiar-Prefetch {
    Write-Separador
    Write-Step "Limpiando carpeta Prefetch..."

    $ruta = "C:\Windows\Prefetch"
    $antes = Get-TamanoCarpeta $ruta
    Get-ChildItem -Path $ruta -Force -ErrorAction SilentlyContinue |
        Remove-Item -Force -ErrorAction SilentlyContinue
    $liberado = $antes - (Get-TamanoCarpeta $ruta)
    $script:totalLiberado += $liberado
    $script:resultados += [PSCustomObject]@{ Tarea = "Prefetch"; LiberadoMB = $liberado }

    Write-OK "Prefetch limpiado: $(Format-Tamano $liberado) liberados"
    Log-Accion "Prefetch: $liberado MB"
}

function Limpiar-Dumps {
    Write-Separador
    Write-Step "Eliminando archivos de volcado del sistema..."

    $rutas = @(
        "C:\Windows\Minidump",
        "C:\Windows\memory.dmp",
        "$env:LOCALAPPDATA\CrashDumps"
    )

    $liberado = 0
    foreach ($ruta in $rutas) {
        if (Test-Path $ruta) {
            $item = Get-Item $ruta -ErrorAction SilentlyContinue
            $antes = 0
            if ($item.PSIsContainer) {
                $antes = Get-TamanoCarpeta $ruta
            } else {
                $antes = [math]::Round($item.Length / 1MB, 2)
            }
            Remove-Item $ruta -Recurse -Force -ErrorAction SilentlyContinue
            $liberado += $antes
        }
    }

    $script:totalLiberado += $liberado
    $script:resultados += [PSCustomObject]@{ Tarea = "Dumps"; LiberadoMB = $liberado }
    Write-OK "Archivos dump eliminados: $(Format-Tamano $liberado) liberados"
    Log-Accion "Dumps: $liberado MB"
}

function Ejecutar-DiskCleanup {
    Write-Separador
    Write-Step "Ejecutando Liberador de espacio en disco (cleanmgr)..."
    Write-Info "Esto puede tardar unos segundos..."

    Backup-Registro

    $sageset = 65535
    $regPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"

    Get-ChildItem $regPath -ErrorAction SilentlyContinue | ForEach-Object {
        Set-ItemProperty -Path $_.PsPath -Name "StateFlags$sageset" -Value 2 -ErrorAction SilentlyContinue
    }

    Start-Process cleanmgr -ArgumentList "/sagerun:$sageset" -Wait -ErrorAction SilentlyContinue
    Write-OK "Liberador de espacio completado"
    Log-Accion "Disk Cleanup ejecutado"
    $script:resultados += [PSCustomObject]@{ Tarea = "Disk Cleanup"; LiberadoMB = 0 }
}

function Limpiar-LogsEventos {
    Write-Separador
    Write-Step "Limpiando logs de eventos antiguos (mas de 30 dias)..."

    $limite = (Get-Date).AddDays(-30)
    $liberado = 0
    try {
        $logs = wevtutil el | ForEach-Object {
            $info = wevtutil gli "$_"
            $tamanoLinea = $info | Where-Object { $_ -match "size=" }
            if ($tamanoLinea) {
                $tamanoBytes = [int]($tamanoLinea -replace "size=", "").Trim()
                [PSCustomObject]@{
                    Nombre = $_
                    TamanoMB = [math]::Round($tamanoBytes / 1MB, 2)
                }
            }
        }

        foreach ($log in $logs | Where-Object { $_.TamanoMB -gt 50 }) {
            try {
                wevtutil cl "$($log.Nombre)" 2>$null
                Write-OK "Log limpiado: $($log.Nombre) ($(Format-Tamano $log.TamanoMB))"
                $liberado += $log.TamanoMB
            } catch {
                Write-Warn "No se pudo limpiar: $($log.Nombre)"
            }
        }
    } catch {
        Write-Warn "No se pudo acceder a los logs de eventos"
    }

    $script:totalLiberado += $liberado
    $script:resultados += [PSCustomObject]@{ Tarea = "Logs Eventos"; LiberadoMB = $liberado }
    Write-Info "Total logs: $(Format-Tamano $liberado) liberados"
    Log-Accion "Logs eventos: $liberado MB"
}

function Limpiar-CacheNavegadores {
    Write-Separador
    Write-Step "Limpiando cache de navegadores..."

    $rutasNavegadores = @{
        "Chrome"  = "$env:LOCALAPPDATA\Google\Chrome\User Data\Default\Cache"
        "Edge"    = "$env:LOCALAPPDATA\Microsoft\Edge\User Data\Default\Cache"
        "Firefox" = "$env:LOCALAPPDATA\Mozilla\Firefox\Profiles"
    }

    $liberado = 0
    foreach ($navegador in $rutasNavegadores.GetEnumerator()) {
        if (Test-Path $navegador.Value) {
            $antes = 0
            if ($navegador.Key -eq "Firefox") {
                $perfiles = Get-ChildItem $navegador.Value -Directory -ErrorAction SilentlyContinue
                foreach ($perfil in $perfiles) {
                    $cachePath = Join-Path $perfil.FullName "cache2"
                    if (Test-Path $cachePath) {
                        $antes += Get-TamanoCarpeta $cachePath
                        Remove-Item "$cachePath\\*" -Recurse -Force -ErrorAction SilentlyContinue
                    }
                }
            } else {
                $antes = Get-TamanoCarpeta $navegador.Value
                Remove-Item "$($navegador.Value)\\*" -Recurse -Force -ErrorAction SilentlyContinue
            }
            $despues = Get-TamanoCarpeta $navegador.Value
            $diff = $antes - $despues
            $liberado += $diff
            Write-OK "$($navegador.Key): $(Format-Tamano $diff) liberados"
            Log-Accion "Cache $($navegador.Key): $diff MB"
        }
    }

    $script:totalLiberado += $liberado
    $script:resultados += [PSCustomObject]@{ Tarea = "Cache Navegadores"; LiberadoMB = $liberado }
    Write-Info "Total navegadores: $(Format-Tamano $liberado) liberados"
}

function Optimizar-Disco {
    Write-Separador
    Write-Step "Optimizando discos (Defrag / TRIM segun tipo de disco)..."

    $discos = Get-Volume | Where-Object { $_.DriveLetter -and $_.FileSystem -eq "NTFS" }
    $i = 0
    foreach ($disco in $discos) {
        $i++
        Write-ProgressBar -Percent ([math]::Round($i / $discos.Count * 100)) -Activity "Optimizando discos..."
        Write-Info "Optimizando unidad $($disco.DriveLetter):\\"
        Optimize-Volume -DriveLetter $disco.DriveLetter -ReTrim -ErrorAction SilentlyContinue
        Write-OK "Unidad $($disco.DriveLetter): optimizada"
        Log-Accion "Disco $($disco.DriveLetter) optimizado"
    }
    Write-ProgressBar -Percent 100 -Activity "Optimizando discos..."
    $script:resultados += [PSCustomObject]@{ Tarea = "Optimizacion"; LiberadoMB = 0 }
}

function Reparar-Archivos {
    Write-Separador
    Write-Step "Verificando integridad de archivos del sistema (SFC)..."
    Write-Warn "Este proceso puede tardar varios minutos..."

    # Ejecutar SFC mostrando salida en tiempo real
    $sfcProc = Start-Process -FilePath "sfc.exe" -ArgumentList "/scannow" `
        -NoNewWindow -Wait -PassThru
	
	$sfcMsg = switch ($sfcProc.ExitCode) {
    0 { "No se encontraron infracciones de integridad." }
    1 { "Se encontraron archivos corruptos pero no se pudieron reparar." }
    2 { "Se encontraron archivos corruptos y fueron reparados correctamente." }
    default { "Resultado desconocido (codigo: $($sfcProc.ExitCode))." }
}
	
    Write-OK "SFC completado (codigo de salida: $($sfcProc.ExitCode))"
	Write-OK "SFC: $sfcMsg"
	Log-Accion "SFC: $sfcMsg"
    Log-Accion "SFC ejecutado - ExitCode: $($sfcProc.ExitCode)"

    Write-Step "Verificando imagen del sistema con DISM..."

    # Ejecutar DISM mostrando salida en tiempo real
    $dismProc = Start-Process -FilePath "DISM.exe" `
        -ArgumentList "/Online /Cleanup-Image /RestoreHealth" `
        -NoNewWindow -Wait -PassThru
		
	$dismMsg = switch ($dismProc.ExitCode) {
    0       { "La imagen del sistema es correcta o fue reparada." }
    -2146498530 { "No se pudo conectar a Windows Update para reparar la imagen." }
    87      { "Parametro no valido." }
    1726    { "El procedimiento remoto fallo (posible problema de red)." }
    default { "Resultado desconocido (codigo: $($dismProc.ExitCode))." }
}
	
    Write-OK "DISM completado (codigo de salida: $($dismProc.ExitCode))"
	Write-OK "DISM: $dismMsg"
	Log-Accion "DISM: $dismMsg"
    Log-Accion "DISM ejecutado - ExitCode: $($dismProc.ExitCode)"

    $script:resultados += [PSCustomObject]@{ Tarea = "SFC+DISM"; LiberadoMB = 0 }
}

function Mostrar-ProgramasInicio {
    Write-Separador
    Write-Step "Programas configurados para iniciar con Windows:"

    $startupItems = Get-CimInstance Win32_StartupCommand -ErrorAction SilentlyContinue |
        Select-Object Name, Command, Location, User

    if ($startupItems) {
        $startupItems | ForEach-Object {
            Write-Info "$($_.Name) -> $($_.Command)"
        }
        Log-Accion "Programas de inicio listados: $($startupItems.Count)"
    } else {
        Write-OK "No se encontraron programas de inicio adicionales"
    }
    $script:resultados += [PSCustomObject]@{ Tarea = "Programas Inicio"; LiberadoMB = 0 }
}

function Verificar-SaludDisco {
    Write-Separador
    Write-Step "Verificando estado SMART de los discos..."

    try {
        $discos = Get-PhysicalDisk | Where-Object { $_.MediaType -eq 'HDD' -or $_.MediaType -eq 'SSD' }
        foreach ($disco in $discos) {
            $salud = $disco.HealthStatus
            $operational = $disco.OperationalStatus
            $color = if ($salud -eq 'Healthy') { "Green" } else { "Red" }
            Write-Host "  Disco $($disco.FriendlyName): Estado=$salud, Operativo=$operational" -ForegroundColor $color
            Log-Accion "Disco $($disco.DeviceId): Salud=$salud"
        }
    } catch {
        Write-Warn "No se pudo obtener informacion SMART. Requiere PowerShell 5.1+ o modulo Storage."
    }
    $script:resultados += [PSCustomObject]@{ Tarea = "SMART"; LiberadoMB = 0 }
}

function Optimizar-Memoria {
    Write-Separador
    Write-Step "Analizando y optimizando memoria RAM..."

    # Estado actual
    $os    = Get-CimInstance Win32_OperatingSystem
    $total = [math]::Round($os.TotalVisibleMemorySize / 1MB, 2)
    $libre = [math]::Round($os.FreePhysicalMemory / 1MB, 2)
    Write-Info "Antes — Libre: $libre GB de $total GB"

    # Compactar Working Set de procesos en segundo plano
    Add-Type @"
using System;
using System.Runtime.InteropServices;
public class MemAPI {
    [DllImport("kernel32.dll")]
    public static extern bool SetProcessWorkingSetSize(IntPtr proc, int min, int max);
}
"@
    Get-Process | Where-Object { $_.MainWindowHandle -eq 0 -and $_.WorkingSet64 -gt 50MB } |
        ForEach-Object {
            try { [MemAPI]::SetProcessWorkingSetSize($_.Handle, -1, -1) | Out-Null } catch {}
        }

    # Vaciar standby memory con RAMMap si está disponible
    $rammap = "$env:TEMP\RAMMap.exe"
    if (-not (Test-Path $rammap)) {
        Invoke-WebRequest "https://live.sysinternals.com/RAMMap.exe" -OutFile $rammap -ErrorAction SilentlyContinue
    }
    if (Test-Path $rammap) {
        Start-Process $rammap -ArgumentList "-Ew" -Wait
        Write-OK "Standby memory vaciada"
    } else {
        Write-Warn "RAMMap no disponible, se omite el vaciado de standby"
    }

    $librePost = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 2)
    Write-OK "Despues — Libre: $librePost GB de $total GB"
    Log-Accion "Memoria optimizada: $libre GB -> $librePost GB libres"
    $script:resultados += [PSCustomObject]@{ Tarea = "Memoria"; LiberadoMB = 0 }
}


function Mostrar-EspacioDisco {
    Write-Separador
    Write-Step "Estado actual de los discos:"

    Get-PSDrive -PSProvider FileSystem -ErrorAction SilentlyContinue |
        Where-Object { $_.Used -gt 0 } |
        ForEach-Object {
            $total = [math]::Round(($_.Used + $_.Free) / 1GB, 1)
            $usado = [math]::Round($_.Used / 1GB, 1)
            $libre = [math]::Round($_.Free / 1GB, 1)
            $pct   = [math]::Round($_.Used / ($_.Used + $_.Free) * 100, 0)
            $barras = [math]::Round($pct / 5)
            $barra = ("#" * $barras) + ("-" * (20 - $barras))
            $color = if ($pct -gt 85) { "Red" } elseif ($pct -gt 70) { "Yellow" } else { "Green" }
            Write-Host "  [$($_.Name):] [$barra] $pct% - Usado: $usado GB / Total: $total GB (Libre: $libre GB)" -ForegroundColor $color
        }
}

function Exportar-Resultados {
    $csvPath = "$env:C:\logs\Mantenimiento_$(Get-Date -Format 'yyyyMMdd_HHmmss').csv"
    $script:resultados | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8
    Write-OK "Resultados exportados a CSV: $csvPath"
    Log-Accion "CSV exportado: $csvPath"
}

function Enviar-Informe {
    param([string]$Destinatario)
    if (-not $Destinatario) { return }

    $asunto = "Informe de Mantenimiento - $env:COMPUTERNAME - $(Get-Date -Format 'yyyy-MM-dd')"
    $cuerpo = @"
Informe de Mantenimiento del Sistema
====================================
Equipo: $env:COMPUTERNAME
Usuario: $env:USERNAME
Fecha: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')
Version Script: $version

Espacio total liberado: $(Format-Tamano $totalLiberado)

Resumen por tarea:
$($script:resultados | Format-Table -AutoSize | Out-String)

Log completo adjunto.
"@

    try {
        $smtpServer = Read-Host "Introduce el servidor SMTP"
        $from = "mantenimiento@tuempresa.com"
        Send-MailMessage -To $Destinatario -From $from -Subject $asunto -Body $cuerpo -SmtpServer $smtpServer -Attachments $logFile
        Write-OK "Informe enviado a $Destinatario"
        Log-Accion "Informe enviado a $Destinatario"
    } catch {
        Write-Warn "No se pudo enviar el informe por email: $($_.Exception.Message)"
    }
}

function Mostrar-Menu {
    Write-Header
    Mostrar-EspacioDisco
    Write-Host ""
    Write-Host "  Selecciona las tareas a ejecutar:" -ForegroundColor White
    Write-Host ""
    Write-Host "  [1]  Limpiar archivos temporales" -ForegroundColor Cyan
    Write-Host "  [2]  Vaciar Papelera de reciclaje" -ForegroundColor Cyan
    Write-Host "  [3]  Limpiar cache de Windows Update" -ForegroundColor Cyan
    Write-Host "  [4]  Eliminar cache de miniaturas" -ForegroundColor Cyan
    Write-Host "  [5]  Limpiar carpeta Prefetch" -ForegroundColor Cyan
    Write-Host "  [6]  Eliminar archivos de volcado (dumps)" -ForegroundColor Cyan
    Write-Host "  [7]  Ejecutar Liberador de espacio (cleanmgr)" -ForegroundColor Cyan
    Write-Host "  [8]  Limpiar logs de eventos antiguos" -ForegroundColor Cyan
    Write-Host "  [9]  Limpiar cache de navegadores" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [10] Optimizar discos (Defrag/TRIM)" -ForegroundColor Cyan
	Write-Host ""
    Write-Host "  [11] Verificar integridad del sistema (SFC + DISM)" -ForegroundColor Cyan
    Write-Host "  [12] Ver programas de inicio" -ForegroundColor Cyan
    Write-Host "  [13] Verificar salud SMART de discos" -ForegroundColor Cyan
	Write-Host "  [14] Optimizar memoria RAM" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  [A]  EJECUTAR LIMPIEZA COMPLETA (1-9)" -ForegroundColor Green
    Write-Host "  [E]  Exportar resultados a CSV" -ForegroundColor Magenta
    Write-Host "  [S]  Salir" -ForegroundColor DarkGray
	Write-Host ""
	Write-Host ""
	Write-Host "  LOS LOGS SE GUARDAN EN  C:\logs" -ForegroundColor Red
    Write-Host ""
}

# ============================================
# MODO SILENCIOSO / AUTOMATIZADO
# ============================================
if ($Silent -and $Full) {
    Write-Info "Modo silencioso activado. Ejecutando limpieza completa..."
    Test-EspacioSuficiente | Out-Null
    Limpiar-Temporales
    Vaciar-Papelera
    Limpiar-WindowsUpdate
    Limpiar-Miniaturas
    Limpiar-Prefetch
    Limpiar-Dumps
    Ejecutar-DiskCleanup
    Limpiar-LogsEventos
    Limpiar-CacheNavegadores
    Optimizar-Disco
    Exportar-Resultados
    if ($EmailTo) { Enviar-Informe -Destinatario $EmailTo }
    Stop-Transcript | Out-Null
    exit
}

# ============================================
# MODO INTERACTIVO
# ============================================
Log-Accion "=== INICIO DE MANTENIMIENTO ==="

do {
    Mostrar-Menu
    $opcion = Read-Host "  Tu eleccion"

    switch ($opcion.ToUpper()) {
        "1"  { Limpiar-Temporales }
        "2"  { Vaciar-Papelera }
        "3"  { Limpiar-WindowsUpdate }
        "4"  { Limpiar-Miniaturas }
        "5"  { Limpiar-Prefetch }
        "6"  { Limpiar-Dumps }
        "7"  { Ejecutar-DiskCleanup }
        "8"  { Limpiar-LogsEventos }
        "9"  { Limpiar-CacheNavegadores }
        "10" { Optimizar-Disco }
        "11" { Reparar-Archivos }
        "12" { Mostrar-ProgramasInicio }
        "13" { Verificar-SaludDisco }
		"14" {Optimizar-Memoria}
        "A"  {
            Test-EspacioSuficiente | Out-Null
            Limpiar-Temporales
            Vaciar-Papelera
            Limpiar-WindowsUpdate
            Limpiar-Miniaturas
            Limpiar-Prefetch
            Limpiar-Dumps
            Ejecutar-DiskCleanup
            Limpiar-LogsEventos
            Limpiar-CacheNavegadores
        }
        "E"  { Exportar-Resultados }
        "S"  {
            Write-Separador
            Write-Host ""
            Write-Host "  Mantenimiento finalizado." -ForegroundColor Green
            Write-Host "  Espacio total liberado: $(Format-Tamano $totalLiberado)" -ForegroundColor Yellow
            Write-Host "  Log guardado en: $logFile" -ForegroundColor Gray
            Write-Host "  Transcripcion en: $transcriptFile" -ForegroundColor Gray
            Write-Host ""
            Log-Accion "=== FIN - Total liberado: $totalLiberado MB ==="
            Exportar-Resultados
            if ($EmailTo) { Enviar-Informe -Destinatario $EmailTo }
            Stop-Transcript | Out-Null
        }
        default { Write-Warn "Opcion no valida. Intenta de nuevo." }
    }

    if ($opcion.ToUpper() -ne "S") {
        Write-Host ""
        Write-Host "  Presiona ENTER para volver al menu..." -ForegroundColor DarkGray
        Read-Host
    }

} while ($opcion.ToUpper() -ne "S")



