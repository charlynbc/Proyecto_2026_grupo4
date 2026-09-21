
# SQL utilizado para la POC Backend

Estas consultas provienen del trabajo previo de POC de base de datos.

El objetivo es utilizarlas como referencia para implementar las operaciones
correspondientes desde Java.

## Operaciones disponibles

01_usuario_alta.sql

Alta de usuario.


02_login_buscar_usuario.sql

Busca un usuario por cédula para realizar la validación del login.


03_profesional_listar.sql

Listado de profesionales.


04_profesional_alta.sql

Alta de profesional.


05_profesional_modificar.sql

Modificación de profesional.


06_profesional_baja.sql

Eliminación de profesional.


07_horario_alta.sql

Creación de horarios.


08_horarios_disponibles.sql

Consulta horarios futuros que todavía no tienen una reserva activa.


09_reserva_alta.sql

Crea una reserva.


10_reserva_cancelar.sql

Cancela una reserva existente.


11_reservas_usuario.sql

Obtiene el historial de reservas del usuario.


## Flujo esperado

Frontend / Mobile

        ↓

API REST

        ↓

Controller

        ↓

Service

        ↓

Repository

        ↓

PostgreSQL

