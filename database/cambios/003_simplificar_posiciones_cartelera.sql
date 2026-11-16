-- Conservar las posiciones existentes al pasar la selección al anuncio.
ALTER TABLE public.anuncio ADD COLUMN posicion_carrusel smallint;
UPDATE public.anuncio a SET posicion_carrusel=p.posicion
FROM public.cartelera_posicion p WHERE p.id_anuncio=a.id_anuncio;
ALTER TABLE public.anuncio ADD CONSTRAINT ck_anuncio_posicion_carrusel
    CHECK (posicion_carrusel BETWEEN 1 AND 5);
CREATE UNIQUE INDEX ux_anuncio_posicion_carrusel ON public.anuncio(posicion_carrusel)
    WHERE posicion_carrusel IS NOT NULL;
DROP TABLE public.cartelera_posicion;
DROP TABLE public.cartelera_version;
