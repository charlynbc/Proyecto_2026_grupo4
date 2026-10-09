ALTER TABLE "POC".usuario
ADD COLUMN IF NOT EXISTS email VARCHAR(254);

ALTER TABLE "POC".usuario
ADD COLUMN IF NOT EXISTS email_verificado BOOLEAN
NOT NULL DEFAULT FALSE;

CREATE UNIQUE INDEX IF NOT EXISTS
usuario_email_unique_idx
ON "POC".usuario (LOWER(email))
WHERE email IS NOT NULL;

CREATE TABLE IF NOT EXISTS "POC".email_verification_token (

    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    usuario_id BIGINT NOT NULL
        REFERENCES "POC".usuario(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(64) NOT NULL UNIQUE,

    expira_en TIMESTAMPTZ NOT NULL,

    usado BOOLEAN NOT NULL DEFAULT FALSE,

    creado_en TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);

CREATE INDEX IF NOT EXISTS
email_verification_usuario_idx

ON "POC".email_verification_token(usuario_id);
