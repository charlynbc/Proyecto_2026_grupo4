# Cómo trabajamos en este repositorio



**Una rama corta por cada cosa, integrada a `main` por Pull Request.**

Nada se pushea directo a `main`.

---


## El ciclo, paso a paso

### 1. Partir de `main` actualizado

```bash
git checkout main
git pull
```

Si arrancás de un `main` viejo, ya nacés atrasado respecto de los demás, y ese
atraso es exactamente lo que después se convierte en conflicto.

### 2. Crear la rama

```bash
git checkout -b feat/mis-reservas
    ────────  ── ─────────────────
       │       │         │
       │       │         └── el nombre que VOS elegís
       │       │
       │       └──────────── "creá una rama nueva"
       │
       └──────────────────── "movete a"
```

Esto **no copia archivos ni duplica nada**: una rama en Git son 41 bytes. Es
instantáneo. Por eso "una rama por cada cosa" no es exagerado.

### 3. Trabajar y commitear

```bash
git add .
git commit -m "Mis reservas: listado y cancelación"
```

Commiteá las veces que quieras. La rama es por *unidad de trabajo*, no por
commit.

Cuando no entiendas qué está pasando:

```bash
git status
```

Es el comando que más vas a usar. No cambia nada, sólo te dice dónde está
parado cada archivo.

### 4. Subir la rama

```bash
git push -u origin feat/mis-reservas
```

El `-u` vincula tu rama local con la de GitHub. Después alcanza con `git push`
a secas.

### 5. Abrir el Pull Request

En GitHub te va a aparecer un botón **"Compare & pull request"**. Poné un
título claro y en la descripción contá **qué hace y por qué**, no sólo qué
archivos tocaste.

### 6. Merge y borrar la rama

Cuando alguien lo revise: botón **"Merge pull request"** y después
**"Delete branch"**. Y en tu máquina:

```bash
git checkout main
git pull
git branch -d feat/mis-reservas
```

Borrar la rama no borra commits: ya están en `main`. Borrarla es lo que te
obliga a arrancar de `main` la próxima vez, que es el punto.

---


---

## Nombres de rama

| Prefijo | Para qué | Ejemplo |
|---|---|---|
| `feat/` | funcionalidad nueva | `feat/reserva-con-numero` |
| `fix/` | arreglar algo roto | `fix/encoding-utf8-errores` |
| `docs/` | documentación | `docs/contributing` |
| `chore/` | configuración, dependencias, CI | `chore/dockerfile-backend` |

---


Lo que **no** puede pasar es que un PR quede abierto una semana. Un PR que se
pudre enseña lo contrario de lo que queremos.

Si el PR toca código de otra persona, avisale por el grupo.

---

## Ver el árbol de ramas

Entender esto es mucho más fácil viéndolo dibujado que imaginándolo.

- **Sin instalar nada:** en GitHub, pestaña **Insights → Network**. Ahí se ve
  el árbol del proyecto. Es la mejor para mirar entre todos.
- **IntelliJ IDEA** (gratis la Community Edition): panel inferior, pestaña
  **Git → Log**. Viene integrado y es la mejor vista de las tres.
- **VS Code o Cursor:** instalar la extensión **Git Graph** de mhutchie.

---

## Levantar el proyecto

Está en el [README](README.md). Resumen:

```bash
cp .env.example .env     # completar DB_PASSWORD y JWT_SECRET_BASE64
set -a && source .env && set +a
cd backend/api && ./mvnw spring-boot:run
```

Y en otra terminal:

```bash
cd frontend
flutter run -d chrome --web-port=5173 --dart-define=API_BASE_URL=http://localhost:8080
```

El `--web-port=5173` **no es opcional**: sin él Flutter elige un puerto al azar,
no coincide con el `CORS_ALLOWED_ORIGIN` y el navegador bloquea todas las
respuestas.

---

## Lo que nunca va al repositorio

- El archivo `.env` (está en el `.gitignore`)
- Las credenciales de Firebase (`*firebase-adminsdk*.json`)
- Contraseñas en documentos compartidos: **se piden por el chat del grupo**
- Carpetas de compilación: `target/`, `build/`, `.dart_tool/`

---

## Todavía no está, pero viene

- **Integración continua** en cada Pull Request: va a compilar el backend,
  correr los tests y verificar las migraciones contra una base limpia. Cuando
  esté, los PRs van a mostrar los checks en verde o en rojo.
- **Protección de `main`**: GitHub va a pasar a *exigir* el Pull Request en vez
  de que sea un acuerdo.
- **Migraciones versionadas** con Flyway, para que el esquema de la base deje
  de vivir fuera del repositorio.
