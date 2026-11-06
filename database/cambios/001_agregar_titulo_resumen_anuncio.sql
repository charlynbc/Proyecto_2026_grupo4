-- RF-28 / RF-07: datos de portada y tarjeta de la cartelera.
-- En test estas columnas ya se agregaron manualmente; IF NOT EXISTS permite
-- ejecutar el script allí sin perder datos. En prod agrega las columnas.
ALTER TABLE public.anuncio
    ADD COLUMN IF NOT EXISTS titulo text,
    ADD COLUMN IF NOT EXISTS resumen text;
