-- Origen: crear_estructura_v1.sql de Martín Parrilla (13/10/2026), el script con
-- el que se creó la base prod en Supabase. Se versiona sin cambios para cumplir
-- el RNF-19; cualquier cambio posterior va en database/cambios/ (ver README).
--
-- Modelo de Datos: estructura inicial en public para PostgreSQL 17.
-- Ejecutar completo una sola vez por base. No incluye datos iniciales.
BEGIN;

SET LOCAL search_path = pg_catalog, public;
SET LOCAL TIME ZONE 'America/Montevideo';

-- Identidad, cuentas y acceso.
CREATE TABLE public.persona (
    ci varchar(12) NOT NULL,
    nombre varchar(100) NOT NULL,
    apellido varchar(100) NOT NULL,
    fecha_nacimiento date NOT NULL,
    CONSTRAINT pk_persona PRIMARY KEY (ci),
    CONSTRAINT ck_persona_ci CHECK (btrim(ci) <> ''),
    CONSTRAINT ck_persona_nombre CHECK (btrim(nombre) <> ''),
    CONSTRAINT ck_persona_apellido CHECK (btrim(apellido) <> '')
);

CREATE TABLE public.cuenta (
    id_cuenta bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    ci varchar(12) NOT NULL,
    rol varchar(20) NOT NULL,
    correo varchar(254) NOT NULL,
    telefono_1 varchar(30) NOT NULL,
    telefono_2 varchar(30),
    direccion text,
    contrasena_hash text,
    primer_ingreso_completado boolean NOT NULL DEFAULT false,
    habilitada boolean NOT NULL DEFAULT true,
    fecha_alta timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    ultimo_inactivador bigint,
    ultima_inactivacion_en timestamptz,
    ultimo_reactivador bigint,
    ultima_reactivacion_en timestamptz,
    CONSTRAINT pk_cuenta PRIMARY KEY (id_cuenta),
    CONSTRAINT fk_cuenta_persona FOREIGN KEY (ci)
        REFERENCES public.persona (ci) ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_cuenta_inactivador FOREIGN KEY (ultimo_inactivador)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_cuenta_reactivador FOREIGN KEY (ultimo_reactivador)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_cuenta_rol CHECK (rol IN ('SOCIO', 'FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR')),
    CONSTRAINT ck_cuenta_correo CHECK (btrim(correo) <> ''),
    CONSTRAINT ck_cuenta_telefono_1 CHECK (btrim(telefono_1) <> ''),
    CONSTRAINT ck_cuenta_primer_ingreso CHECK (
        NOT primer_ingreso_completado
        OR (NULLIF(btrim(direccion), '') IS NOT NULL
            AND NULLIF(btrim(contrasena_hash), '') IS NOT NULL)
    ),
    CONSTRAINT ck_cuenta_inactivacion CHECK (
        (ultimo_inactivador IS NULL) = (ultima_inactivacion_en IS NULL)
    ),
    CONSTRAINT ck_cuenta_reactivacion CHECK (
        (ultimo_reactivador IS NULL) = (ultima_reactivacion_en IS NULL)
    )
);

CREATE TABLE public.especialidad (
    id_especialidad bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nombre varchar(120) NOT NULL,
    requiere_pase boolean NOT NULL,
    fecha_alta timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_especialidad PRIMARY KEY (id_especialidad),
    CONSTRAINT ck_especialidad_nombre CHECK (btrim(nombre) <> '')
);

CREATE TABLE public.medico_especialidad (
    id_medico bigint NOT NULL,
    id_especialidad bigint NOT NULL,
    CONSTRAINT pk_medico_especialidad PRIMARY KEY (id_medico, id_especialidad),
    CONSTRAINT fk_medico_especialidad_medico FOREIGN KEY (id_medico)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_medico_especialidad_especialidad FOREIGN KEY (id_especialidad)
        REFERENCES public.especialidad (id_especialidad) ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE public.sesion (
    id_sesion bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_cuenta bigint NOT NULL,
    token_renovacion_hash text NOT NULL,
    creada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    vence_en timestamptz NOT NULL,
    revocada_en timestamptz,
    CONSTRAINT pk_sesion PRIMARY KEY (id_sesion),
    CONSTRAINT uq_sesion_token UNIQUE (token_renovacion_hash),
    CONSTRAINT fk_sesion_cuenta FOREIGN KEY (id_cuenta)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_sesion_token CHECK (btrim(token_renovacion_hash) <> ''),
    CONSTRAINT ck_sesion_vencimiento CHECK (vence_en > creada_en),
    CONSTRAINT ck_sesion_revocacion CHECK (revocada_en IS NULL OR revocada_en >= creada_en)
);

CREATE TABLE public.enlace_cuenta (
    id_enlace bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_cuenta bigint NOT NULL,
    tipo varchar(24) NOT NULL,
    token_hash text NOT NULL,
    correo_nuevo varchar(254),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    vence_en timestamptz NOT NULL,
    usado_en timestamptz,
    CONSTRAINT pk_enlace_cuenta PRIMARY KEY (id_enlace),
    CONSTRAINT uq_enlace_cuenta_token UNIQUE (token_hash),
    CONSTRAINT fk_enlace_cuenta_cuenta FOREIGN KEY (id_cuenta)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_enlace_cuenta_tipo CHECK (tipo IN ('PRIMER_INGRESO', 'RECUPERACION', 'CAMBIO_CORREO')),
    CONSTRAINT ck_enlace_cuenta_token CHECK (btrim(token_hash) <> ''),
    CONSTRAINT ck_enlace_cuenta_correo CHECK (
        (tipo = 'CAMBIO_CORREO' AND NULLIF(btrim(correo_nuevo), '') IS NOT NULL)
        OR (tipo <> 'CAMBIO_CORREO' AND correo_nuevo IS NULL)
    ),
    CONSTRAINT ck_enlace_cuenta_vencimiento CHECK (vence_en > creado_en),
    CONSTRAINT ck_enlace_cuenta_uso CHECK (usado_en IS NULL OR usado_en >= creado_en)
);

-- Planificacion semanal e instancias por fecha.
CREATE TABLE public.consultorio (
    id_consultorio bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    nombre varchar(120) NOT NULL,
    ubicacion varchar(200) NOT NULL,
    CONSTRAINT pk_consultorio PRIMARY KEY (id_consultorio),
    CONSTRAINT uq_consultorio_nombre UNIQUE (nombre),
    CONSTRAINT ck_consultorio_nombre CHECK (btrim(nombre) <> ''),
    CONSTRAINT ck_consultorio_ubicacion CHECK (btrim(ubicacion) <> '')
);

-- R-MDAT-04: la asociacion medico/especialidad se valida al operar, conservando el historial.
CREATE TABLE public.turno_semanal (
    id_turno_semanal bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_medico bigint NOT NULL,
    id_especialidad bigint NOT NULL,
    id_consultorio bigint NOT NULL,
    id_funcionario_alta bigint NOT NULL,
    dia_semana smallint NOT NULL,
    fecha_inicio date NOT NULL,
    fecha_fin date NOT NULL,
    CONSTRAINT pk_turno_semanal PRIMARY KEY (id_turno_semanal),
    CONSTRAINT fk_turno_semanal_medico FOREIGN KEY (id_medico)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_turno_semanal_especialidad FOREIGN KEY (id_especialidad)
        REFERENCES public.especialidad (id_especialidad) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_turno_semanal_consultorio FOREIGN KEY (id_consultorio)
        REFERENCES public.consultorio (id_consultorio) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_turno_semanal_funcionario FOREIGN KEY (id_funcionario_alta)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_turno_semanal_dia CHECK (dia_semana BETWEEN 1 AND 7),
    CONSTRAINT ck_turno_semanal_vigencia CHECK (fecha_fin >= fecha_inicio)
);

CREATE TABLE public.numero_semanal (
    id_numero_semanal bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_turno_semanal bigint NOT NULL,
    numero integer NOT NULL,
    hora_inicio time NOT NULL,
    hora_fin time NOT NULL,
    CONSTRAINT pk_numero_semanal PRIMARY KEY (id_numero_semanal),
    CONSTRAINT uq_numero_semanal_turno_numero UNIQUE (id_turno_semanal, numero),
    CONSTRAINT fk_numero_semanal_turno FOREIGN KEY (id_turno_semanal)
        REFERENCES public.turno_semanal (id_turno_semanal) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_numero_semanal_numero CHECK (numero > 0),
    CONSTRAINT ck_numero_semanal_horario CHECK (hora_inicio < hora_fin),
    CONSTRAINT ck_numero_semanal_intervalo CHECK (
        EXTRACT(SECOND FROM hora_inicio) = 0 AND EXTRACT(SECOND FROM hora_fin) = 0
        AND EXTRACT(MINUTE FROM hora_inicio)::integer % 5 = 0
        AND EXTRACT(MINUTE FROM hora_fin)::integer % 5 = 0
    )
);

CREATE TABLE public.turno (
    id_turno bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_turno_semanal bigint NOT NULL,
    id_consultorio bigint NOT NULL,
    fecha date NOT NULL,
    estado varchar(12) NOT NULL DEFAULT 'ACTIVO',
    CONSTRAINT pk_turno PRIMARY KEY (id_turno),
    CONSTRAINT uq_turno_patron_fecha UNIQUE (id_turno_semanal, fecha),
    CONSTRAINT fk_turno_patron FOREIGN KEY (id_turno_semanal)
        REFERENCES public.turno_semanal (id_turno_semanal) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_turno_consultorio FOREIGN KEY (id_consultorio)
        REFERENCES public.consultorio (id_consultorio) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_turno_estado CHECK (estado IN ('ACTIVO', 'SUSPENDIDO'))
);

CREATE TABLE public.numero (
    id_numero bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_turno bigint NOT NULL,
    id_numero_semanal bigint NOT NULL,
    numero integer NOT NULL,
    hora_inicio time NOT NULL,
    hora_fin time NOT NULL,
    CONSTRAINT pk_numero PRIMARY KEY (id_numero),
    CONSTRAINT uq_numero_turno_numero UNIQUE (id_turno, numero),
    CONSTRAINT fk_numero_turno FOREIGN KEY (id_turno)
        REFERENCES public.turno (id_turno) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_numero_patron FOREIGN KEY (id_numero_semanal)
        REFERENCES public.numero_semanal (id_numero_semanal) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_numero_numero CHECK (numero > 0),
    CONSTRAINT ck_numero_horario CHECK (hora_inicio < hora_fin),
    CONSTRAINT ck_numero_intervalo CHECK (
        EXTRACT(SECOND FROM hora_inicio) = 0 AND EXTRACT(SECOND FROM hora_fin) = 0
        AND EXTRACT(MINUTE FROM hora_inicio)::integer % 5 = 0
        AND EXTRACT(MINUTE FROM hora_fin)::integer % 5 = 0
    )
);

-- Llegada y eventos de turnos.
CREATE TABLE public.aviso_llegada (
    id_aviso_llegada bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_socio bigint NOT NULL,
    id_funcionario bigint NOT NULL,
    fecha date NOT NULL,
    registrada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_aviso_llegada PRIMARY KEY (id_aviso_llegada),
    CONSTRAINT uq_aviso_llegada_socio_fecha UNIQUE (id_socio, fecha),
    CONSTRAINT fk_aviso_llegada_socio FOREIGN KEY (id_socio)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_aviso_llegada_funcionario FOREIGN KEY (id_funcionario)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE public.turno_evento (
    id_evento bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_turno bigint NOT NULL,
    id_responsable bigint NOT NULL,
    tipo varchar(20) NOT NULL,
    realizado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    observacion text,
    CONSTRAINT pk_turno_evento PRIMARY KEY (id_evento),
    CONSTRAINT fk_turno_evento_turno FOREIGN KEY (id_turno)
        REFERENCES public.turno (id_turno) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_turno_evento_responsable FOREIGN KEY (id_responsable)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_turno_evento_tipo CHECK (tipo IN ('SUSPENSION', 'REHABILITACION'))
);

-- Consultas, atenciones y pases.
CREATE TABLE public.consulta (
    id_consulta bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_socio bigint NOT NULL,
    id_numero bigint NOT NULL,
    id_pase bigint,
    estado varchar(32) NOT NULL DEFAULT 'AGENDADA',
    agendada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    cancelada_por bigint,
    cancelada_en timestamptz,
    motivo_cancelacion text,
    id_evento_suspension bigint,
    resultado_registrado_por bigint,
    fecha_resultado timestamptz,
    CONSTRAINT pk_consulta PRIMARY KEY (id_consulta),
    CONSTRAINT fk_consulta_socio FOREIGN KEY (id_socio)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_consulta_numero FOREIGN KEY (id_numero)
        REFERENCES public.numero (id_numero) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_consulta_cancelador FOREIGN KEY (cancelada_por)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_consulta_evento FOREIGN KEY (id_evento_suspension)
        REFERENCES public.turno_evento (id_evento) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_consulta_resultado_responsable FOREIGN KEY (resultado_registrado_por)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_consulta_estado CHECK (
        estado IN ('AGENDADA', 'ATENDIDA', 'CANCELADA_SOCIO', 'CANCELADA_INSTITUCION', 'NO_SE_PRESENTO')
    ),
    CONSTRAINT ck_consulta_cancelacion CHECK (
        (estado IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
            AND cancelada_por IS NOT NULL AND cancelada_en IS NOT NULL)
        OR (estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION')
            AND cancelada_por IS NULL AND cancelada_en IS NULL
            AND motivo_cancelacion IS NULL AND id_evento_suspension IS NULL)
    ),
    CONSTRAINT ck_consulta_resultado CHECK (
        (estado IN ('ATENDIDA', 'NO_SE_PRESENTO')
            AND resultado_registrado_por IS NOT NULL AND fecha_resultado IS NOT NULL)
        OR (estado NOT IN ('ATENDIDA', 'NO_SE_PRESENTO')
            AND resultado_registrado_por IS NULL AND fecha_resultado IS NULL)
    ),
    CONSTRAINT ck_consulta_suspension CHECK (
        id_evento_suspension IS NULL OR estado = 'CANCELADA_INSTITUCION'
    ),
    CONSTRAINT ck_consulta_motivo CHECK (
        estado <> 'CANCELADA_INSTITUCION' OR id_evento_suspension IS NOT NULL
        OR NULLIF(btrim(motivo_cancelacion), '') IS NOT NULL
    ),
    CONSTRAINT ck_consulta_fecha_cancelacion CHECK (cancelada_en IS NULL OR cancelada_en >= agendada_en),
    CONSTRAINT ck_consulta_fecha_resultado CHECK (fecha_resultado IS NULL OR fecha_resultado >= agendada_en)
);

CREATE TABLE public.atencion (
    id_atencion bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_consulta bigint NOT NULL,
    id_medico bigint NOT NULL,
    afeccion text NOT NULL,
    tratamiento text,
    observaciones text,
    registrada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_atencion PRIMARY KEY (id_atencion),
    CONSTRAINT uq_atencion_consulta UNIQUE (id_consulta),
    CONSTRAINT fk_atencion_consulta FOREIGN KEY (id_consulta)
        REFERENCES public.consulta (id_consulta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_atencion_medico FOREIGN KEY (id_medico)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_atencion_afeccion CHECK (btrim(afeccion) <> '')
);

CREATE TABLE public.pase (
    id_pase bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_atencion bigint NOT NULL,
    id_especialidad_destino bigint NOT NULL,
    emitido_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    vence_el date NOT NULL,
    CONSTRAINT pk_pase PRIMARY KEY (id_pase),
    CONSTRAINT uq_pase_atencion_destino UNIQUE (id_atencion, id_especialidad_destino),
    CONSTRAINT fk_pase_atencion FOREIGN KEY (id_atencion)
        REFERENCES public.atencion (id_atencion) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_pase_especialidad FOREIGN KEY (id_especialidad_destino)
        REFERENCES public.especialidad (id_especialidad) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_pase_vencimiento CHECK (vence_el >= (emitido_en AT TIME ZONE 'America/Montevideo')::date)
);

-- Cierra el ciclo consulta -> pase -> atencion -> consulta.
ALTER TABLE public.consulta
    ADD CONSTRAINT fk_consulta_pase FOREIGN KEY (id_pase)
        REFERENCES public.pase (id_pase) ON UPDATE RESTRICT ON DELETE RESTRICT;

-- Cartelera y notificaciones.
CREATE TABLE public.anuncio (
    id_anuncio bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_administrador bigint NOT NULL,
    texto text,
    publicado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_anuncio PRIMARY KEY (id_anuncio),
    CONSTRAINT fk_anuncio_administrador FOREIGN KEY (id_administrador)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT
);

CREATE TABLE public.imagen_anuncio (
    id_imagen bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_anuncio bigint NOT NULL,
    referencia_archivo text NOT NULL,
    orden integer NOT NULL,
    CONSTRAINT pk_imagen_anuncio PRIMARY KEY (id_imagen),
    CONSTRAINT fk_imagen_anuncio_anuncio FOREIGN KEY (id_anuncio)
        REFERENCES public.anuncio (id_anuncio) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_imagen_anuncio_referencia CHECK (btrim(referencia_archivo) <> '')
);

CREATE TABLE public.notificacion (
    id_notificacion bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_consulta bigint NOT NULL,
    tipo varchar(40) NOT NULL,
    contenido text NOT NULL,
    creada_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    programada_para timestamptz,
    CONSTRAINT pk_notificacion PRIMARY KEY (id_notificacion),
    CONSTRAINT fk_notificacion_consulta FOREIGN KEY (id_consulta)
        REFERENCES public.consulta (id_consulta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_notificacion_tipo CHECK (
        tipo IN ('AGENDA', 'CANCELACION', 'SUSPENSION', 'HISTORIA_ACTUALIZADA', 'RECORDATORIO')
    ),
    CONSTRAINT ck_notificacion_contenido CHECK (btrim(contenido) <> ''),
    CONSTRAINT ck_notificacion_recordatorio CHECK (tipo <> 'RECORDATORIO' OR programada_para IS NOT NULL)
);

CREATE TABLE public.dispositivo_push (
    id_dispositivo bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_socio bigint NOT NULL,
    token text NOT NULL,
    habilitado boolean NOT NULL DEFAULT true,
    registrado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT pk_dispositivo_push PRIMARY KEY (id_dispositivo),
    CONSTRAINT uq_dispositivo_push_token UNIQUE (token),
    CONSTRAINT fk_dispositivo_push_socio FOREIGN KEY (id_socio)
        REFERENCES public.cuenta (id_cuenta) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_dispositivo_push_token CHECK (btrim(token) <> '')
);

CREATE TABLE public.envio_notificacion (
    id_envio bigint GENERATED ALWAYS AS IDENTITY NOT NULL,
    id_notificacion bigint NOT NULL,
    canal varchar(12) NOT NULL,
    id_dispositivo bigint,
    correo_destino varchar(254),
    estado varchar(20) NOT NULL DEFAULT 'PENDIENTE',
    intentos integer NOT NULL DEFAULT 0,
    ultimo_intento_en timestamptz,
    enviado_en timestamptz,
    CONSTRAINT pk_envio_notificacion PRIMARY KEY (id_envio),
    CONSTRAINT fk_envio_notificacion_notificacion FOREIGN KEY (id_notificacion)
        REFERENCES public.notificacion (id_notificacion) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT fk_envio_notificacion_dispositivo FOREIGN KEY (id_dispositivo)
        REFERENCES public.dispositivo_push (id_dispositivo) ON UPDATE RESTRICT ON DELETE RESTRICT,
    CONSTRAINT ck_envio_notificacion_canal CHECK (canal IN ('CORREO', 'PUSH')),
    CONSTRAINT ck_envio_notificacion_destino CHECK (
        (canal = 'CORREO' AND NULLIF(btrim(correo_destino), '') IS NOT NULL AND id_dispositivo IS NULL)
        OR (canal = 'PUSH' AND id_dispositivo IS NOT NULL AND correo_destino IS NULL)
    ),
    CONSTRAINT ck_envio_notificacion_estado CHECK (estado IN ('PENDIENTE', 'ENVIADO', 'FALLIDO')),
    CONSTRAINT ck_envio_notificacion_intentos CHECK (intentos >= 0),
    CONSTRAINT ck_envio_notificacion_ultimo_intento CHECK (
        (intentos = 0 AND ultimo_intento_en IS NULL)
        OR (intentos > 0 AND ultimo_intento_en IS NOT NULL)
    ),
    CONSTRAINT ck_envio_notificacion_enviado CHECK (
        (estado = 'ENVIADO' AND enviado_en IS NOT NULL AND intentos > 0)
        OR (estado <> 'ENVIADO' AND enviado_en IS NULL)
    )
);

-- Unicidades condicionadas: R-MDAT-02, 04, 10, 20 y 21.
CREATE UNIQUE INDEX uq_cuenta_socio_ci ON public.cuenta (ci)
    WHERE rol = 'SOCIO';
CREATE UNIQUE INDEX uq_cuenta_empleado_habilitado_ci ON public.cuenta (ci)
    WHERE rol IN ('FUNCIONARIO', 'MEDICO', 'ADMINISTRADOR') AND habilitada;
CREATE UNIQUE INDEX uq_especialidad_nombre ON public.especialidad (lower(nombre));
CREATE UNIQUE INDEX uq_consulta_numero_no_cancelada ON public.consulta (id_numero)
    WHERE estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION');
CREATE UNIQUE INDEX uq_consulta_pase_no_cancelada ON public.consulta (id_pase)
    WHERE id_pase IS NOT NULL AND estado NOT IN ('CANCELADA_SOCIO', 'CANCELADA_INSTITUCION');
CREATE UNIQUE INDEX uq_notificacion_recordatorio ON public.notificacion (id_consulta)
    WHERE tipo = 'RECORDATORIO';
CREATE UNIQUE INDEX uq_envio_notificacion_correo ON public.envio_notificacion (id_notificacion, correo_destino)
    WHERE canal = 'CORREO';
CREATE UNIQUE INDEX uq_envio_notificacion_push ON public.envio_notificacion (id_notificacion, id_dispositivo)
    WHERE canal = 'PUSH';

-- Indices iniciales para referencias, historial y busquedas.
CREATE INDEX ix_cuenta_ci ON public.cuenta (ci);
CREATE INDEX ix_cuenta_inactivador ON public.cuenta (ultimo_inactivador);
CREATE INDEX ix_cuenta_reactivador ON public.cuenta (ultimo_reactivador);
CREATE INDEX ix_medico_especialidad_especialidad ON public.medico_especialidad (id_especialidad);
CREATE INDEX ix_sesion_cuenta ON public.sesion (id_cuenta);
CREATE INDEX ix_enlace_cuenta_cuenta_tipo ON public.enlace_cuenta (id_cuenta, tipo);
CREATE INDEX ix_turno_semanal_medico_especialidad ON public.turno_semanal (id_medico, id_especialidad);
CREATE INDEX ix_turno_semanal_especialidad ON public.turno_semanal (id_especialidad);
CREATE INDEX ix_turno_semanal_consultorio ON public.turno_semanal (id_consultorio);
CREATE INDEX ix_turno_semanal_funcionario ON public.turno_semanal (id_funcionario_alta);
CREATE INDEX ix_turno_consultorio_fecha_estado ON public.turno (id_consultorio, fecha, estado);
CREATE INDEX ix_turno_fecha_estado ON public.turno (fecha, estado);
CREATE INDEX ix_numero_patron ON public.numero (id_numero_semanal);
CREATE INDEX ix_aviso_llegada_funcionario ON public.aviso_llegada (id_funcionario);
CREATE INDEX ix_aviso_llegada_fecha_registro ON public.aviso_llegada (fecha, registrada_en);
CREATE INDEX ix_turno_evento_turno_fecha ON public.turno_evento (id_turno, realizado_en);
CREATE INDEX ix_turno_evento_responsable ON public.turno_evento (id_responsable);
CREATE INDEX ix_consulta_socio_estado ON public.consulta (id_socio, estado);
CREATE INDEX ix_consulta_numero ON public.consulta (id_numero);
CREATE INDEX ix_consulta_pase ON public.consulta (id_pase);
CREATE INDEX ix_consulta_cancelador ON public.consulta (cancelada_por);
CREATE INDEX ix_consulta_evento ON public.consulta (id_evento_suspension);
CREATE INDEX ix_consulta_resultado_responsable ON public.consulta (resultado_registrado_por);
CREATE INDEX ix_consulta_agendada_en ON public.consulta (agendada_en);
CREATE INDEX ix_atencion_medico_registro ON public.atencion (id_medico, registrada_en);
CREATE INDEX ix_pase_especialidad_vencimiento ON public.pase (id_especialidad_destino, vence_el);
CREATE INDEX ix_pase_emitido_en ON public.pase (emitido_en);
CREATE INDEX ix_anuncio_administrador ON public.anuncio (id_administrador);
CREATE INDEX ix_anuncio_publicado_en ON public.anuncio (publicado_en);
CREATE INDEX ix_imagen_anuncio_anuncio_orden ON public.imagen_anuncio (id_anuncio, orden);
CREATE INDEX ix_notificacion_consulta_fecha ON public.notificacion (id_consulta, creada_en);
CREATE INDEX ix_notificacion_programada_para ON public.notificacion (programada_para)
    WHERE tipo = 'RECORDATORIO';
CREATE INDEX ix_dispositivo_push_socio_habilitado ON public.dispositivo_push (id_socio, habilitado);
CREATE INDEX ix_envio_notificacion_notificacion ON public.envio_notificacion (id_notificacion);
CREATE INDEX ix_envio_notificacion_dispositivo ON public.envio_notificacion (id_dispositivo);
CREATE INDEX ix_envio_notificacion_estado_intento ON public.envio_notificacion (estado, ultimo_intento_en);

COMMIT;
