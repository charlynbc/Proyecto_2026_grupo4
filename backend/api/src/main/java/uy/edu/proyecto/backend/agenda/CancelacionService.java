package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZonedDateTime;
import java.time.OffsetDateTime;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.agenda.ConsultaRepository.ConsultaParaCancelar;
import uy.edu.proyecto.backend.exception.ApiException;

// RF-10: cancelación de una consulta propia por el socio.
@Service
public class CancelacionService {

    private static final long HORAS_MINIMAS = 2;

    private final ConsultaRepository repository;
    private final Clock clock;

    public CancelacionService(ConsultaRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional
    public CancelacionDTO cancelarPorSocio(Long socioId, String id) {
        long consultaId;
        try {
            consultaId = Long.parseLong(id);
        } catch (NumberFormatException exception) {
            consultaId = 0;
        }
        if (socioId == null || socioId <= 0 || consultaId <= 0) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El identificador de la consulta debe ser positivo"
            );
        }
        // Mismo orden de bloqueo que agendar y registrar resultado: socio, luego consulta.
        if (!repository.bloquearSocioHabilitado(socioId)) {
            throw noEncontrada();
        }
        ConsultaParaCancelar consulta = repository
                .bloquearConsultaDelSocio(socioId, consultaId)
                .orElseThrow(this::noEncontrada);

        if (!"AGENDADA".equals(consulta.estado())) {
            throw conflicto(
                    "CONSULTA_NO_AGENDADA",
                    "Solo se puede cancelar una consulta agendada"
            );
        }
        if (repository.existeAvisoLlegada(socioId, consulta.fecha())) {
            throw conflicto(
                    "LLEGADA_YA_REGISTRADA",
                    "El socio ya registró su llegada ese día"
            );
        }
        ZonedDateTime ahora = ZonedDateTime.now(clock);
        ZonedDateTime inicio = consulta.fecha()
                .atTime(consulta.horaInicio())
                .atZone(clock.getZone());
        if (inicio.isBefore(ahora.plusHours(HORAS_MINIMAS))) {
            throw conflicto(
                    "CANCELACION_FUERA_DE_PLAZO",
                    "Faltan menos de 2 horas para la hora del número"
            );
        }

        OffsetDateTime canceladaEn = repository
                .cancelarPorSocio(consultaId, socioId)
                .orElseThrow(() -> conflicto(
                        "CONSULTA_NO_AGENDADA",
                        "Solo se puede cancelar una consulta agendada"
                ));

        // El pase vuelve a estar disponible porque ya no lo usa una consulta no cancelada.
        LocalDate hoy = ahora.toLocalDate();
        boolean paseDevuelto = consulta.venceElPase() != null
                && !consulta.venceElPase().isBefore(hoy);
        return new CancelacionDTO(
                consultaId,
                "CANCELADA_SOCIO",
                canceladaEn,
                paseDevuelto
        );
    }

    // Consulta ajena e inexistente responden igual para no revelar su existencia.
    private ApiException noEncontrada() {
        return new ApiException(
                HttpStatus.NOT_FOUND,
                "NO_ENCONTRADO",
                "No existe la consulta indicada"
        );
    }

    private ApiException conflicto(String codigo, String mensaje) {
        return new ApiException(HttpStatus.CONFLICT, codigo, mensaje);
    }
}
