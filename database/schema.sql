-- Esquema completo de la base de datos del sistema de reserva de órdenes.
--
-- Fuente: Documento de Modelo de Datos (versión del 19/10/2026), secciones 4
-- (diccionario de datos) y 5 (restricciones R-MDAT). Cada restricción cita la
-- regla que implementa.
--
-- Este archivo recrea la base desde cero (RNF-19): se ejecuta sobre una base
-- vacía, dentro del esquema que indique search_path. No usa Flyway: los cambios
-- posteriores van en database/cambios/ y también se reflejan acá (ver README).
--
-- Convención: las tablas del Modelo de Datos (Persona, TurnoSemanal, ...) se
-- escriben en minúscula con guion bajo (persona, turno_semanal, ...).

BEGIN;

-- ---------------------------------------------------------------------------
-- 4.1 Identidad, cuentas y acceso
-- ---------------------------------------------------------------------------

CREATE TABLE persona (
    ci                varchar(12)  PRIMARY KEY,
    nombre            varchar(100) NOT NULL,
    apellido          varchar(100) NOT NULL,
    fecha_nacimiento  date         NOT NULL
);

CREATE TABLE cuenta (
    id_cuenta                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- R-MDAT-01: corregir una CI propaga la referencia a sus cuentas.
    ci                        varchar(12)  NOT NULL
                              REFERENCES persona (ci) ON UPDATE CASCADE,
    rol                       varchar(20)  NOT NULL
                              CHECK (rol IN ('SOCIO', 'FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')),
    correo                    varchar(254) NOT NULL,
    telefono_1                varchar(30)  NOT NULL,
    telefono_2                varchar(30),
    direccion                 text,
    contrasena_hash           text,
    primer_ingreso_completado boolean      NOT NULL DEFAULT false,
    habilitada                boolean      NOT NULL DEFAULT true,
    fecha_alta                timestamptz  NOT NULL DEFAULT now(),
    ultimo_inactivador        bigint       REFERENCES cuenta (id_cuenta),
    ultima_inactivacion_en    timestamptz,
    ultimo_reactivador        bigint       REFERENCES cuenta (id_cuenta),
    ultima_reactivacion_en    timestamptz,

    -- R-MDAT-03: al completar el primer ingreso se exigen dirección y contraseña.
    CONSTRAINT ck_cuenta_primer_ingreso
        CHECK (NOT primer_ingreso_completado
               OR (direccion IS NOT NULL AND contrasena_hash IS NOT NULL)),
    -- R-MDAT-03: responsable y fecha de cada acción se actualizan juntos.
    CONSTRAINT ck_cuenta_inactivacion
        CHECK ((ultimo_inactivador IS NULL) = (ultima_inactivacion_en IS NULL)),
    CONSTRAINT ck_cuenta_reactivacion
        CHECK ((ultimo_reactivador IS NULL) = (ultima_reactivacion_en IS NULL))
);

-- R-MDAT-02: una sola cuenta SOCIO por CI.
CREATE UNIQUE INDEX ux_cuenta_socio_por_ci
    ON cuenta (ci) WHERE rol = 'SOCIO';
-- R-MDAT-02: una sola cuenta de empleado habilitada por CI, aunque esté
-- pendiente del primer ingreso.
CREATE UNIQUE INDEX ux_cuenta_empleado_habilitado_por_ci
    ON cuenta (ci) WHERE rol <> 'SOCIO' AND habilitada;
CREATE INDEX ix_cuenta_ci ON cuenta (ci);

-- Cuenta.rol es inmutable (sección 3 del Modelo de Datos).
CREATE FUNCTION impedir_cambio_de_rol() RETURNS trigger
LANGUAGE plpgsql AS $$
BEGIN
    IF NEW.rol <> OLD.rol THEN
        RAISE EXCEPTION 'El rol de una cuenta no se puede modificar (cuenta %)', OLD.id_cuenta;
    END IF;
    RETURN NEW;
END;
$$;

CREATE TRIGGER tg_cuenta_rol_inmutable
    BEFORE UPDATE OF rol ON cuenta
    FOR EACH ROW EXECUTE FUNCTION impedir_cambio_de_rol();

CREATE TABLE especialidad (
    id_especialidad bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre          varchar(120) NOT NULL,
    requiere_pase   boolean      NOT NULL,
    fecha_alta      timestamptz  NOT NULL DEFAULT now()
);

-- R-MDAT-04: nombre único sin distinguir mayúsculas.
CREATE UNIQUE INDEX ux_especialidad_nombre ON especialidad (lower(nombre));

-- Que id_medico tenga rol MEDICO se verifica en el servicio (R-MDAT-04).
CREATE TABLE medico_especialidad (
    id_medico       bigint NOT NULL REFERENCES cuenta (id_cuenta),
    id_especialidad bigint NOT NULL REFERENCES especialidad (id_especialidad),
    PRIMARY KEY (id_medico, id_especialidad)
);

CREATE INDEX ix_medico_especialidad_especialidad ON medico_especialidad (id_especialidad);

CREATE TABLE sesion (
    id_sesion             bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cuenta             bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    token_renovacion_hash text        NOT NULL UNIQUE,
    creada_en             timestamptz NOT NULL DEFAULT now(),
    vence_en              timestamptz NOT NULL,
    revocada_en           timestamptz,
    CONSTRAINT ck_sesion_vencimiento CHECK (vence_en > creada_en)
);

CREATE INDEX ix_sesion_cuenta ON sesion (id_cuenta);

CREATE TABLE enlace_cuenta (
    id_enlace    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_cuenta    bigint       NOT NULL REFERENCES cuenta (id_cuenta),
    tipo         varchar(24)  NOT NULL
                 CHECK (tipo IN ('PRIMER_INGRESO', 'RECUPERACION', 'CAMBIO_CORREO')),
    token_hash   text         NOT NULL UNIQUE,
    correo_nuevo varchar(254),
    creado_en    timestamptz  NOT NULL DEFAULT now(),
    vence_en     timestamptz  NOT NULL,
    usado_en     timestamptz,
    -- correo_nuevo solo existe para CAMBIO_CORREO.
    CONSTRAINT ck_enlace_correo_nuevo
        CHECK ((tipo = 'CAMBIO_CORREO') = (correo_nuevo IS NOT NULL)),
    CONSTRAINT ck_enlace_vencimiento CHECK (vence_en > creado_en)
);

CREATE INDEX ix_enlace_cuenta_cuenta ON enlace_cuenta (id_cuenta);

-- ---------------------------------------------------------------------------
-- 4.2 Planificación semanal y fechas concretas
-- ---------------------------------------------------------------------------

CREATE TABLE consultorio (
    id_consultorio bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    nombre         varchar(120) NOT NULL UNIQUE,  -- R-MDAT-04
    ubicacion      varchar(200) NOT NULL
);

CREATE TABLE turno_semanal (
    id_turno_semanal    bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_medico           bigint   NOT NULL,
    id_especialidad     bigint   NOT NULL,
    id_consultorio      bigint   NOT NULL REFERENCES consultorio (id_consultorio),
    id_funcionario_alta bigint   NOT NULL REFERENCES cuenta (id_cuenta),
    dia_semana          smallint NOT NULL CHECK (dia_semana BETWEEN 1 AND 7),  -- 1 = lunes
    fecha_inicio        date     NOT NULL,
    fecha_fin           date     NOT NULL,
    -- La combinación médico–especialidad debe existir en medico_especialidad.
    CONSTRAINT fk_turno_semanal_medico_especialidad
        FOREIGN KEY (id_medico, id_especialidad)
        REFERENCES medico_especialidad (id_medico, id_especialidad),
    -- R-MDAT-06
    CONSTRAINT ck_turno_semanal_vigencia CHECK (fecha_fin >= fecha_inicio)
);

CREATE INDEX ix_turno_semanal_medico ON turno_semanal (id_medico);
CREATE INDEX ix_turno_semanal_consultorio ON turno_semanal (id_consultorio);

-- R-MDAT-07: los extremos de una franja están en múltiplos de cinco minutos y
-- el inicio precede al fin. La duración admitida (10 a 60 minutos) es
-- configurable, así que se valida en el servicio, igual que los solapamientos.
CREATE TABLE numero_semanal (
    id_numero_semanal bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_turno_semanal  bigint  NOT NULL REFERENCES turno_semanal (id_turno_semanal),
    numero            integer NOT NULL CHECK (numero > 0),
    hora_inicio       time    NOT NULL,
    hora_fin          time    NOT NULL,
    CONSTRAINT uq_numero_semanal UNIQUE (id_turno_semanal, numero),
    CONSTRAINT ck_numero_semanal_franja CHECK (hora_inicio < hora_fin),
    CONSTRAINT ck_numero_semanal_multiplo_5 CHECK (
        extract(minute FROM hora_inicio)::int % 5 = 0 AND extract(second FROM hora_inicio) = 0 AND
        extract(minute FROM hora_fin)::int % 5 = 0 AND extract(second FROM hora_fin) = 0)
);

CREATE TABLE turno (
    id_turno         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_turno_semanal bigint      NOT NULL REFERENCES turno_semanal (id_turno_semanal),
    id_consultorio   bigint      NOT NULL REFERENCES consultorio (id_consultorio),
    fecha            date        NOT NULL,
    estado           varchar(12) NOT NULL DEFAULT 'ACTIVO'
                     CHECK (estado IN ('ACTIVO', 'SUSPENDIDO')),
    -- R-MDAT-06: una instancia por patrón y fecha.
    CONSTRAINT uq_turno_patron_fecha UNIQUE (id_turno_semanal, fecha)
);

CREATE INDEX ix_turno_fecha ON turno (fecha);
CREATE INDEX ix_turno_consultorio_fecha ON turno (id_consultorio, fecha);

CREATE TABLE numero (
    id_numero         bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_turno          bigint  NOT NULL REFERENCES turno (id_turno),
    id_numero_semanal bigint  NOT NULL REFERENCES numero_semanal (id_numero_semanal),
    numero            integer NOT NULL CHECK (numero > 0),
    hora_inicio       time    NOT NULL,
    hora_fin          time    NOT NULL,
    CONSTRAINT uq_numero_turno UNIQUE (id_turno, numero),
    CONSTRAINT ck_numero_franja CHECK (hora_inicio < hora_fin),
    CONSTRAINT ck_numero_multiplo_5 CHECK (
        extract(minute FROM hora_inicio)::int % 5 = 0 AND extract(second FROM hora_inicio) = 0 AND
        extract(minute FROM hora_fin)::int % 5 = 0 AND extract(second FROM hora_fin) = 0)
);

CREATE INDEX ix_numero_numero_semanal ON numero (id_numero_semanal);

-- ---------------------------------------------------------------------------
-- 4.4 Aviso de llegada y responsables de acciones
-- (antes que consulta, que referencia a turno_evento)
-- ---------------------------------------------------------------------------

CREATE TABLE aviso_llegada (
    id_aviso_llegada bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_socio         bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    id_funcionario   bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    fecha            date        NOT NULL,
    registrada_en    timestamptz NOT NULL DEFAULT now(),
    -- R-MDAT-12: un aviso por socio y día.
    CONSTRAINT uq_aviso_llegada_socio_fecha UNIQUE (id_socio, fecha)
);

CREATE INDEX ix_aviso_llegada_fecha ON aviso_llegada (fecha);

CREATE TABLE turno_evento (
    id_evento      bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_turno       bigint      NOT NULL REFERENCES turno (id_turno),
    id_responsable bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    tipo           varchar(20) NOT NULL CHECK (tipo IN ('SUSPENSION', 'REHABILITACION')),
    realizado_en   timestamptz NOT NULL DEFAULT now(),
    observacion    text
);

CREATE INDEX ix_turno_evento_turno ON turno_evento (id_turno);

-- ---------------------------------------------------------------------------
-- 4.3 Consultas, atención y pases
-- ---------------------------------------------------------------------------

CREATE TABLE consulta (
    id_consulta              bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_socio                 bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    id_numero                bigint      NOT NULL REFERENCES numero (id_numero),
    id_pase                  bigint,     -- FK agregada al final: pase depende de atencion
    estado                   varchar(32) NOT NULL DEFAULT 'AGENDADA'
                             CHECK (estado IN ('AGENDADA', 'ATENDIDA', 'CANCELADA_SOCIO',
                                               'CANCELADA_INSTITUCION', 'NO_SE_PRESENTO')),
    agendada_en              timestamptz NOT NULL DEFAULT now(),
    cancelada_por            bigint      REFERENCES cuenta (id_cuenta),
    cancelada_en             timestamptz,
    motivo_cancelacion       text,
    id_evento_suspension     bigint      REFERENCES turno_evento (id_evento),
    resultado_registrado_por bigint      REFERENCES cuenta (id_cuenta),
    fecha_resultado          timestamptz,

    -- R-MDAT-14: toda cancelación conserva quién actuó y cuándo.
    CONSTRAINT ck_consulta_cancelacion
        CHECK ((estado IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION'))
               = (cancelada_por IS NOT NULL AND cancelada_en IS NOT NULL)),
    -- R-MDAT-14: la cancelación institucional lleva motivo (cancelación del
    -- médico) o el evento de suspensión que la causó (R-MDAT-08).
    CONSTRAINT ck_consulta_cancelacion_institucional
        CHECK (estado <> 'CANCELADA_INSTITUCION'
               OR motivo_cancelacion IS NOT NULL OR id_evento_suspension IS NOT NULL),
    CONSTRAINT ck_consulta_evento_suspension
        CHECK (id_evento_suspension IS NULL OR estado = 'CANCELADA_INSTITUCION'),
    -- R-MDAT-13 y R-MDAT-16: un resultado guarda responsable y momento.
    CONSTRAINT ck_consulta_resultado
        CHECK ((estado IN ('ATENDIDA', 'NO_SE_PRESENTO'))
               = (resultado_registrado_por IS NOT NULL AND fecha_resultado IS NOT NULL))
);

-- R-MDAT-10 (RNF-13): un número tiene a lo sumo una consulta no cancelada,
-- garantizado por la base aun ante agendas simultáneas.
CREATE UNIQUE INDEX ux_consulta_numero_ocupado
    ON consulta (id_numero)
    WHERE estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION');
-- R-MDAT-10: un pase se usa en a lo sumo una consulta no cancelada.
CREATE UNIQUE INDEX ux_consulta_pase_usado
    ON consulta (id_pase)
    WHERE id_pase IS NOT NULL AND estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION');
CREATE INDEX ix_consulta_socio_estado ON consulta (id_socio, estado);
CREATE INDEX ix_consulta_numero ON consulta (id_numero);

CREATE TABLE atencion (
    id_atencion   bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    -- R-MDAT-16: a lo sumo una atención por consulta.
    id_consulta   bigint      NOT NULL UNIQUE REFERENCES consulta (id_consulta),
    id_medico     bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    afeccion      text        NOT NULL CHECK (btrim(afeccion) <> ''),
    tratamiento   text,
    observaciones text,
    registrada_en timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_atencion_medico ON atencion (id_medico);

-- R-MDAT-18: la vigencia (1 a 365 días, 90 por defecto) es configurable, así
-- que se valida en el servicio.
CREATE TABLE pase (
    id_pase                 bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_atencion             bigint      NOT NULL REFERENCES atencion (id_atencion),
    id_especialidad_destino bigint      NOT NULL REFERENCES especialidad (id_especialidad),
    emitido_en              timestamptz NOT NULL DEFAULT now(),
    vence_el                date        NOT NULL,
    -- R-MDAT-18: dentro de una misma atención no se duplica el destino.
    CONSTRAINT uq_pase_atencion_destino UNIQUE (id_atencion, id_especialidad_destino)
);

CREATE INDEX ix_pase_especialidad_destino ON pase (id_especialidad_destino);

-- Cierra el ciclo consulta → pase → atencion → consulta.
ALTER TABLE consulta
    ADD CONSTRAINT fk_consulta_pase FOREIGN KEY (id_pase) REFERENCES pase (id_pase);

-- ---------------------------------------------------------------------------
-- 4.5 Cartelera y notificaciones
-- ---------------------------------------------------------------------------

-- "Debe contener texto o al menos una imagen" involucra dos tablas: se
-- verifica en el servicio.
CREATE TABLE anuncio (
    id_anuncio       bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_administrador bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    texto            text,
    publicado_en     timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE imagen_anuncio (
    id_imagen          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_anuncio         bigint  NOT NULL REFERENCES anuncio (id_anuncio),
    referencia_archivo text    NOT NULL,
    orden              integer NOT NULL
);

CREATE INDEX ix_imagen_anuncio_anuncio ON imagen_anuncio (id_anuncio);

CREATE TABLE dispositivo_push (
    id_dispositivo bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_socio       bigint      NOT NULL REFERENCES cuenta (id_cuenta),
    token          text        NOT NULL UNIQUE,
    habilitado     boolean     NOT NULL DEFAULT true,
    registrado_en  timestamptz NOT NULL DEFAULT now()
);

CREATE INDEX ix_dispositivo_push_socio ON dispositivo_push (id_socio);

CREATE TABLE notificacion (
    id_notificacion bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_consulta     bigint      NOT NULL REFERENCES consulta (id_consulta),
    tipo            varchar(40) NOT NULL
                    CHECK (tipo IN ('AGENDA', 'CANCELACION', 'SUSPENSION',
                                    'HISTORIA_ACTUALIZADA', 'RECORDATORIO')),
    contenido       text        NOT NULL,
    creada_en       timestamptz NOT NULL DEFAULT now(),
    programada_para timestamptz
);

-- R-MDAT-21: a lo sumo un recordatorio por consulta.
CREATE UNIQUE INDEX ux_notificacion_recordatorio
    ON notificacion (id_consulta) WHERE tipo = 'RECORDATORIO';
CREATE INDEX ix_notificacion_consulta ON notificacion (id_consulta);

CREATE TABLE envio_notificacion (
    id_envio          bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    id_notificacion   bigint       NOT NULL REFERENCES notificacion (id_notificacion),
    canal             varchar(12)  NOT NULL CHECK (canal IN ('CORREO', 'PUSH')),
    id_dispositivo    bigint       REFERENCES dispositivo_push (id_dispositivo),
    correo_destino    varchar(254),
    estado            varchar(20)  NOT NULL DEFAULT 'PENDIENTE'
                      CHECK (estado IN ('PENDIENTE', 'ENVIADO', 'FALLIDO')),
    intentos          integer      NOT NULL DEFAULT 0 CHECK (intentos >= 0),
    ultimo_intento_en timestamptz,
    enviado_en        timestamptz,
    -- R-MDAT-20: CORREO lleva dirección y no dispositivo; PUSH, lo inverso.
    CONSTRAINT ck_envio_destino CHECK (
        (canal = 'CORREO' AND correo_destino IS NOT NULL AND id_dispositivo IS NULL) OR
        (canal = 'PUSH'   AND id_dispositivo IS NOT NULL AND correo_destino IS NULL)),
    CONSTRAINT ck_envio_enviado CHECK ((estado = 'ENVIADO') = (enviado_en IS NOT NULL))
);

-- R-MDAT-20: un solo envío por notificación, canal y destino.
CREATE UNIQUE INDEX ux_envio_correo
    ON envio_notificacion (id_notificacion, correo_destino) WHERE canal = 'CORREO';
CREATE UNIQUE INDEX ux_envio_push
    ON envio_notificacion (id_notificacion, id_dispositivo) WHERE canal = 'PUSH';
-- El ejecutor de envíos busca los pendientes (Arquitectura, sección 8.2).
CREATE INDEX ix_envio_pendiente ON envio_notificacion (estado) WHERE estado = 'PENDIENTE';

COMMIT;
