-- Vigencia: los anuncios anteriores pueden conservar fin NULL; el backend
-- exige fin en las publicaciones nuevas y al modificar la vigencia.
ALTER TABLE public.anuncio ADD COLUMN vigente_desde timestamptz;
ALTER TABLE public.anuncio ADD COLUMN vigente_hasta timestamptz;
ALTER TABLE public.anuncio ADD CONSTRAINT ck_anuncio_vigencia
    CHECK (vigente_desde IS NULL OR vigente_hasta IS NULL OR vigente_desde < vigente_hasta);

-- Una version compartida evita perder cambios concurrentes del carrusel.
CREATE TABLE public.cartelera_version (
    id smallint PRIMARY KEY DEFAULT 1 CHECK (id = 1),
    version bigint NOT NULL DEFAULT 0 CHECK (version >= 0)
);
INSERT INTO public.cartelera_version (id, version) VALUES (1, 0);

CREATE TABLE public.cartelera_posicion (
    posicion smallint PRIMARY KEY CHECK (posicion BETWEEN 1 AND 5),
    id_anuncio bigint NOT NULL UNIQUE REFERENCES public.anuncio(id_anuncio) ON DELETE CASCADE
);

-- No depende del anuncio: conserva la referencia tras su eliminacion fisica.
CREATE TABLE public.anuncio_archivo_pendiente_borrado (
    id bigint GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
    referencia_archivo text NOT NULL UNIQUE CHECK (btrim(referencia_archivo) <> ''),
    creado_en timestamptz NOT NULL DEFAULT CURRENT_TIMESTAMP,
    intentos integer NOT NULL DEFAULT 0 CHECK (intentos >= 0),
    ultimo_intento timestamptz,
    ultimo_error text
);
