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

Después abrí el `.env` y completá:

- `DB_PASSWORD` — la contraseña de la base, se pide por el chat del grupo
- `JWT_SECRET_BASE64` — generá la tuya con `openssl rand -base64 32`

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
| `POST` | `/api/auth/registro` | Alta de usuario |
| `POST` | `/api/auth/login` | Login, devuelve el JWT |
| `POST` | `/api/auth/refresh` | Renueva el JWT con la cookie |
| `POST` | `/api/auth/logout` | Cierra la sesión |
| `GET` | `/api/profesionales` | Lista de profesionales |
| `GET` | `/api/profesionales/{id}/horarios` | Horarios libres, con `desde` y `hasta` |
| `POST` | `/api/reservas` | Crea una reserva |
| `GET` | `/api/mis-reservas` | Historial de reservas del usuario |
| `PATCH` | `/api/reservas/{id}/cancelacion` | Cancela una reserva |
| `POST` | `/api/notificaciones/registro` | Registra el token de push |

Los errores vuelven siempre con la misma forma, y el `code` es el contrato
con el frontend:

```json
{ "code": "HORARIO_OCUPADO", "message": "Ese horario ya fue reservado" }
```

---

## Base de datos

PostgreSQL 17 alojado en Supabase (proyecto AgendaMedica, São Paulo), con dos
bases: `test` para desarrollar y `prod` para el despliegue. Las tablas están en
el esquema `public`.

El esquema completo está versionado en
[`database/schema.sql`](database/schema.sql), y el CI lo prueba en cada Pull
Request que toque `database/`. Cómo se cambia el esquema está en
[`database/README.md`](database/README.md).

> **Pendiente:** los endpoints heredados de la prueba de concepto
> (`/api/reservas`, `/api/profesionales`, `/api/mis-reservas`,
> `/api/auth/registro` y el login con `cedula`/`clave`) todavía consultan el
> esquema `"POC"`, que no existe en las bases `test` y `prod`.
