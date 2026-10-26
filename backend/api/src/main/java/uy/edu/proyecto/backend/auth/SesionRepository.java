package uy.edu.proyecto.backend.auth;

import java.time.OffsetDateTime;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class SesionRepository {

    private final JdbcTemplate jdbcTemplate;

    public SesionRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public void crear(
            Long idCuenta,
            String tokenHash,
            OffsetDateTime venceEn
    ) {
        jdbcTemplate.update(
                """
                INSERT INTO public.sesion
                    (id_cuenta, token_renovacion_hash, vence_en)
                VALUES (?, ?, ?)
                """,
                idCuenta,
                tokenHash,
                venceEn
        );
    }

    public Optional<Long> rotar(
            String hashAnterior,
            String hashNuevo,
            OffsetDateTime nuevaExpiracion
    ) {
        return jdbcTemplate.query(
                        """
                        UPDATE public.sesion s
                        SET token_renovacion_hash = ?,
                            vence_en = ?
                        WHERE s.token_renovacion_hash = ?
                          AND s.revocada_en IS NULL
                          AND s.vence_en > CURRENT_TIMESTAMP
                          AND EXISTS (
                              SELECT 1
                              FROM public.cuenta c
                              WHERE c.id_cuenta = s.id_cuenta
                                AND c.habilitada = TRUE
                                AND c.primer_ingreso_completado = TRUE
                                AND (c.ultima_reactivacion_en IS NULL
                                     OR s.creada_en > c.ultima_reactivacion_en)
                          )
                        RETURNING s.id_cuenta
                        """,
                        (rs, rowNum) -> rs.getLong("id_cuenta"),
                        hashNuevo,
                        nuevaExpiracion,
                        hashAnterior
                )
                .stream()
                .findFirst();
    }

    public void revocar(String tokenHash) {
        jdbcTemplate.update(
                """
                UPDATE public.sesion
                SET revocada_en = CURRENT_TIMESTAMP
                WHERE token_renovacion_hash = ?
                  AND revocada_en IS NULL
                """,
                tokenHash
        );
    }
}
