package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.security.crypto.password.PasswordEncoder;

import uy.edu.proyecto.backend.auth.PrimerIngresoRepository.CuentaPendiente;
import uy.edu.proyecto.backend.auth.RecuperacionRepository.CuentaRecuperacion;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

// La longitud minima de contrasena y la validez de los enlaces salen de ParametroService.
class AuthParametrizadoTest {

    private final CuentaAuthRepository cuentaRepository = mock(CuentaAuthRepository.class);
    private final SesionRepository sesionRepository = mock(SesionRepository.class);
    private final PasswordEncoder passwordEncoder = mock(PasswordEncoder.class);
    private final PrimerIngresoRepository primerIngreso = mock(PrimerIngresoRepository.class);
    private final RecuperacionRepository recuperacion = mock(RecuperacionRepository.class);
    private final ApplicationEventPublisher eventos = mock(ApplicationEventPublisher.class);

    private CambioContrasenaService cambio(ParametroService parametros) {
        return new CambioContrasenaService(
                cuentaRepository, sesionRepository, passwordEncoder, parametros);
    }

    private PrimerIngresoService primerIngreso(ParametroService parametros) {
        return new PrimerIngresoService(primerIngreso, passwordEncoder, eventos, parametros);
    }

    private RecuperacionService recuperacion(ParametroService parametros) {
        return new RecuperacionService(
                recuperacion, sesionRepository, passwordEncoder, eventos, parametros);
    }

    // ---- Cambio de contrasena (RF-04)

    @Test
    void cambioConMinimoDeDoceRechazaUnaContrasenaDeOnceCaracteres() {
        CambioContrasenaService servicio = cambio(
                ParametrosDePrueba.nuevo().contrasenaMinima(12).construir());

        ApiException error = assertThrows(ApiException.class, () ->
                servicio.cambiar(42L,
                        new CambiarContrasenaRequest("Clave-Vieja-1", "abcdefghijk"), null));

        assertEquals("VALIDACION", error.getCode());
        assertEquals("La contrasena nueva debe tener al menos 12 caracteres",
                error.getMessage());
        verify(cuentaRepository, never()).bloquearCredencial(42L);
    }

    @Test
    void cambioConMinimoDeDoceAceptaUnaContrasenaDeDoceCaracteres() {
        when(cuentaRepository.bloquearCredencial(42L)).thenReturn(Optional.of("hash-actual"));
        when(passwordEncoder.matches("Clave-Vieja-1", "hash-actual")).thenReturn(true);
        when(passwordEncoder.encode("abcdefghijkl")).thenReturn("hash-nuevo");

        cambio(ParametrosDePrueba.nuevo().contrasenaMinima(12).construir()).cambiar(
                42L, new CambiarContrasenaRequest("Clave-Vieja-1", "abcdefghijkl"), null);

        verify(cuentaRepository).actualizarContrasena(42L, "hash-nuevo");
    }

    @Test
    void cambioConMinimoDeCuatroAceptaUnaContrasenaDeCuatroCaracteres() {
        when(cuentaRepository.bloquearCredencial(42L)).thenReturn(Optional.of("hash-actual"));
        when(passwordEncoder.matches("Clave-Vieja-1", "hash-actual")).thenReturn(true);
        when(passwordEncoder.encode("abcd")).thenReturn("hash-nuevo");

        cambio(ParametrosDePrueba.nuevo().contrasenaMinima(4).construir()).cambiar(
                42L, new CambiarContrasenaRequest("Clave-Vieja-1", "abcd"), null);

        verify(cuentaRepository).actualizarContrasena(42L, "hash-nuevo");
    }

    // ---- Primer ingreso (RF-02)

    private CompletarPrimerIngresoRequest completar(String password) {
        return new CompletarPrimerIngresoRequest(
                "token", "Direccion", "099111222", null, password);
    }

    @Test
    void primerIngresoConMinimoDeDoceRechazaUnaContrasenaDeOnceCaracteres() {
        PrimerIngresoService servicio = primerIngreso(
                ParametrosDePrueba.nuevo().contrasenaMinima(12).construir());

        ApiException error = assertThrows(ApiException.class, () ->
                servicio.completar(completar("abcdefghijk")));

        assertEquals("VALIDACION", error.getCode());
        verify(primerIngreso, never()).activarConEnlace(any(), any(), any(), any(), any());
    }

    @Test
    void primerIngresoConMinimoDeDoceAceptaUnaContrasenaDeDoceCaracteres() {
        when(passwordEncoder.encode("abcdefghijkl")).thenReturn("hash");
        when(primerIngreso.activarConEnlace(any(), any(), any(), any(), eq("hash")))
                .thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () ->
                primerIngreso(ParametrosDePrueba.nuevo().contrasenaMinima(12).construir())
                        .completar(completar("abcdefghijkl")));

        // Paso la validacion de largo: llego a consumir el enlace (que aqui no existe).
        assertEquals("ENLACE_INVALIDO", error.getCode());
    }

    @Test
    void primerIngresoUsaLaValidezDelEnlaceConfigurada() {
        OffsetDateTime antes = OffsetDateTime.now(ZoneOffset.UTC);
        when(primerIngreso.buscarCuentaPendiente("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaPendiente(12L, "ana@example.org", "Ana")));

        primerIngreso(ParametrosDePrueba.nuevo().enlaces(48, 7, 9).construir())
                .solicitar(new SolicitarPrimerIngresoRequest("67890127", "SOCIO"));

        ArgumentCaptor<OffsetDateTime> vence = ArgumentCaptor.forClass(OffsetDateTime.class);
        verify(primerIngreso).crearEnlace(eq(12L), any(), vence.capture());
        assertTrue(vence.getValue().isAfter(antes.plusHours(48).minusSeconds(1)));
        assertTrue(vence.getValue().isBefore(
                OffsetDateTime.now(ZoneOffset.UTC).plusHours(48).plusSeconds(1)));
        ArgumentCaptor<PrimerIngresoLinkSolicitado> evento =
                ArgumentCaptor.forClass(PrimerIngresoLinkSolicitado.class);
        verify(eventos).publishEvent(evento.capture());
        assertEquals(48, evento.getValue().validezHoras());
    }

    // ---- Recuperacion (RF-05)

    @Test
    void recuperacionConMinimoDeDoceRechazaUnaContrasenaDeOnceCaracteres() {
        RecuperacionService servicio = recuperacion(
                ParametrosDePrueba.nuevo().contrasenaMinima(12).construir());

        ApiException error = assertThrows(ApiException.class, () ->
                servicio.completar(new CompletarRecuperacionRequest("tok", "abcdefghijk")));

        assertEquals("VALIDACION", error.getCode());
        assertEquals("La contrasena debe tener al menos 12 caracteres", error.getMessage());
        verify(recuperacion, never()).completarConEnlace(any(), any());
    }

    @Test
    void recuperacionConMinimoDeDoceAceptaUnaContrasenaDeDoceCaracteres() {
        when(passwordEncoder.encode("abcdefghijkl")).thenReturn("hash");
        when(recuperacion.completarConEnlace(TokenHash.sha256("tok"), "hash"))
                .thenReturn(Optional.of(12L));

        recuperacion(ParametrosDePrueba.nuevo().contrasenaMinima(12).construir())
                .completar(new CompletarRecuperacionRequest("tok", "abcdefghijkl"));

        verify(sesionRepository).revocarOtrasSesiones(12L, null);
    }

    @Test
    void recuperacionUsaLaValidezDelEnlaceConfigurada() {
        OffsetDateTime antes = OffsetDateTime.now(ZoneOffset.UTC);
        when(recuperacion.buscarCuentaActiva("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaRecuperacion(12L, "ana@example.org", "Ana")));
        when(recuperacion.ultimoEnlaceVigenteCreadoEn(12L)).thenReturn(Optional.empty());

        recuperacion(ParametrosDePrueba.nuevo().enlaces(7, 9, 72).construir())
                .solicitar(new SolicitarRecuperacionRequest("67890127", "SOCIO"));

        ArgumentCaptor<OffsetDateTime> vence = ArgumentCaptor.forClass(OffsetDateTime.class);
        verify(recuperacion).crearEnlace(eq(12L), any(), vence.capture());
        assertTrue(vence.getValue().isAfter(antes.plusHours(72).minusSeconds(1)));
        assertTrue(vence.getValue().isBefore(
                OffsetDateTime.now(ZoneOffset.UTC).plusHours(72).plusSeconds(1)));
        ArgumentCaptor<RecuperacionLinkSolicitado> evento =
                ArgumentCaptor.forClass(RecuperacionLinkSolicitado.class);
        verify(eventos).publishEvent(evento.capture());
        assertEquals(72, evento.getValue().validezHoras());
    }
}
