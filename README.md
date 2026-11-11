# mantenimieentoPC


Script de PowerShell para mantenimiento, limpieza y diagnóstico básico de equipos Windows.

Permite liberar espacio en disco, eliminar archivos temporales y de caché, revisar programas de inicio, comprobar el estado de los discos y ejecutar comprobaciones de integridad del sistema.

## Autor

- **Francisco Javier Martín**
- Versión: 2.0

## Requisitos

- Windows 10 o Windows 11.
- PowerShell 5.1 o superior.
- Permisos de administrador.
- Conexión a Internet para algunas tareas, como la reparación de la imagen de Windows con DISM.

## Qué hace

El script ofrece las siguientes opciones:

| Opción | Acción |
|---|---|
| 1 | Limpia archivos temporales del sistema y del usuario |
| 2 | Vacía la Papelera de reciclaje |
| 3 | Limpia la caché de Windows Update |
| 4 | Elimina la caché de miniaturas |
| 5 | Limpia la carpeta Prefetch |
| 6 | Elimina archivos de volcado o dumps |
| 7 | Ejecuta el Liberador de espacio en disco (`cleanmgr`) |
| 8 | Limpia registros de eventos de más de 50 MB |
| 9 | Limpia la caché de Chrome, Edge y Firefox |
| 10 | Optimiza discos NTFS mediante TRIM o desfragmentación |
| 11 | Ejecuta `sfc /scannow` y `DISM /Online /Cleanup-Image /RestoreHealth` |
| 12 | Muestra los programas configurados para iniciarse con Windows |
| 13 | Comprueba el estado de salud SMART de los discos |
| 14 | Analiza y optimiza la memoria RAM |
| A | Ejecuta la limpieza completa de las opciones 1 a 9 |
| E | Exporta un resumen de resultados a CSV |
| S | Finaliza el script y guarda los resultados |

## Cómo ejecutarlo

1. Descarga el archivo `Mantenimiento-PC.ps1`.
2. Haz clic derecho sobre él y selecciona **Ejecutar con PowerShell**.
3. Si Windows pide confirmación de administrador, acéptala.
4. Selecciona una opción del menú.

También puedes ejecutarlo desde una consola de PowerShell **ejecutada como administrador**:

```powershell
Set-Location "C:\ruta\donde\esta\el\script"
.\Mantenimiento-PC.ps1
```

Si aparece un error de política de ejecución, usa:

```powershell
powershell -ExecutionPolicy Bypass -File .\Mantenimiento-PC.ps1
```

## Modo automatizado

El script admite un modo silencioso para ejecutar la limpieza completa sin menú:

```powershell
.\Mantenimiento-PC.ps1 -Silent -Full
```

Para enviar además un informe por correo electrónico:

```powershell
.\Mantenimiento-PC.ps1 -Silent -Full -EmailTo "soporte@tuempresa.com"
```

> **Nota:** el envío de correo solicita el servidor SMTP durante la ejecución y usa una dirección de remitente configurada dentro del script. Antes de usarlo en producción, revisa y adapta el remitente, el servidor SMTP y la autenticación necesaria.

## Registros y resultados

El script crea archivos en `C:\logs`:

- `Mantenimiento_AAAAAMMDD_HHMMSS.log`: registro de acciones realizadas.
- `Transcript_AAAAAMMDD_HHMMSS.txt`: transcripción completa de la sesión.
- `Mantenimiento_AAAAAMMDD_HHMMSS.csv`: resumen de tareas y espacio liberado.
- `RegBackup_AAAAAMMDD_HHMMSS.reg`: copia de seguridad de la configuración del Liberador de espacio, creada antes de ejecutar `cleanmgr`.

## Advertencias

- El script **elimina archivos temporales, cachés, miniaturas, dumps y registros de eventos antiguos**. Estas acciones no deberían borrar documentos personales, pero pueden eliminar datos útiles de diagnóstico.
- La opción **2** vacía la Papelera de reciclaje de forma permanente.
- La opción **3** detiene temporalmente servicios de Windows Update y borra la caché de descargas; después los reinicia.
- La opción **7** puede eliminar más archivos del sistema, según la configuración del Liberador de espacio en disco.
- La opción **10** puede tardar bastante en equipos con discos HDD grandes.
- La opción **11** puede tardar varios minutos y requiere conexión a Internet para reparar la imagen de Windows.
- La opción **14** descarga `RAMMap.exe` desde Sysinternals si no está disponible localmente. Revisa esta función antes de usarla en un entorno corporativo.

## Uso recomendado

- Para un mantenimiento habitual: usa la opción **A**.
- Para diagnosticar lentitud o errores del sistema: usa **11**, **12** y **13**.
- Para liberar espacio rápidamente: usa **1**, **2**, **3**, **6** y **9**.
- Para revisar el estado del equipo sin borrar nada: usa **12** y **13**.

## Licencia

Este script se proporciona tal cual, sin garantía. Úsalo bajo tu propia responsabilidad y revisa las acciones antes de ejecutarlo en equipos de producción.
