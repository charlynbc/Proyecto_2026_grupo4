package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.Optional;
import java.util.concurrent.atomic.AtomicInteger;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.usuario.ReglaInactivacion.AgendaMedico;
import uy.edu.proyecto.backend.usuario.ReglaInactivacion.Bloqueo;
import uy.edu.proyecto.backend.usuario.ReglaInactivacion.CuentaCandidata;

class ReglaInactivacionTest {

    private static final long ADMIN = 1L;

    private static AgendaMedico agenda(boolean fechas, boolean consultas) {
        return new AgendaMedico() {
            @Override
            public boolean tieneFechasActivas() {
                return fechas;
            }

            @Override
            public boolean tieneConsultasAgendadas() {
                return consultas;
            }
        };
    }

    private static Optional<Bloqueo> evaluar(
            long id, String rol, boolean habilitada, AgendaMedico agenda
    ) {
        return ReglaInactivacion.evaluar(
                id, ADMIN, () -> new CuentaCandidata(rol, habilitada), agenda);
    }

    @Test
    void laCuentaDelPropioAdministradorEstaBloqueada() {
        assertEquals(Optional.of(Bloqueo.CUENTA_PROPIA),
                evaluar(1L, "ADMINISTRADOR", true, agenda(false, false)));
    }

    @Test
    void laCuentaPropiaGanaSobreLaCuentaInactiva() {
        assertEquals(Optional.of(Bloqueo.CUENTA_PROPIA),
                evaluar(1L, "ADMINISTRADOR", false, agenda(false, false)));
    }

    @Test
    void laCuentaPropiaNoConsultaLosDatosDeLaCuenta() {
        AtomicInteger consultas = new AtomicInteger();

        Optional<Bloqueo> resultado = ReglaInactivacion.evaluar(1L, ADMIN, () -> {
            consultas.incrementAndGet();
            return new CuentaCandidata("ADMINISTRADOR", true);
        }, agenda(false, false));

        assertEquals(Optional.of(Bloqueo.CUENTA_PROPIA), resultado);
        assertEquals(0, consultas.get());
    }

    @Test
    void unSocioNoEsUnEmpleado() {
        assertEquals(Optional.of(Bloqueo.NO_ES_EMPLEADO),
                evaluar(4L, "SOCIO", true, agenda(false, false)));
    }

    @Test
    void unaCuentaInactivaYaEstaInactiva() {
        assertEquals(Optional.of(Bloqueo.YA_INACTIVA),
                evaluar(3L, "FUNCIONARIO", false, agenda(false, false)));
    }

    @Test
    void unMedicoConFechasActivasEstaBloqueado() {
        assertEquals(Optional.of(Bloqueo.MEDICO_CON_TURNOS_ACTIVOS),
                evaluar(5L, "MEDICO", true, agenda(true, false)));
    }

    @Test
    void unMedicoConConsultasAgendadasEstaBloqueado() {
        assertEquals(Optional.of(Bloqueo.MEDICO_CON_CONSULTAS_AGENDADAS),
                evaluar(6L, "MEDICO", true, agenda(false, true)));
    }

    @Test
    void conFechasYConsultasGanaLaDeFechas() {
        assertEquals(Optional.of(Bloqueo.MEDICO_CON_TURNOS_ACTIVOS),
                evaluar(5L, "MEDICO", true, agenda(true, true)));
    }

    @Test
    void unMedicoSinBloqueosSeInactiva() {
        assertEquals(Optional.empty(),
                evaluar(7L, "MEDICO", true, agenda(false, false)));
    }

    @Test
    void unFuncionarioActivoSeInactiva() {
        assertEquals(Optional.empty(),
                evaluar(2L, "FUNCIONARIO", true, agenda(false, false)));
    }

    @Test
    void otroAdministradorActivoSeInactiva() {
        assertEquals(Optional.empty(),
                evaluar(8L, "ADMINISTRADOR", true, agenda(false, false)));
    }

    @Test
    void laAgendaSoloSeConsultaParaMedicosActivos() {
        AgendaMedico explosiva = new AgendaMedico() {
            @Override
            public boolean tieneFechasActivas() {
                throw new AssertionError("no debia consultar la agenda");
            }

            @Override
            public boolean tieneConsultasAgendadas() {
                throw new AssertionError("no debia consultar la agenda");
            }
        };

        assertTrue(evaluar(2L, "FUNCIONARIO", true, explosiva).isEmpty());
        assertTrue(evaluar(3L, "MEDICO", false, explosiva).isPresent());
        assertTrue(evaluar(4L, "SOCIO", true, explosiva).isPresent());
    }
}
