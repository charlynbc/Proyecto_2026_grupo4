package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;
import java.util.Set;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import uy.edu.proyecto.backend.auth.SesionRepository;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CuentaRepository.CuentaEstado;

/**
 * El valor de puedeInactivar del listado tiene que coincidir con lo que
 * responde inactivar sobre la misma cuenta y el mismo estado de la base:
 * si inactivar rechaza, el listado dice false; si inactiva, dice true.
 */
class ParidadInactivarListadoTest {

    private static final long ADMIN = 1L;
    private static final LocalDate HOY = LocalDate.of(2026, 11, 4);
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-11-04T12:00:00Z"), ZoneId.of("America/Montevideo"));

    static List<Arguments> casos() {
        // id, rol, habilitada, turnos activos, consultas agendadas, puede inactivar
        return List.of(
                Arguments.of(1L, "ADMINISTRADOR", true, false, false, false),
                Arguments.of(2L, "FUNCIONARIO", true, false, false, true),
                Arguments.of(3L, "FUNCIONARIO", false, false, false, false),
                Arguments.of(4L, "SOCIO", true, false, false, false),
                Arguments.of(5L, "MEDICO", true, true, false, false),
                Arguments.of(6L, "MEDICO", true, false, true, false),
                Arguments.of(7L, "MEDICO", true, false, false, true),
                Arguments.of(8L, "ADMINISTRADOR", true, false, false, true)
        );
    }

    @ParameterizedTest
    @MethodSource("casos")
    void elListadoDiceLoMismoQueResponderiaInactivar(
            long id, String rol, boolean habilitada,
            boolean turnos, boolean consultas, boolean esperado
    ) {
        CuentaRepository cuentas = mock(CuentaRepository.class);
        UsuarioPadronRepository padron = mock(UsuarioPadronRepository.class);
        SesionRepository sesiones = mock(SesionRepository.class);
        CuentaEstado estado = new CuentaEstado(
                id, "12345672", "Nombre", "Apellido", rol, habilitada,
                null, null, null, null);
        when(cuentas.bloquearCuentaParaEstado(id)).thenReturn(Optional.of(estado));
        when(cuentas.medicoTieneFechasActivasDesde(id, HOY)).thenReturn(turnos);
        when(cuentas.medicoTieneConsultasAgendadasDesde(id, HOY)).thenReturn(consultas);
        when(cuentas.inactivarCuenta(anyLong(), anyLong())).thenReturn(1);
        when(cuentas.medicosConFechasActivasDesde(any(), any()))
                .thenReturn(turnos ? Set.of(id) : Set.of());
        when(cuentas.medicosConConsultasAgendadasDesde(any(), any()))
                .thenReturn(consultas ? Set.of(id) : Set.of());
        when(padron.listar(null, null, null, "apellido", "asc", 0, 20))
                .thenReturn(new UsuarioCuentaPageResponse(List.of(new UsuarioCuentaDTO(
                        id, "12345672", "Nombre", "Apellido", rol, "u@example.org",
                        habilitada ? "ACTIVA" : "INACTIVA", true,
                        OffsetDateTime.parse("2026-09-01T09:00:00-03:00"), false)),
                        0, 20, 1));

        boolean enElListado = new UsuarioService(padron, cuentas, RELOJ)
                .listar(ADMIN, null, null, null, 0, 20)
                .items().get(0).puedeInactivar();
        boolean inactivarFunciona;
        try {
            new InactivacionEmpleadoService(cuentas, sesiones, RELOJ).inactivar(id, ADMIN);
            inactivarFunciona = true;
        } catch (ApiException rechazo) {
            inactivarFunciona = false;
        }

        assertEquals(esperado, enElListado);
        assertEquals(esperado, inactivarFunciona);
    }
}
