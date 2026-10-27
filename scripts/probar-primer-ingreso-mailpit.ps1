<#
.SYNOPSIS
  Prueba de punta a punta de RF-02 contra un backend local con MAIL_PROVIDER=smtp y Mailpit.

.DESCRIPTION
  1. POST /solicitar (HTTP aceptado).
  2. Espera el correo en Mailpit (proveedor SMTP acepto y entrego a la bandeja simulada).
  3. Verifica que el enlace tenga la forma <FIRST_LOGIN_URL>?token=... (Flutter web, con #/).
  4. POST /completar con el token del correo (cuenta activada).
  5. POST /login con la contrasena nueva (login satisfactorio).

  Usa solo datos ficticios y Mailpit; nunca imprime el token completo.
  Requisitos: backend en $BaseUrl, Mailpit en $MailpitUrl, cuenta pendiente cargada con
  database/pruebas/datos_primer_ingreso_local.sql.
#>
param(
    [string]$BaseUrl = 'http://localhost:8080',
    [string]$MailpitUrl = 'http://localhost:8025',
    [string]$Ci = '40000018',
    [ValidateSet('SOCIO', 'EMPLEADO')][string]$Acceso = 'SOCIO',
    [string]$Password = 'Clave-Local-Mailpit-1',
    [string]$EnlaceEsperado = '#/primer-ingreso?token='
)

$ErrorActionPreference = 'Stop'
$json = 'application/json'

function Paso($texto) { Write-Host "[ok] $texto" -ForegroundColor Green }

Invoke-RestMethod -Method Delete -Uri "$MailpitUrl/api/v1/messages" | Out-Null

$solicitud = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$BaseUrl/api/auth/primer-ingreso/solicitar" `
    -ContentType $json -Body (@{ ci = $Ci; acceso = $Acceso } | ConvertTo-Json)
if ($solicitud.StatusCode -ne 202) { throw "Se esperaba 202 y llego $($solicitud.StatusCode)" }
Paso '1. Solicitud HTTP aceptada (202). Todavia NO prueba que el correo salio.'

$mensaje = $null
for ($i = 0; $i -lt 20 -and -not $mensaje; $i++) {
    Start-Sleep -Milliseconds 500
    $lista = Invoke-RestMethod -Uri "$MailpitUrl/api/v1/messages"
    if ($lista.messages_count -gt 0) { $mensaje = $lista.messages[0] }
}
if (-not $mensaje) { throw 'Mailpit no recibio ningun correo en 10 s (revisar MAIL_PROVIDER=smtp y el log del backend).' }
Paso "2. Mailpit recibio el correo '$($mensaje.Subject)' para $($mensaje.To[0].Address)."

$detalle = Invoke-RestMethod -Uri "$MailpitUrl/api/v1/message/$($mensaje.ID)"
$patron = [regex]::Escape($EnlaceEsperado) + '([A-Za-z0-9_-]{43,})'
$coincidencia = [regex]::Match($detalle.Text, $patron)
if (-not $coincidencia.Success) { throw "El correo no contiene un enlace con '$EnlaceEsperado<token>'." }
$token = $coincidencia.Groups[1].Value
$enlace = ($detalle.Text -split '\s+' | Where-Object { $_ -like "*$EnlaceEsperado*" } | Select-Object -First 1)
Paso "3. Enlace con forma correcta: $($enlace.Substring(0, $enlace.IndexOf('token=') + 6))$($token.Substring(0, 6))... (token truncado)"

$completar = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$BaseUrl/api/auth/primer-ingreso/completar" -ContentType $json `
    -Body (@{ token = $token; direccion = 'Calle Ficticia 123'; telefono1 = '099000000'; telefono2 = $null; password = $Password } | ConvertTo-Json)
if ($completar.StatusCode -ne 200) { throw "Completar devolvio $($completar.StatusCode)" }
Paso "4. Cuenta activada: $($completar.Content)"

try {
    Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$BaseUrl/api/auth/primer-ingreso/completar" -ContentType $json `
        -Body (@{ token = $token; direccion = 'x'; telefono1 = '1'; password = $Password } | ConvertTo-Json) | Out-Null
    throw 'El enlace se pudo usar dos veces'
} catch {
    if (-not $_.Exception.Response -or [int]$_.Exception.Response.StatusCode -ne 400) { throw }
    Paso '5. Reutilizar el enlace da 400 ENLACE_INVALIDO.'
}

$login = Invoke-WebRequest -UseBasicParsing -Method Post -Uri "$BaseUrl/api/auth/login" -ContentType $json `
    -Body (@{ ci = $Ci; password = $Password; acceso = $Acceso; plataforma = 'WEB' } | ConvertTo-Json)
if ($login.StatusCode -ne 200) { throw "Login devolvio $($login.StatusCode)" }
Paso '6. Login satisfactorio con la contrasena nueva (200).'
Write-Host 'RF-02 local OK: solicitud -> correo en Mailpit -> enlace -> activacion -> login.' -ForegroundColor Cyan
