ALTER TABLE "POC".usuario
ADD COLUMN IF NOT EXISTS rol VARCHAR(20)
NOT NULL DEFAULT 'PACIENTE';

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_constraint
        WHERE conname = 'usuario_rol_valido'
          AND conrelid = '"POC".usuario'::regclass
    ) THEN

        ALTER TABLE "POC".usuario
        ADD CONSTRAINT usuario_rol_valido
        CHECK (
            rol IN (
                'PACIENTE',
                'FUNCIONARIO',
                'MEDICO',
                'ADMINISTRADOR'
            )
        );

    END IF;
END $$;


CREATE TABLE IF NOT EXISTS "POC".refresh_token (

    id BIGINT GENERATED ALWAYS AS IDENTITY PRIMARY KEY,

    usuario_id BIGINT NOT NULL
        REFERENCES "POC".usuario(id)
        ON DELETE CASCADE,

    token_hash VARCHAR(64) NOT NULL UNIQUE,

    expira_en TIMESTAMPTZ NOT NULL,

    revocado BOOLEAN NOT NULL DEFAULT FALSE,

    creado_en TIMESTAMPTZ NOT NULL
        DEFAULT CURRENT_TIMESTAMP
);


CREATE INDEX IF NOT EXISTS
refresh_token_usuario_idx

ON "POC".refresh_token(usuario_id);
