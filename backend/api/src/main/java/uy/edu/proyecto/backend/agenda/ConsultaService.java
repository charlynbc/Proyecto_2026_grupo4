package uy.edu.proyecto.backend.agenda;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.agenda.ConsultaRepository.NumeroParaAgendar;
import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class ConsultaService {

    private final ConsultaRepository repository;

    public ConsultaService(ConsultaRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public ConsultaDTO agendar(Long socioId, CrearConsultaRequest request) {
        if (socioId == null || socioId <= 0 || request == null
                || request.numeroId() == null || request.numeroId() <= 0
                || (request.paseId() != null && request.paseId() <= 0)) {
            throw validacion("numeroId es obligatorio y los identificadores deben ser válidos");
        }

        if (!repository.bloquearSocioHabilitado(socioId)) {
            throw noEncontrado("No existe una cuenta de socio activa");
        }

        NumeroParaAgendar numero = repository.bloquearNumero(request.numeroId())
                .orElseThrow(() -> noEncontrado("No existe el número indicado"));

        if (!"ACTIVO".equals(numero.estadoTurno())
                || !numero.medicoHabilitado()) {
            throw conflicto(
                    "NUMERO_NO_DISPONIBLE",
                    "El número no está disponible para agendar"
            );
        }
        if (!numero.ventanaValida()) {
            throw conflicto(
                    "ANTICIPACION_INVALIDA",
                    "El número debe estar entre 2 horas y 30 días desde ahora"
            );
        }

        long consultasActivas = repository.contarConsultasAgendadas(socioId);
        if (consultasActivas >= 3) {
            throw conflicto(
                    "LIMITE_TOTAL",
                    "El socio ya tiene el máximo de tres consultas agendadas"
            );
        }
        if (repository.tieneConsultaAgendadaEnEspecialidad(
                socioId,
                numero.especialidad().id()
        )) {
            throw conflicto(
                    "LIMITE_ESPECIALIDAD",
                    "El socio ya tiene una consulta agendada en esta especialidad"
            );
        }
        if (repository.tieneConsultaSuperpuesta(
                socioId,
                numero.fecha(),
                numero.horaInicio(),
                numero.horaFin()
        )) {
            throw conflicto(
                    "CONSULTA_SUPERPUESTA",
                    "El horario se superpone con otra consulta agendada del socio"
            );
        }

        Long paseId = validarPase(socioId, request.paseId(), numero);

        ConsultaDTO consulta = repository.crear(socioId, numero, paseId)
                .orElseThrow(() -> conflicto(
                        "NUMERO_NO_DISPONIBLE",
                        "El número ya no está disponible para agendar"
                ));
        repository.crearNotificacionAgenda(consulta.id());
        return consulta;
    }

    private Long validarPase(
            Long socioId,
            Long paseId,
            NumeroParaAgendar numero
    ) {
        if (!numero.especialidad().requierePase()) {
            if (paseId != null) {
                throw validacion(
                        "No se debe enviar paseId para una especialidad que no lo requiere"
                );
            }
            return null;
        }
        if (paseId == null
                || repository.bloquearPaseDisponible(
                        paseId,
                        socioId,
                        numero.especialidad().id(),
                        numero.fecha()
                ).isEmpty()) {
            throw conflicto(
                    "PASE_NO_VALIDO",
                    "No existe un pase propio, vigente y sin utilizar para esta especialidad"
            );
        }
        return paseId;
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "VALIDACION",
                mensaje
        );
    }

    private ApiException noEncontrado(String mensaje) {
        return new ApiException(
                HttpStatus.NOT_FOUND,
                "NO_ENCONTRADO",
                mensaje
        );
    }

    private ApiException conflicto(String codigo, String mensaje) {
        return new ApiException(
                HttpStatus.CONFLICT,
                codigo,
                mensaje
        );
    }
}
