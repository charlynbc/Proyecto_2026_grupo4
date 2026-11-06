package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CuentaRepository.CuentaCompleta;

class CorreccionUsuarioServiceTest {

    private static final LocalDate HOY = LocalDate.of(2026, 11, 4);

    private final CuentaRepository repository = mock(CuentaRepository.class);
    private final Clock clock = Clock.fixed(
            Instant.parse("2026-11-04T12:00:00Z"), ZoneId.of("America/Montevideo"));

    private final CorreccionUsuarioService service =
            new CorreccionUsuarioService(repository, clock);

    private CuentaCompleta cuentaSocio() {
        return new CuentaCompleta(
                10L, "12345678", "Sofia", "Socia", LocalDate.of(1985, 5, 5),
                "SOCIO", "sofia@ejemplo.invalid", "099111222", null,
                "Calle Falsa 123", true, true);
    }

    private CuentaCompleta cuentaMedico() {
        return new CuentaCompleta(
                20L, "23456789", "Mario", "Medina", LocalDate.of(1980, 3, 3),
                "MEDICO", "mario@ejemplo.invalid", "099333444", null,
                "Calle 1", true, true);
    }

    private CorreccionUsuarioRequest vacio() {
        return new CorreccionUsuarioRequest(
                null, null, null, null, null, null, null, null, null);
    }

    @Test
    void detalleDeSocioIncluyeTodosLosCamposSinModificarDatos() {
        when(repository.buscarCuentaCompleta(10L)).thenReturn(Optional.of(cuentaSocio()));

        CorreccionUsuarioResponse detalle = service.obtener(10L);

        assertEquals(10L, detalle.id());
        assertEquals("12345678", detalle.ci());
        assertEquals(LocalDate.of(1985, 5, 5), detalle.fechaNacimiento());
        assertEquals("099111222", detalle.telefono1());
        assertEquals("Calle Falsa 123", detalle.direccion());
        assertEquals(List.of(), detalle.especialidadIds());
        verify(repository).buscarCuentaCompleta(10L);
        org.mockito.Mockito.verify(repository, never()).especialidadesDelMedico(anyLong());
        org.mockito.Mockito.verify(repository, never()).actualizarContactoCuenta(
                anyLong(), org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any(), org.mockito.ArgumentMatchers.any(),
                org.mockito.ArgumentMatchers.any());
    }

    @Test
    void detalleDeMedicoTraeEspecialidades() {
        when(repository.buscarCuentaCompleta(20L)).thenReturn(Optional.of(cuentaMedico()));
        when(repository.especialidadesDelMedico(20L)).thenReturn(List.of(3L, 7L));

        CorreccionUsuarioResponse detalle = service.obtener(20L);

        assertEquals("MEDICO", detalle.rol());
        assertEquals(List.of(3L, 7L), detalle.especialidadIds());
        verify(repository).buscarCuentaCompleta(20L);
        verify(repository).especialidadesDelMedico(20L);
    }

    @Test
    void detalleDeCuentaInexistenteResponde404() {
        when(repository.buscarCuentaCompleta(99L)).thenReturn(Optional.empty());
        ApiException error = assertThrows(ApiException.class, () -> service.obtener(99L));
        assertEquals(HttpStatus.NOT_FOUND, error.getStatus());
        assertEquals("USUARIO_NO_ENCONTRADO", error.getCode());
    }

    @Test
    void rechazaSolicitudSinCambios() {
        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(10L, vacio()));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaCuentaInexistente() {
        when(repository.bloquearCuentaCompleta(99L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(99L,
                        new CorreccionUsuarioRequest(
                                null, "Nuevo", null, null, null, null, null, null, null)));

        assertEquals(HttpStatus.NOT_FOUND, error.getStatus());
        assertEquals("USUARIO_NO_ENCONTRADO", error.getCode());
    }

    @Test
    void rechazaCiInvalida() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(10L,
                        new CorreccionUsuarioRequest(
                                "12345670", null, null, null, null, null, null, null, null)));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("CI_INVALIDA", error.getCode());
    }

    @Test
    void rechazaCiDeOtraPersona() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));
        when(repository.existePersona("34567894")).thenReturn(true);

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(10L,
                        new CorreccionUsuarioRequest(
                                "34567894", null, null, null, null, null, null, null, null)));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("CI_EN_USO", error.getCode());
        verify(repository, never()).actualizarPersona(
                anyString(), anyString(), anyString(), anyString(),
                org.mockito.ArgumentMatchers.any());
    }

    @Test
    void corrigeDatosDePersonaParaTodasLasCuentas() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));
        when(repository.existePersona("34567894")).thenReturn(false);

        var respuesta = service.corregir(10L,
                new CorreccionUsuarioRequest(
                        "3.456.789-4", "Sofia Elena", "Socia Nueva",
                        LocalDate.of(1985, 6, 6), null, null, null, null, null));

        assertEquals("34567894", respuesta.ci());
        assertEquals("Sofia Elena", respuesta.nombre());
        assertEquals("Socia Nueva", respuesta.apellido());
        assertEquals(LocalDate.of(1985, 6, 6), respuesta.fechaNacimiento());
        assertEquals("SOCIO", respuesta.rol());
        verify(repository).actualizarPersona(
                "12345678", "34567894", "Sofia Elena", "Socia Nueva",
                LocalDate.of(1985, 6, 6));
        verify(repository, never()).actualizarContactoCuenta(
                anyLong(), anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void corrigeContactoDeLaCuenta() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));

        var respuesta = service.corregir(10L,
                new CorreccionUsuarioRequest(
                        null, null, null, null, "  SOFIA@NUEVO.INVALID  ",
                        "099000111", "", "  Nueva Direccion 1  ", null));

        assertEquals("sofia@nuevo.invalid", respuesta.correo());
        assertEquals("099000111", respuesta.telefono1());
        assertNull(respuesta.telefono2());
        assertEquals("Nueva Direccion 1", respuesta.direccion());
        verify(repository).actualizarContactoCuenta(
                10L, "sofia@nuevo.invalid", "099000111", null, "Nueva Direccion 1");
        verify(repository, never()).actualizarPersona(
                anyString(), anyString(), anyString(), anyString(),
                org.mockito.ArgumentMatchers.any());
    }

    @Test
    void rechazaCorreoInvalido() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(10L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, "no-es-correo",
                                null, null, null, null)));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void rechazaTelefono1Vacio() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(10L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, "   ",
                                null, null, null)));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
    }

    @Test
    void noBorraDireccionDeCuentaActivada() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(10L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, null, null, "", null)));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verify(repository, never()).actualizarContactoCuenta(
                anyLong(), anyString(), anyString(), anyString(), anyString());
    }

    @Test
    void borraDireccionDeCuentaPendienteDePrimerIngreso() {
        CuentaCompleta pendiente = new CuentaCompleta(
                11L, "12345678", "Nora", "Nueva", LocalDate.of(1990, 1, 1),
                "SOCIO", "nora@ejemplo.invalid", "099111222", null,
                null, true, false);
        when(repository.bloquearCuentaCompleta(11L))
                .thenReturn(Optional.of(pendiente));

        var respuesta = service.corregir(11L,
                new CorreccionUsuarioRequest(
                        null, null, null, null, null, null, null, "", null));

        assertNull(respuesta.direccion());
        verify(repository).actualizarContactoCuenta(
                11L, "nora@ejemplo.invalid", "099111222", null, null);
    }

    @Test
    void especialidadesSoloCorrespondenAMedicos() {
        when(repository.bloquearCuentaCompleta(10L))
                .thenReturn(Optional.of(cuentaSocio()));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(10L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, null, null, null,
                                List.of(1L))));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void medicoRequiereAlMenosUnaEspecialidad() {
        when(repository.bloquearCuentaCompleta(20L))
                .thenReturn(Optional.of(cuentaMedico()));
        when(repository.especialidadesDelMedico(20L)).thenReturn(List.of(1L));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(20L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, null, null, null,
                                List.of())));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
    }

    @Test
    void rechazaEspecialidadesRepetidas() {
        when(repository.bloquearCuentaCompleta(20L))
                .thenReturn(Optional.of(cuentaMedico()));
        when(repository.especialidadesDelMedico(20L)).thenReturn(List.of(1L));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(20L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, null, null, null,
                                List.of(1L, 1L))));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
    }

    @Test
    void rechazaEspecialidadesInexistentes() {
        when(repository.bloquearCuentaCompleta(20L))
                .thenReturn(Optional.of(cuentaMedico()));
        when(repository.especialidadesDelMedico(20L)).thenReturn(List.of(1L));
        when(repository.especialidadesExistentes(List.of(1L, 2L)))
                .thenReturn(List.of(1L));

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(20L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, null, null, null,
                                List.of(1L, 2L))));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
    }

    @Test
    void noQuitaEspecialidadConTurnosVigentes() {
        when(repository.bloquearCuentaCompleta(20L))
                .thenReturn(Optional.of(cuentaMedico()));
        when(repository.especialidadesDelMedico(20L)).thenReturn(List.of(1L, 2L));
        when(repository.especialidadesExistentes(List.of(2L)))
                .thenReturn(List.of(2L));
        when(repository.medicoTieneTurnosVigentesEnEspecialidad(20L, 1L, HOY))
                .thenReturn(true);

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(20L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, null, null, null,
                                List.of(2L))));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("ESPECIALIDAD_EN_USO", error.getCode());
        verify(repository, never()).eliminarEspecialidadDelMedico(anyLong(), anyLong());
    }

    @Test
    void noQuitaEspecialidadConConsultasFuturas() {
        when(repository.bloquearCuentaCompleta(20L))
                .thenReturn(Optional.of(cuentaMedico()));
        when(repository.especialidadesDelMedico(20L)).thenReturn(List.of(1L, 2L));
        when(repository.especialidadesExistentes(List.of(2L)))
                .thenReturn(List.of(2L));
        when(repository.medicoTieneTurnosVigentesEnEspecialidad(20L, 1L, HOY))
                .thenReturn(false);
        when(repository.medicoTieneConsultasFuturasEnEspecialidad(20L, 1L, HOY))
                .thenReturn(true);

        ApiException error = assertThrows(ApiException.class,
                () -> service.corregir(20L,
                        new CorreccionUsuarioRequest(
                                null, null, null, null, null, null, null, null,
                                List.of(2L))));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("ESPECIALIDAD_EN_USO", error.getCode());
        verify(repository, never()).eliminarEspecialidadDelMedico(anyLong(), anyLong());
    }

    @Test
    void reemplazaEspecialidadesLibres() {
        when(repository.bloquearCuentaCompleta(20L))
                .thenReturn(Optional.of(cuentaMedico()));
        when(repository.especialidadesDelMedico(20L)).thenReturn(List.of(1L, 2L));
        when(repository.especialidadesExistentes(List.of(2L, 3L)))
                .thenReturn(List.of(2L, 3L));
        when(repository.medicoTieneTurnosVigentesEnEspecialidad(20L, 1L, HOY))
                .thenReturn(false);
        when(repository.medicoTieneConsultasFuturasEnEspecialidad(20L, 1L, HOY))
                .thenReturn(false);

        var respuesta = service.corregir(20L,
                new CorreccionUsuarioRequest(
                        null, null, null, null, null, null, null, null,
                        List.of(2L, 3L)));

        assertEquals(List.of(2L, 3L), respuesta.especialidadIds());
        verify(repository).eliminarEspecialidadDelMedico(20L, 1L);
        verify(repository).asociarEspecialidades(20L, List.of(3L));
    }
}
