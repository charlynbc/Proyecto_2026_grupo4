package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.util.Optional;

import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.stereotype.Repository;

@Repository
public class HistoriaClinicaMedicoRepository {

    private final JdbcTemplate jdbcTemplate;

    public HistoriaClinicaMedicoRepository(JdbcTemplate jdbcTemplate) {
        this.jdbcTemplate = jdbcTemplate;
    }

    public Optional<String> ciMedico(Long medicoId) {
        return jdbcTemplate.query("""
                SELECT ci FROM public.cuenta
                WHERE id_cuenta = ? AND rol = 'MEDICO' AND habilitada = TRUE
                """, (rs, rowNum) -> rs.getString("ci"), medicoId)
                .stream().findFirst();
    }

    // Solo cuentas de socio: cualquier otro id responde vacío para no revelar su existencia.
    public Optional<String> ciPaciente(Long socioId) {
        return jdbcTemplate.query("""
                SELECT ci FROM public.cuenta
                WHERE id_cuenta = ? AND rol = 'SOCIO'
                """, (rs, rowNum) -> rs.getString("ci"), socioId)
                .stream().findFirst();
    }

    // RF-22: habilita el acceso una consulta AGENDADA del médico con el paciente
    // cuyo día todavía no terminó (puede ser futura y no exige aviso de llegada).
    public boolean tieneConsultaHabilitante(Long medicoId, Long socioId, LocalDate hoy) {
        return Boolean.TRUE.equals(jdbcTemplate.queryForObject("""
                SELECT EXISTS (
                    SELECT 1
                    FROM public.consulta consulta
                    JOIN public.numero numero
                      ON numero.id_numero = consulta.id_numero
                    JOIN public.turno turno ON turno.id_turno = numero.id_turno
                    JOIN public.turno_semanal semanal
                      ON semanal.id_turno_semanal = turno.id_turno_semanal
                    WHERE semanal.id_medico = ?
                      AND consulta.id_socio = ?
                      AND consulta.estado = 'AGENDADA'
                      AND turno.fecha >= ?
                )
                """, Boolean.class, medicoId, socioId, hoy));
    }
}
