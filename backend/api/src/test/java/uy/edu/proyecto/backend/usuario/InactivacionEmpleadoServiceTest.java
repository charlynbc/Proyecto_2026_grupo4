package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.auth.SesionRepository;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CuentaRepository.CuentaEstado;

class InactivacionEmpleadoServiceTest {

    private static final LocalDate HOY = LocalDate.of(2026, 11, 4);
    private static final long ADMIN = 1L;

    private final CuentaRepository repository = mock(CuentaRepository.class);
    private final SesionRepository sesionRepository = mock(SesionRepository.class);
    private final Clock clock = Clock.fixed(
            Instant.parse("2026-11-04T12:00:00Z"), ZoneId.of("America/Montevideo"));

    private final InactivacionEmpleadoService service =
            new InactivacionEmpleadoService(repository, sesionRepository, clock);

    private CuentaEstado empleado(long id, String rol, boolean habilitada) {
        return new CuentaEstado(
                id, "12345672", "Fabio", "Funcionario", rol, habilitada,
                null, null, null, null);
    }

    private CuentaEstado inactivado(CuentaEstado cuenta) {
        return new CuentaEstado(
                cuenta.id(), cuenta.ci(), cuenta.nombre(), cuenta.apellido(),
                cuenta.rol(), false,
                OffsetDateTime.of(2026, 11, 4, 12, 0, 0, 0, ZoneOffset.UTC),
                ADMIN, null, null);
    }

    private CuentaEstado reactivado(CuentaEstado cuenta) {
        return new CuentaEstado(
                cuenta.id(), cuenta.ci(), cuenta.nombre(), cuenta.apellido(),
                cuenta.rol(), true, null, null,
                OffsetDateTime.of(2026, 11, 4, 12, 30, 0, 0, ZoneOffset.UTC),
                ADMIN);
    }

    /* ---------- Inactivacion ---------- */

    @Test
    void inactivarPropiaCuentaSeRechaza() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.inactivar(ADMIN, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("AUTO_INACTIVACION_NO_PERMITIDA", error.getCode());
        verifyNoInteractions(repository, sesionRepository);
    }

    @Test
    void inactivarCuentaInexistenteDevuelve404() {
        when(repository.bloquearCuentaParaEstado(99L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class,
                () -> service.inactivar(99L, ADMIN));

        assertEquals(HttpStatus.NOT_FOUND, error.getStatus());
        assertEquals("USUARIO_NO_ENCONTRADO", error.getCode());
    }

    @Test
    void inactivarSocioSeRechaza() {
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(empleado(10L, "SOCIO", true)));

        ApiException error = assertThrows(ApiException.class,
                () -> service.inactivar(10L, ADMIN));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verify(repository, never()).inactivarCuenta(anyLong(), anyLong());
    }

    @Test
    void inactivarCuentaYaInactivaDevuelve409() {
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(empleado(10L, "FUNCIONARIO", false)));

        ApiException error = assertThrows(ApiException.class,
                () -> service.inactivar(10L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("CUENTA_YA_INACTIVA", error.getCode());
        verifyNoInteractions(sesionRepository);
    }

    @Test
    void inactivarFuncionarioRevocaSusSesionesYAudita() {
        CuentaEstado cuenta = empleado(10L, "FUNCIONARIO", true);
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(cuenta))
                .thenReturn(Optional.of(inactivado(cuenta)));
        when(repository.inactivarCuenta(10L, ADMIN)).thenReturn(1);

        EstadoCuentaResponse respuesta = service.inactivar(10L, ADMIN);

        assertEquals("INACTIVA", respuesta.estado());
        assertEquals(ADMIN, respuesta.ultimaInactivacionPor());
        assertEquals(OffsetDateTime.of(2026, 11, 4, 12, 0, 0, 0, ZoneOffset.UTC),
                respuesta.ultimaInactivacionEn());
        verify(repository).inactivarCuenta(10L, ADMIN);
        verify(sesionRepository).revocarOtrasSesiones(10L, null);
    }

    @Test
    void inactivarMedicoSinAgendaFunciona() {
        CuentaEstado cuenta = empleado(20L, "MEDICO", true);
        when(repository.bloquearCuentaParaEstado(20L))
                .thenReturn(Optional.of(cuenta))
                .thenReturn(Optional.of(inactivado(cuenta)));
        when(repository.medicoTieneFechasActivasDesde(20L, HOY)).thenReturn(false);
        when(repository.medicoTieneConsultasAgendadasDesde(20L, HOY)).thenReturn(false);
        when(repository.inactivarCuenta(20L, ADMIN)).thenReturn(1);

        EstadoCuentaResponse respuesta = service.inactivar(20L, ADMIN);

        assertEquals("INACTIVA", respuesta.estado());
        verify(repository).inactivarCuenta(20L, ADMIN);
    }

    @Test
    void inactivarMedicoConFechasActivasSeRechaza() {
        when(repository.bloquearCuentaParaEstado(20L))
                .thenReturn(Optional.of(empleado(20L, "MEDICO", true)));
        when(repository.medicoTieneFechasActivasDesde(20L, HOY)).thenReturn(true);

        ApiException error = assertThrows(ApiException.class,
                () -> service.inactivar(20L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("MEDICO_CON_TURNOS_ACTIVOS", error.getCode());
        verify(repository, never()).inactivarCuenta(anyLong(), anyLong());
        verifyNoInteractions(sesionRepository);
    }

    @Test
    void inactivarMedicoConConsultasAgendadasSeRechaza() {
        when(repository.bloquearCuentaParaEstado(20L))
                .thenReturn(Optional.of(empleado(20L, "MEDICO", true)));
        when(repository.medicoTieneFechasActivasDesde(20L, HOY)).thenReturn(false);
        when(repository.medicoTieneConsultasAgendadasDesde(20L, HOY)).thenReturn(true);

        ApiException error = assertThrows(ApiException.class,
                () -> service.inactivar(20L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("MEDICO_CON_CONSULTAS_AGENDADAS", error.getCode());
        verify(repository, never()).inactivarCuenta(anyLong(), anyLong());
    }

    @Test
    void inactivacionConcurrenteDevuelve409() {
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(empleado(10L, "FUNCIONARIO", true)));
        when(repository.inactivarCuenta(10L, ADMIN)).thenReturn(0);

        ApiException error = assertThrows(ApiException.class,
                () -> service.inactivar(10L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("CUENTA_YA_INACTIVA", error.getCode());
    }

    @Test
    void errorAlRevocarSesionesPropagaYRevientaLaTransaccion() {
        CuentaEstado cuenta = empleado(10L, "FUNCIONARIO", true);
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(cuenta));
        when(repository.inactivarCuenta(10L, ADMIN)).thenReturn(1);
        org.mockito.Mockito.doThrow(new IllegalStateException("falla"))
                .when(sesionRepository).revocarOtrasSesiones(10L, null);

        assertThrows(IllegalStateException.class, () -> service.inactivar(10L, ADMIN));
        // La excepcion interrumpe el metodo: no se relee ni se responde;
        // al ser RuntimeException la transaccion revierte la inactivacion.
    }

    /* ---------- Reactivacion ---------- */

    @Test
    void reactivarPropiaCuentaSeRechaza() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.reactivar(ADMIN, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("AUTO_INACTIVACION_NO_PERMITIDA", error.getCode());
        verifyNoInteractions(repository, sesionRepository);
    }

    @Test
    void reactivarCuentaInexistenteDevuelve404() {
        when(repository.bloquearCuentaParaEstado(99L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class,
                () -> service.reactivar(99L, ADMIN));

        assertEquals(HttpStatus.NOT_FOUND, error.getStatus());
        assertEquals("USUARIO_NO_ENCONTRADO", error.getCode());
    }

    @Test
    void reactivarSocioSeRechaza() {
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(empleado(10L, "SOCIO", false)));

        ApiException error = assertThrows(ApiException.class,
                () -> service.reactivar(10L, ADMIN));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void reactivarCuentaYaActivaDevuelve409() {
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(empleado(10L, "FUNCIONARIO", true)));

        ApiException error = assertThrows(ApiException.class,
                () -> service.reactivar(10L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("CUENTA_YA_ACTIVA", error.getCode());
    }

    @Test
    void reactivarConOtraCuentaEmpleadoHabilitadaDevuelve409() {
        CuentaEstado cuenta = empleado(10L, "FUNCIONARIO", false);
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(cuenta));
        when(repository.existeOtraCuentaEmpleadoHabilitada("12345672", 10L))
                .thenReturn(true);

        ApiException error = assertThrows(ApiException.class,
                () -> service.reactivar(10L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("EMPLEADO_DUPLICADO", error.getCode());
        verify(repository, never()).reactivarCuenta(anyLong(), anyLong());
    }

    @Test
    void reactivarRegistraAuditoria() {
        CuentaEstado cuenta = empleado(10L, "MEDICO", false);
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(cuenta))
                .thenReturn(Optional.of(reactivado(cuenta)));
        when(repository.existeOtraCuentaEmpleadoHabilitada("12345672", 10L))
                .thenReturn(false);
        when(repository.reactivarCuenta(10L, ADMIN)).thenReturn(1);

        EstadoCuentaResponse respuesta = service.reactivar(10L, ADMIN);

        assertEquals("ACTIVA", respuesta.estado());
        assertEquals(ADMIN, respuesta.ultimaReactivacionPor());
        assertEquals(OffsetDateTime.of(2026, 11, 4, 12, 30, 0, 0, ZoneOffset.UTC),
                respuesta.ultimaReactivacionEn());
        verify(repository).reactivarCuenta(10L, ADMIN);
        verifyNoInteractions(sesionRepository);
    }

    @Test
    void reactivacionConcurrentePorIndiceUnicoDevuelve409() {
        CuentaEstado cuenta = empleado(10L, "FUNCIONARIO", false);
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(cuenta));
        when(repository.existeOtraCuentaEmpleadoHabilitada("12345672", 10L))
                .thenReturn(false);
        when(repository.reactivarCuenta(10L, ADMIN))
                .thenThrow(new DuplicateKeyException("uq_cuenta_empleado_habilitado_ci"));

        ApiException error = assertThrows(ApiException.class,
                () -> service.reactivar(10L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("EMPLEADO_DUPLICADO", error.getCode());
    }

    @Test
    void reactivacionConcurrentePorFilaDevuelve409() {
        CuentaEstado cuenta = empleado(10L, "FUNCIONARIO", false);
        when(repository.bloquearCuentaParaEstado(10L))
                .thenReturn(Optional.of(cuenta));
        when(repository.existeOtraCuentaEmpleadoHabilitada(eq("12345672"), eq(10L)))
                .thenReturn(false);
        when(repository.reactivarCuenta(10L, ADMIN)).thenReturn(0);

        ApiException error = assertThrows(ApiException.class,
                () -> service.reactivar(10L, ADMIN));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("CUENTA_YA_ACTIVA", error.getCode());
    }

    @Test
    void reactivarNoTocaLasSesionesNiLosTurnos() {
        CuentaEstado cuenta = empleado(20L, "MEDICO", false);
        when(repository.bloquearCuentaParaEstado(20L))
                .thenReturn(Optional.of(cuenta))
                .thenReturn(Optional.of(reactivado(cuenta)));
        when(repository.existeOtraCuentaEmpleadoHabilitada("12345672", 20L))
                .thenReturn(false);
        when(repository.reactivarCuenta(20L, ADMIN)).thenReturn(1);

        service.reactivar(20L, ADMIN);

        verifyNoInteractions(sesionRepository);
        verify(repository, never()).medicoTieneFechasActivasDesde(anyLong(), any());
        verify(repository, never()).medicoTieneConsultasAgendadasDesde(anyLong(), any());
    }
}
