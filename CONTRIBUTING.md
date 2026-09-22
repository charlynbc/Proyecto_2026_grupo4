# Cómo trabajamos en este repositorio

Documento corto. Si tenés una duda que no está acá, preguntá en el grupo y la
agregamos.

---

## La regla de oro

**Una rama corta por cada cosa, integrada a `main` por Pull Request.**

Nada se pushea directo a `main`.

---

## Por qué

Hasta el 20/09 usábamos una rama de larga vida por área: `Backend`, `frontend`,
`poc/`. El resultado fue que `main` estuvo **dos semanas con un README de 22
bytes** mientras el equipo acumulaba 18 commits de trabajo real en ramas que
nunca volvían.

El proyecto no existía integrado en ningún lado. Existía como tres versiones
privadas, y para probar el login completo alguien tenía que bajarse dos ramas
distintas y compilarlas a mano.

La razón de fondo es simple:

> **El costo de integrar dos ramas crece con el tiempo que estuvieron
> separadas.**

Dos ramas separadas ayer tienen un día de cambios que reconciliar. Dos ramas
separadas hace un mes tienen un mes, y encima nadie se acuerda de por qué hizo
lo que hizo. Integrar seguido hace que ese costo nunca se acumule.

Cuando juntamos las tres ramas no hubo ningún conflicto, pero fue **suerte**:
cada uno trabajaba en una carpeta distinta. A partir del 12/10, con siete
personas sobre el mismo modelo de dominio, esa suerte se termina.

---

## Antes de empezar: versiones

Esto ya nos mordió dos veces. Si el proyecto no te compila, mirá acá primero.

| Herramienta | Versión | Verificar con |
|---|---|---|
| **Java** | **25** | `java -version` |
| Maven | no hace falta instalarlo, usamos `./mvnw` | — |
| **Flutter** | la que traiga **Dart 3.13.3 o superior** | `flutter --version` |

**Si Java te da `release version 25 not supported`:**

```bash
brew install --cask temurin@25
```

Y si tenés `JAVA_HOME` fijado en el `.zshrc`, cambiá el `21` por `25`.

**Si Flutter te da `requires SDK version ^3.13.3`:**

```bash
flutter upgrade
```

> **Pendiente de acordar:** todavía no fijamos una versión exacta de Flutter
> como sí hicimos con Java 25. Hay que definirla y anotarla acá.

---

## Los cuatro lugares donde vive tu trabajo

Casi toda la confusión con Git viene de no tener claro este mapa:

```
   Tus archivos            lo que ves en el editor
        |
        |  git add         elegís qué entra en el próximo commit
        v
   Zona de preparación
        |
        |  git commit      lo guardás en tu máquina (nadie más lo ve)
        v
   Repositorio local
        |
        |  git push        recién ahora existe para los demás
        v
   GitHub
```

Y `git pull` hace el camino inverso: trae lo que hay en GitHub a tu máquina.

Lo que más confunde al principio: **`commit` y `push` son dos cosas
distintas.** Podés commitear todas las veces que quieras sin que nadie se
entere. Recién el `push` lo hace público.

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

## Tamaño de una rama

**Algo que puedas describir en una frase sin usar "y".**

Si una rama lleva más de una semana abierta, probablemente eran dos ramas.

Un PR chico se revisa de verdad. Uno de 2.000 líneas nadie lo lee: le dan
aprobar y listo. El PR grande *parece* revisado y no lo está.

---

## Nombres de rama

| Prefijo | Para qué | Ejemplo |
|---|---|---|
| `feat/` | funcionalidad nueva | `feat/reserva-con-numero` |
| `fix/` | arreglar algo roto | `fix/encoding-utf8-errores` |
| `docs/` | documentación | `docs/contributing` |
| `chore/` | configuración, dependencias, CI | `chore/dockerfile-backend` |

---

## Sobre las revisiones

**Que sean livianas.** Dos minutos de mirada, no una auditoría. Somos siete
estudiantes con trabajo en paralelo, no un equipo de producción.

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
