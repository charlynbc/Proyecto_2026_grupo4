package uy.edu.proyecto.backend.atencion;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.HashSet;
import java.util.List;
import java.util.Set;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.atencion.AtencionRepository.ConsultaResultado;
import uy.edu.proyecto.backend.atencion.ResultadoConsultaRequest.PaseNuevoRequest;
import uy.edu.proyecto.backend.atencion.ResultadoConsultaResponse.PaseDTO;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class AtencionService {

    private static final String ATENDIDA = "ATENDIDA";
    private static final String NO_SE_PRESENTO = "NO_SE_PRESENTO";
    private static final int VIGENCIA_PASE_PREDETERMINADA = 90;

    private final AtencionRepository repository;
    private final Clock clock;

    public AtencionService(AtencionRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional
    public ResultadoConsultaResponse registrarResultado(
            Long medicoId,
            Long consultaId,
            ResultadoConsultaRequest request
    ) {
        validarIds(medicoId, consultaId);
        ResultadoValidado resultado = validarRequest(request);

        Long socioId = repository.buscarSocioId(medicoId, consultaId)
                .orElseThrow(() -> noEncontrado(
                        "No existe la consulta indicada para este médico"
                ));
        if (!repository.bloquearSocio(socioId)) {
            throw noEncontrado("No existe el socio de la consulta");
        }

        ConsultaResultado consulta = repository
                .bloquearConsulta(medicoId, consultaId)
                .orElseThrow(() -> noEncontrado(
                        "No existe la consulta indicada para este médico"
                ));

        if (consulta.ciSocio().equals(consulta.ciMedico())) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "CONFLICTO_DE_INTERES",
                    "El médico no puede registrar el resultado de su propia consulta"
            );
        }
        if (!consulta.estado().equals("AGENDADA")) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CONSULTA_NO_AGENDADA",
                    "La consulta ya no está agendada"
            );
        }
        LocalDate hoy = LocalDate.now(clock);
        if (!consulta.fecha().equals(hoy)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CONSULTA_NO_ES_DE_HOY",
                    "La consulta no corresponde al día de hoy"
            );
        }
        if (!repository.existeAvisoLlegada(socioId, hoy)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "SIN_AVISO_LLEGADA",
                    "El socio no registró su llegada hoy"
            );
        }

        OffsetDateTime ahora = OffsetDateTime.now(clock);
        if (resultado.estado().equals(NO_SE_PRESENTO)) {
            if (!repository.registrarNoPresentacion(
                    consultaId,
                    medicoId,
                    ahora
            )) {
                throw consultaNoAgendada();
            }
            return new ResultadoConsultaResponse(
                    consultaId,
                    NO_SE_PRESENTO,
                    null,
                    ahora,
                    List.of()
            );
        }

        List<PaseValidado> pases = validarPases(
                resultado.pases(),
                socioId,
                consultaId,
                hoy
        );
        Long atencionId = repository.crearAtencion(
                consultaId,
                medicoId,
                resultado.afeccion(),
                resultado.tratamiento(),
                resultado.observaciones(),
                ahora
        );
        List<PaseDTO> pasesCreados = new ArrayList<>();
        for (PaseValidado pase : pases) {
            LocalDate venceEl = hoy.plusDays(pase.vigenciaDias());
            Long paseId = repository.crearPase(
                    atencionId,
                    pase.especialidad(),
                    ahora,
                    venceEl
            );
            pasesCreados.add(new PaseDTO(
                    paseId,
                    pase.especialidad(),
                    ahora,
                    venceEl
            ));
        }
        if (!repository.registrarAtendida(consultaId, medicoId, ahora)) {
            throw consultaNoAgendada();
        }
        repository.crearNotificacionHistoriaActualizada(consultaId);

        return new ResultadoConsultaResponse(
                consultaId,
                ATENDIDA,
                atencionId,
                ahora,
                pasesCreados
        );
    }

    private ResultadoValidado validarRequest(
            ResultadoConsultaRequest request
    ) {
        if (request == null || request.resultado() == null) {
            throw validacion("resultado es obligatorio");
        }
        String estado = request.resultado().trim();
        if (!estado.equals(ATENDIDA) && !estado.equals(NO_SE_PRESENTO)) {
            throw validacion("resultado debe ser ATENDIDA o NO_SE_PRESENTO");
        }
        if (estado.equals(NO_SE_PRESENTO)) {
            if (request.afeccion() != null
                    || request.tratamiento() != null
                    || request.observaciones() != null
                    || request.pases() != null) {
                throw validacion(
                        "NO_SE_PRESENTO no admite campos clínicos ni pases"
                );
            }
            return new ResultadoValidado(estado, null, null, null, List.of());
        }

        String afeccion = normalizarObligatorio(
                request.afeccion(),
                "afeccion es obligatoria para ATENDIDA"
        );
        return new ResultadoValidado(
                estado,
                afeccion,
                normalizarOpcional(request.tratamiento()),
                normalizarOpcional(request.observaciones()),
                request.pases() == null ? List.of() : request.pases()
        );
    }

    private List<PaseValidado> validarPases(
            List<PaseNuevoRequest> solicitudes,
            Long socioId,
            Long consultaId,
            LocalDate hoy
    ) {
        List<SolicitudPaseValidada> solicitudesValidadas = new ArrayList<>();
        Set<Long> especialidades = new HashSet<>();
        for (PaseNuevoRequest solicitud : solicitudes) {
            if (solicitud == null
                    || solicitud.especialidadDestinoId() == null
                    || solicitud.especialidadDestinoId() <= 0) {
                throw validacion(
                        "Cada pase debe indicar una especialidad destino válida"
                );
            }
            Long especialidadId = solicitud.especialidadDestinoId();
            if (!especialidades.add(especialidadId)) {
                throw validacion(
                        "No se puede repetir la especialidad destino en los pases"
                );
            }
            int vigencia = solicitud.vigenciaDias() == null
                    ? VIGENCIA_PASE_PREDETERMINADA
                    : solicitud.vigenciaDias();
            if (vigencia < 1 || vigencia > 365) {
                throw validacion("vigenciaDias debe estar entre 1 y 365");
            }
            solicitudesValidadas.add(new SolicitudPaseValidada(
                    especialidadId,
                    vigencia
            ));
        }

        List<PaseValidado> resultado = new ArrayList<>();
        for (SolicitudPaseValidada solicitud : solicitudesValidadas) {
            Especialidad especialidad = repository
                    .buscarEspecialidad(solicitud.especialidadId())
                    .orElseThrow(() -> noEncontrado(
                            "No existe la especialidad destino indicada"
                    ));
            if (repository.tienePaseVigenteOConsultaAgendada(
                    socioId,
                    solicitud.especialidadId(),
                    consultaId,
                    hoy
            )) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "PASE_DUPLICADO",
                        "El socio ya tiene un pase vigente o una consulta agendada para esa especialidad"
                );
            }
            resultado.add(new PaseValidado(
                    especialidad,
                    solicitud.vigenciaDias()
            ));
        }
        return resultado;
    }

    private void validarIds(Long medicoId, Long consultaId) {
        if (medicoId == null || medicoId <= 0) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
        if (consultaId == null || consultaId <= 0) {
            throw validacion("El id de consulta debe ser mayor que cero");
        }
    }

    private String normalizarObligatorio(String valor, String mensaje) {
        if (valor == null || valor.isBlank()) {
            throw validacion(mensaje);
        }
        return valor.trim();
    }

    private String normalizarOpcional(String valor) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        return valor.trim();
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

    private ApiException consultaNoAgendada() {
        return new ApiException(
                HttpStatus.CONFLICT,
                "CONSULTA_NO_AGENDADA",
                "La consulta ya no está agendada"
        );
    }

    private record ResultadoValidado(
            String estado,
            String afeccion,
            String tratamiento,
            String observaciones,
            List<PaseNuevoRequest> pases
    ) {
    }

    private record PaseValidado(
            Especialidad especialidad,
            int vigenciaDias
    ) {
    }

    private record SolicitudPaseValidada(
            Long especialidadId,
            int vigenciaDias
    ) {
    }
}
