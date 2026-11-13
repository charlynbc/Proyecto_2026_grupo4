package uy.edu.proyecto.backend.usuario;

import java.time.Clock;
import java.time.LocalDate;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.auth.SesionRepository;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CuentaRepository.CuentaEstado;

/**
 * Inactivacion y reactivacion administrativa de cuentas de empleado (RF-45).
 *
 * Al inactivar se conserva toda la informacion historica y se registra quien
 * lo hizo y cuando; la cuenta no puede iniciar sesion (el login filtra
 * habilitada) y los JWT ya emitidos dejan de autorizar en la siguiente
 * solicitud (CuentaVigenteValidator), ademas de revocarse sus sesiones de
 * renovacion. La cuenta de Socio de la misma persona no se modifica.
 *
 * Un medico solo se inactiva sin fechas activas de turnos ni consultas
 * agendadas cuyo dia todavia no termino; antes deben suspenderse por RF-14.
 *
 * Al reactivar se verifica que no exista otra cuenta de empleado habilitada
 * o pendiente de primer ingreso para la misma CI; las fechas de turnos
 * suspendidas no se rehabilitan automaticamente (RF-15) y los JWT emitidos
 * antes de la reactivacion no reviven (CuentaVigenteValidator).
 */
@Service
public class InactivacionEmpleadoService {

    private final CuentaRepository repository;
    private final SesionRepository sesionRepository;
    private final Clock clock;

    public InactivacionEmpleadoService(
            CuentaRepository repository,
            SesionRepository sesionRepository,
            Clock clock
    ) {
        this.repository = repository;
        this.sesionRepository = sesionRepository;
        this.clock = clock;
    }

    @Transactional
    public EstadoCuentaResponse inactivar(long idCuenta, long idAdministrador) {
        LocalDate hoy = LocalDate.now(clock);
        ReglaInactivacion.evaluar(
                idCuenta,
                idAdministrador,
                () -> {
                    CuentaEstado cuenta = bloquearCuenta(idCuenta);
                    return new ReglaInactivacion.CuentaCandidata(
                            cuenta.rol(), cuenta.habilitada());
                },
                new ReglaInactivacion.AgendaMedico() {
                    @Override
                    public boolean tieneFechasActivas() {
                        return repository.medicoTieneFechasActivasDesde(idCuenta, hoy);
                    }

                    @Override
                    public boolean tieneConsultasAgendadas() {
                        return repository.medicoTieneConsultasAgendadasDesde(idCuenta, hoy);
                    }
                }
        ).ifPresent(bloqueo -> {
            throw rechazo(bloqueo);
        });

        if (repository.inactivarCuenta(idCuenta, idAdministrador) != 1) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CUENTA_YA_INACTIVA",
                    "La cuenta ya está inactiva"
            );
        }

        // Las sesiones de renovacion se revocan; los JWT ya emitidos dejan de
        // autorizar porque la cuenta queda inhabilitada (CuentaVigenteValidator).
        sesionRepository.revocarOtrasSesiones(idCuenta, null);

        CuentaEstado actualizada = repository.bloquearCuentaParaEstado(idCuenta)
                .orElseThrow();
        return respuesta(actualizada);
    }

    @Transactional
    public EstadoCuentaResponse reactivar(long idCuenta, long idAdministrador) {
        if (idCuenta == idAdministrador) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "AUTO_INACTIVACION_NO_PERMITIDA",
                    "No puede reactivar su propia cuenta"
            );
        }

        CuentaEstado cuenta = bloquearEmpleado(idCuenta);

        if (cuenta.habilitada()) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CUENTA_YA_ACTIVA",
                    "La cuenta ya está habilitada"
            );
        }

        if (repository.existeOtraCuentaEmpleadoHabilitada(
                cuenta.ci(), idCuenta)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "EMPLEADO_DUPLICADO",
                    "La CI ya tiene otra cuenta de empleado habilitada o"
                            + " pendiente de primer ingreso"
            );
        }

        try {
            if (repository.reactivarCuenta(idCuenta, idAdministrador) != 1) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "CUENTA_YA_ACTIVA",
                        "La cuenta ya está habilitada"
                );
            }
        } catch (DuplicateKeyException exception) {
            // uq_cuenta_empleado_habilitado_ci: otra cuenta se habilito en paralelo.
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "EMPLEADO_DUPLICADO",
                    "La CI ya tiene otra cuenta de empleado habilitada o"
                            + " pendiente de primer ingreso"
            );
        }

        // Las fechas de turnos suspendidas no se rehabilitan (RF-15) y los
        // JWT anteriores a la reactivacion no reviven (CuentaVigenteValidator).
        CuentaEstado actualizada = repository.bloquearCuentaParaEstado(idCuenta)
                .orElseThrow();
        return respuesta(actualizada);
    }

    private CuentaEstado bloquearCuenta(long idCuenta) {
        return repository.bloquearCuentaParaEstado(idCuenta)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "USUARIO_NO_ENCONTRADO",
                        "No existe una cuenta con ese identificador"
                ));
    }

    private CuentaEstado bloquearEmpleado(long idCuenta) {
        CuentaEstado cuenta = bloquearCuenta(idCuenta);
        if (cuenta.rol().equals("SOCIO")) {
            throw rechazo(ReglaInactivacion.Bloqueo.NO_ES_EMPLEADO);
        }
        return cuenta;
    }

    /** El error HTTP de cada bloqueo de la regla de inactivacion. */
    private static ApiException rechazo(ReglaInactivacion.Bloqueo bloqueo) {
        return switch (bloqueo) {
            case CUENTA_PROPIA -> new ApiException(
                    HttpStatus.CONFLICT,
                    "AUTO_INACTIVACION_NO_PERMITIDA",
                    "No puede inactivar su propia cuenta"
            );
            case NO_ES_EMPLEADO -> new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "Esta operación aplica solo a cuentas de empleado"
            );
            case YA_INACTIVA -> new ApiException(
                    HttpStatus.CONFLICT,
                    "CUENTA_YA_INACTIVA",
                    "La cuenta ya está inactiva"
            );
            case MEDICO_CON_TURNOS_ACTIVOS -> new ApiException(
                    HttpStatus.CONFLICT,
                    "MEDICO_CON_TURNOS_ACTIVOS",
                    "El médico tiene fechas de turnos activas cuyo día"
                            + " todavía no terminó. Primero suspendalas"
                            + " desde la gestión de turnos."
            );
            case MEDICO_CON_CONSULTAS_AGENDADAS -> new ApiException(
                    HttpStatus.CONFLICT,
                    "MEDICO_CON_CONSULTAS_AGENDADAS",
                    "El médico tiene consultas agendadas cuyo día todavía"
                            + " no terminó. Primero suspenda las fechas de"
                            + " sus turnos para cancelarlas."
            );
        };
    }

    private EstadoCuentaResponse respuesta(CuentaEstado cuenta) {
        return new EstadoCuentaResponse(
                cuenta.id(),
                cuenta.ci(),
                cuenta.nombre(),
                cuenta.apellido(),
                cuenta.rol(),
                cuenta.habilitada() ? "ACTIVA" : "INACTIVA",
                cuenta.ultimaInactivacionEn(),
                cuenta.ultimoInactivador(),
                cuenta.ultimaReactivacionEn(),
                cuenta.ultimoReactivador()
        );
    }
}
