# Sistema de reserva de órdenes médicas

Proyecto de la materia **Proyecto** — Tecnólogo Informático (C.E.T.P. UTU –
UdelaR), segundo semestre de 2026. Grupo 4.

Sistema online para que pacientes reserven órdenes de consulta en una
institución de asistencia médica, con cuatro perfiles de usuario: paciente,
funcionario, médico y administrador.

---

## Mapa del repositorio

| Carpeta | Qué es | ¿Se toca? |
|---|---|---|
| `backend/api/` | **El backend del proyecto.** Java 25 + Spring Boot 4.1.1 + Maven | **Sí** |
| `frontend/` | **La app del proyecto.** Flutter, cubre web y Android | **Sí** |
| `backend/poc-springboot/` | Prueba de concepto, Spring Boot | No — archivada |
| `backend/poc-quarkus/` | Prueba de concepto, Quarkus | No — archivada |
| `backend/poc-jakarta-glassfish/` | Prueba de concepto, Jakarta EE | No — archivada |
| `database/poc-sql/` | Operaciones SQL de la prueba de concepto | No — archivada |
| `docs/poc/` | Documentación y resultados de las pruebas de concepto | Referencia |
| `scripts/` | Scripts de arranque de las pruebas de concepto | No — archivados |
| `TODOELPOC.md` | Registro completo de la prueba de concepto de backend | Referencia |

Las carpetas marcadas como archivadas son la **evidencia** del documento de
pruebas de concepto. Documentan comparaciones entre tecnologías que ya se
hicieron y no forman parte del sistema. No las borres ni les cambies las
rutas: la documentación en `docs/poc/` registra los comandos exactos que se
corrieron contra ellas.

---

## Levantar el proyecto

### Requisitos

- **JDK 25** — verificar con `java -version`
- **Flutter** — verificar con `flutter --version`
- Maven **no** hace falta: el proyecto trae el wrapper (`./mvnw`)

### 1. Configurar las variables de entorno

```bash
cp .env.example .env
```

Después abrí el `.env` y completá `JWT_SECRET_BASE64` con una clave propia,
generada con `openssl rand -base64 32`. El ejemplo configura una base
PostgreSQL local aislada; cargá su esquema con `database/schema.sql` antes de
iniciar el backend.

El `.env` está en el `.gitignore`. **Nunca lo subas.**

### 2. Levantar el backend

```bash
set -a && source .env && set +a
cd backend/api
./mvnw spring-boot:run
```

El `set -a` hace que las variables del `.env` queden exportadas para el
proceso de Java. Spring Boot no lee archivos `.env` por su cuenta.

Queda escuchando en `http://localhost:8080`.

### 3. Levantar el frontend

En **otra terminal**:

```bash
cd frontend
flutter pub get
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost:8080
```

Para correrlo en el **emulador de Android**, la dirección es distinta: el
emulador no llega al `localhost` de tu máquina, hay que usar `10.0.2.2`.

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8080
```

---

## Cómo trabajamos

**Una rama corta por funcionalidad, integrada a `main` por Pull Request.**

```bash
git checkout main
git pull
git checkout -b feat/reserva-con-numero
# ... trabajar, commitear ...
git push -u origin feat/reserva-con-numero
```

Y abrir el Pull Request contra `main` desde GitHub.

No usamos ramas de larga vida por área (`Backend`, `frontend`). Ese modelo nos
dejó tres proyectos que nunca se integraban entre sí.

El detalle completo —qué hace cada comando, el tamaño de una rama, los nombres,
cómo ver el árbol y las versiones de Java y Flutter que hacen falta— está en
**[CONTRIBUTING.md](CONTRIBUTING.md)**.

---

## API

El backend expone estos endpoints bajo `/api`:

| Método | Ruta | Qué hace |
|---|---|---|
| `POST` | `/api/auth/login` | Login con `{ci, password, acceso, plataforma}`, devuelve el JWT |
| `POST` | `/api/auth/refresh` | Renueva el JWT con la cookie |
| `POST` | `/api/auth/logout` | Cierra la sesión |
| `POST` | `/api/auth/primer-ingreso/solicitar` | Envía el enlace de activación al correo de la cuenta |
| `POST` | `/api/auth/primer-ingreso/completar` | Activa la cuenta con el enlace de un solo uso |
| `POST` | `/api/consultas` | Reserva una consulta (SOCIO) |
| `POST` | `/api/notificaciones/registro` | Registra el token de push |

El login exige `plataforma` (`WEB` o `ANDROID`) para `acceso: EMPLEADO`, y los
empleados solo pueden ingresar con `WEB`. Para `SOCIO` es opcional.

El resto de los endpoints vigentes está en
[docs/api/endpoints-usados.md](docs/api/endpoints-usados.md). Se eliminaron los
endpoints de la prueba de concepto (`/api/auth/registro`,
`/api/auth/confirmar-email`, `/api/profesionales`, `/api/reservas`,
`/api/mis-reservas`, `/api/reservas/{id}/cancelacion`) y el login
`{cedula, clave}`. Qué los reemplaza y qué queda pendiente:
[docs/api/endpoints-usados.md](docs/api/endpoints-usados.md). Configuración de
correo y Railway: [docs/api/railway-correo.md](docs/api/railway-correo.md).

Los errores vuelven siempre con la misma forma, y el `code` es el contrato
con el frontend:

```json
{ "code": "HORARIO_OCUPADO", "message": "Ese horario ya fue reservado" }
```

---

## Base de datos

El backend utiliza PostgreSQL 17 y el esquema `public`. La estructura completa
está versionada y puede recrearse a partir de
[`database/schema.sql`](database/schema.sql). Para desarrollo local se
recomienda una base aislada; no apuntes las pruebas a una base compartida o de
producción.

El esquema completo está versionado en
[`database/schema.sql`](database/schema.sql), y el CI lo prueba en cada Pull
Request que toque `database/`. Cómo se cambia el esquema está en
[`database/README.md`](database/README.md).

Los módulos POC archivados se conservan como evidencia académica y no forman
parte del backend activo. Sus endpoints y el login antiguo con
`{cedula, clave}` fueron retirados. La configuración de Railway y del correo
de primer ingreso se documenta en
[`docs/api/railway-correo.md`](docs/api/railway-correo.md).

## Imagen de despliegue

Desde la raíz del repositorio, `docker build -t proyecto-2026 .` construye
Flutter web y el backend en una única imagen. La web llama a la API mediante
rutas relativas `/api/...` y ambos servicios se publican bajo el mismo origen.
Las variables de producción se configuran en Railway; no se incluyen secretos
en la imagen ni en el repositorio.
