package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.time.ZonedDateTime;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.agenda.ConsultaRepository.NumeroParaAgendar;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.notificacion.NotificacionEnvios;
import uy.edu.proyecto.backend.notificacion.NotificacionTextos;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.VentanaAgendar;

@Service
public class ConsultaService {

    private final ConsultaRepository repository;
    private final ParametroService parametros;
    private final Clock clock;
    private final NotificacionEnvios envios;

    public ConsultaService(ConsultaRepository repository, ParametroService parametros,
            Clock clock, NotificacionEnvios envios) {
        this.repository = repository;
        this.parametros = parametros;
        this.clock = clock;
        this.envios = envios;
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

        VentanaAgendar ventana = parametros.ventanaAgendar(OffsetDateTime.now(clock));
        NumeroParaAgendar numero = repository.bloquearNumero(
                        request.numeroId(), ventana.minimoInicio(), ventana.maximoInicio())
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
                    "El número debe estar entre "
                            + ParametroService.horas(parametros.agendarAnticipacionMinimaHoras())
                            + " y "
                            + ParametroService.dias(parametros.agendarAnticipacionMaximaDias())
                            + " desde ahora"
            );
        }

        int limiteTotal = parametros.consultasActivasTotal();
        long consultasActivas = repository.contarConsultasAgendadas(socioId);
        if (consultasActivas >= limiteTotal) {
            throw conflicto(
                    "LIMITE_TOTAL",
                    mensajeLimiteTotal(limiteTotal)
            );
        }
        int limiteEspecialidad = parametros.consultasActivasPorEspecialidad();
        long enLaEspecialidad = repository.contarConsultasAgendadasEnEspecialidad(
                socioId,
                numero.especialidad().id()
        );
        if (enLaEspecialidad >= limiteEspecialidad) {
            throw conflicto(
                    "LIMITE_ESPECIALIDAD",
                    mensajeLimiteEspecialidad(limiteEspecialidad)
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

        ConsultaDTO consulta;
        try {
            consulta = repository.crear(socioId, numero, paseId)
                    .orElseThrow(() -> conflicto(
                            "NUMERO_NO_DISPONIBLE",
                            "El número ya no está disponible para agendar"
                    ));
        } catch (DuplicateKeyException exception) {
            throw conflicto(
                    "NUMERO_NO_DISPONIBLE",
                    "El número ya no está disponible para agendar"
            );
        }
        // Los envios se crean en esta transaccion y se entregan despues del commit:
        // una falla del correo o del push no revierte el agendado (RNF-24).
        Long notificacionId = repository.crearNotificacionAgenda(
                consulta.id(),
                NotificacionTextos.cuerpoAgenda(
                        consulta.especialidad().nombre(),
                        consulta.medico().nombre() + " " + consulta.medico().apellido(),
                        consulta.fecha(),
                        numero.horaInicio()
                )
        );
        envios.solicitar(notificacionId, socioId);
        // cancelable: la misma regla que la lectura, con la llegada del socio ese dia.
        return ReglaCancelableSocio.aplicar(
                consulta,
                repository.existeAvisoLlegada(socioId, consulta.fecha()),
                clock.getZone(),
                ZonedDateTime.now(clock),
                parametros.cancelarAnticipacionMinimaHoras()
        );
    }

    private static String mensajeLimiteTotal(int limite) {
        return "El socio ya tiene el máximo de " + ParametroService.consultas(limite)
                + (limite == 1 ? " agendada" : " agendadas");
    }

    private static String mensajeLimiteEspecialidad(int limite) {
        if (limite == 1) {
            return "El socio ya tiene una consulta agendada en esta especialidad";
        }
        return "El socio ya tiene el máximo de " + ParametroService.consultas(limite)
                + " agendadas en esta especialidad";
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
