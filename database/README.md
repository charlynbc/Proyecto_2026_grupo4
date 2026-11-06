# Base de datos

El esquema se versiona como scripts SQL en esta carpeta. No usamos Flyway: los
cambios se aplican a mano, primero en la base de pruebas de Supabase y, una vez
validados, en la de producción (Documento de Arquitectura, sección 9.2).

```
database/
├── schema.sql                  esquema completo actual: tablas, restricciones e índices
├── cambios/                    un script numerado por cada cambio posterior
├── pruebas/
│   └── verificar_esquema.sql   prueba de las restricciones (la corre el CI)
└── poc-sql/                    scripts de las pruebas de concepto, no se usan
```

`schema.sql` parte del script con el que Martín creó la base `prod` en Supabase
(`crear_estructura_v1.sql`, 13/10/2026) y contiene los cambios posteriores. Implementa el Documento
de Modelo de Datos: las tablas del documento (`Persona`, `TurnoSemanal`, …) se
escriben en minúscula con guion bajo (`persona`, `turno_semanal`, …) y quedan
en el esquema `public`.

Las bases del proyecto no son la base por defecto `postgres` de Supabase sino
bases propias dentro del mismo servidor (`prod` y la de pruebas). Por eso el
panel web de Supabase no muestra sus tablas: se ven conectándose con DBeaver o
`psql` a esa base. Por la misma razón, la Data API de Supabase, que solo sirve
la base `postgres`, no las expone.

## Por qué `schema.sql` tiene que estar siempre al día

El RNF-19 exige que la estructura de la base, con sus restricciones e índices,
pueda **recrearse a partir de scripts versionados en el repositorio**. Ese
archivo es lo que lo cumple: corrido sobre una base vacía, deja el esquema
completo. El workflow `Esquema de la base` lo comprueba en cada Pull Request que
toque esta carpeta.

## Cómo hacer un cambio de esquema

1. En tu rama, creá `cambios/NNN_descripcion.sql` con el cambio, por ejemplo
   `cambios/001_agregar_indice_turno_fecha.sql`. El número es el siguiente al
   último que exista.
2. Aplicá el **mismo** cambio a `schema.sql`, para que siga describiendo la base
   completa.
3. Si el cambio agrega una regla, sumá una comprobación en
   `pruebas/verificar_esquema.sql`.
4. Abrí el Pull Request. El CI recrea la base con `schema.sql` y corre las
   pruebas.
5. Una vez aprobado, corré `cambios/NNN_*.sql` en la base de **pruebas** y,
   cuando esté validado, en la de **producción**. Avisá en el grupo, porque las
   dos bases son compartidas.

Nunca edites un script de `cambios/` que ya se aplicó en alguna base: el
siguiente cambio va en un archivo nuevo.

## Correrlo localmente

Con un PostgreSQL 17 vacío:

```bash
psql -v ON_ERROR_STOP=1 -f database/schema.sql
psql -v ON_ERROR_STOP=1 -f database/pruebas/verificar_esquema.sql
```

La prueba termina en `ROLLBACK`, así que no deja datos.

## Qué controla la base y qué controla el servicio

La base controla todo lo que se puede expresar sobre una sola fila o con un
índice: claves, unicidades (incluidos los índices únicos parciales de
RNF-13) y dominios con `CHECK`. Las reglas que dependen de varias tablas o de
la configuración las verifica el backend dentro de la transacción, como indica
la sección 5 del Modelo de Datos: los solapamientos de turnos, las duraciones
admitidas, los límites de agenda, que un médico tenga rol `MEDICO` y la
especialidad del turno y que el rol de una cuenta no cambie. En la cartelera,
el servicio exige título y al menos una imagen por anuncio.
