package uy.edu.proyecto.backend.usuario;

import java.util.Optional;
import java.util.function.Supplier;

/**
 * La regla unica de inactivacion de una cuenta de empleado (RF-45). La usan
 * POST /api/usuarios/{id}/inactivar, que traduce cada bloqueo a su error, y
 * el listado GET /api/usuarios, que publica puedeInactivar: como las dos
 * salen de este metodo, no pueden divergir.
 *
 * Una cuenta se puede inactivar solo si no tiene ningun bloqueo. Se evalua en
 * este orden y se informa el primero: cuenta propia del administrador que
 * opera, cuenta de socio, cuenta ya inactiva, medico con fechas activas de
 * turnos y medico con consultas agendadas (las dos ultimas, cuyo dia todavia
 * no termino).
 */
final class ReglaInactivacion {

    enum Bloqueo {
        CUENTA_PROPIA,
        NO_ES_EMPLEADO,
        YA_INACTIVA,
        MEDICO_CON_TURNOS_ACTIVOS,
        MEDICO_CON_CONSULTAS_AGENDADAS
    }

    /** Los datos de la cuenta que la regla necesita. */
    record CuentaCandidata(String rol, boolean habilitada) {
    }

    /**
     * Agenda de un medico. Solo se consulta si la cuenta es de un medico
     * activo y sin otro bloqueo anterior, asi quien la implementa puede
     * resolverla de forma perezosa o con datos calculados en lote.
     */
    interface AgendaMedico {
        boolean tieneFechasActivas();

        boolean tieneConsultasAgendadas();
    }

    private ReglaInactivacion() {
    }

    /**
     * @param cuenta  datos de la cuenta; no se pide si es la propia
     * @param agenda  agenda del medico
     * @return el primer bloqueo, o vacio si la cuenta se puede inactivar
     */
    static Optional<Bloqueo> evaluar(
            long idCuenta,
            long idAdministrador,
            Supplier<CuentaCandidata> cuenta,
            AgendaMedico agenda
    ) {
        if (idCuenta == idAdministrador) {
            return Optional.of(Bloqueo.CUENTA_PROPIA);
        }
        CuentaCandidata datos = cuenta.get();
        if ("SOCIO".equals(datos.rol())) {
            return Optional.of(Bloqueo.NO_ES_EMPLEADO);
        }
        if (!datos.habilitada()) {
            return Optional.of(Bloqueo.YA_INACTIVA);
        }
        if ("MEDICO".equals(datos.rol())) {
            if (agenda.tieneFechasActivas()) {
                return Optional.of(Bloqueo.MEDICO_CON_TURNOS_ACTIVOS);
            }
            if (agenda.tieneConsultasAgendadas()) {
                return Optional.of(Bloqueo.MEDICO_CON_CONSULTAS_AGENDADAS);
            }
        }
        return Optional.empty();
    }
}
