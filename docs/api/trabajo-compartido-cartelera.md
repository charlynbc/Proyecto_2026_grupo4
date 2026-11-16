# Cómo continuar el desarrollo de cartelera

## Estado de esta rama

La rama compartida es `feat/gestion-cartelera-backend`. Contiene el backend de
vigencia, posiciones manuales y eliminación definitiva, además de los scripts
de base. El frontend de estas funciones **no está implementado**. El detalle de
las rutas y sus cuerpos está en [Gestión de cartelera](cartelera-administracion.md).

En `desa` se aplicaron los scripts 002 y 003. Se realizó un recorrido HTTP real
con anuncios de texto: alta, cambio de posiciones, eliminación con hueco,
programación, vencimiento y recuperación de vigencia. Los datos temporales se
eliminaron. No se probó Storage real ni escritura concurrente; las pruebas
automáticas con PostgreSQL descartable siguen pendientes. **No ejecutar los
scripts otra vez en `desa`**. No se verificó ni modificó `test` para este trabajo.

Cada guardado del carrusel reemplaza toda la selección; el último procesado
prevalece. Admite hasta cinco posiciones entre 1 y 5, con huecos. Una novedad
programada o vencida conserva su posición pero no se muestra al público.
Las novedades anteriores pueden tener fin nulo; para una nueva es obligatorio.

## Preparar el entorno local

Cada integrante necesita Git, Java 25, Flutter y acceso de red al servidor de
PostgreSQL y a Supabase Storage. Puede clonar y partir de la rama compartida:

```powershell
git clone https://github.com/charlynbc/Proyecto_2026_grupo4.git
cd Proyecto_2026_grupo4
git switch -c mi-cambio-flutter --track origin/feat/gestion-cartelera-backend
```

Coordinar con Martín el acceso a `desa` y una cuenta de administrador activada.
Al terminar el recorrido de prueba, `desa` quedó sin cuentas; Martín creará la
cuenta de desarrollo por separado. Un administrador habilitado debe haber
completado el primer ingreso y tener contraseña válida para entrar desde Flutter.
El primer administrador se incorpora fuera de la aplicación; acordar con Martín
la CI y la contraseña de prueba. No usar la cuenta temporal eliminada.

En PowerShell, antes de iniciar el backend, configurar las variables en la
sesión. Solicitar las credenciales por un canal seguro y no guardarlas en Git:

```powershell
$env:DB_URL = 'jdbc:postgresql://<host>:5432/desa?sslmode=require'
$env:DB_USER = '<usuario-de-desa>'
$env:DB_PASSWORD = '<contraseña-de-desa>'
$env:JWT_SECRET_BASE64 = '<clave-base64-local-de-al-menos-32-bytes>'
$env:SUPABASE_URL = '<url-del-proyecto-supabase>'
$env:SUPABASE_SECRET_KEY = '<clave-de-storage-del-servidor>'
$env:ANUNCIOS_BUCKET = 'anuncios'
$env:MAIL_PROVIDER = 'none'
$env:APP_FIREBASE_ENABLED = 'false'
$env:CORS_ALLOWED_ORIGIN = 'http://localhost:5173'
cd backend/api
.\mvnw.cmd spring-boot:run
```

Generar una clave JWT local, por ejemplo `openssl rand -base64 32`, o pedir
una según el método del equipo. Es una clave del backend local, no de Flutter.
Las variables solo duran esa sesión de terminal. Spring Boot no lee `.env` por
sí solo. Confirmar con Martín la URL, clave y nombre del bucket: el valor
`anuncios` es el predeterminado del código; **no se verificó la configuración
actual de Railway**. Storage es opcional para anuncios solo de texto; para subir
o consultar imágenes hace falta configurarlo correctamente. El equipo aceptó
compartir el bucket con el otro entorno; las referencias copiadas entre bases
pueden apuntar al mismo archivo.

En otra terminal, desde la raíz del repositorio:

```powershell
cd frontend
flutter pub get
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8080
```

Entrar por el acceso de empleados con la cuenta administradora de `desa`.
El backend local debe quedar encendido. No usar `USE_FAKES=true`: ese modo no
consume el backend. CORS debe coincidir con el origen y puerto de Flutter.

## Qué debe implementar Flutter

1. En publicación, enviar `vigenteHasta` obligatorio y `vigenteDesde` opcional
   dentro de `datos` multipart. Usar ISO 8601 con desplazamiento y presentar
   fechas en `America/Montevideo`. El formulario actual no envía esos campos.
2. Consultar `GET /api/anuncios/carrusel` para Inicio. Mantener el listado
   completo con `GET /api/anuncios`, ordenado por fecha desde el servidor.
3. Crear la gestión para ADMINISTRADOR: listado de estados, edición de vigencia,
   selección y orden de cinco posiciones y confirmación antes de eliminar.
   El `PUT` del carrusel envía la foto completa; no hay versión ni bloqueo por
   edición anterior. Recargar el estado tras guardar.
4. Distinguir anuncio inexistente o no vigente, errores de validación y fallas
   de almacenamiento. DELETE responde 202: puede quedar limpieza pendiente.

Las rutas administrativas deben seguir protegidas por el backend además de
ocultarse en Flutter. La rama no cambia el frontend: no desplegar este backend
sobre la aplicación actual sin coordinar la compatibilidad de publicación.

## Integración posterior

Trabajar en una rama individual basada en esta rama compartida y coordinar su
integración con el equipo. Antes de pasar a otro ambiente: revisar código y CI,
consultar su esquema real, definir datos iniciales y coordinar migraciones y
despliegue de backend y frontend. Aplicar scripts en bases compartidas requiere
autorización específica. Fusionar Git no actualiza bases ni despliega servicios.
