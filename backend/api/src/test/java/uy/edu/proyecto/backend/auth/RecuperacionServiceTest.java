package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;

import uy.edu.proyecto.backend.auth.RecuperacionRepository.CuentaRecuperacion;
import uy.edu.proyecto.backend.exception.ApiException;

class RecuperacionServiceTest {

    private final RecuperacionRepository repository =
            mock(RecuperacionRepository.class);
    private final SesionRepository sesionRepository =
            mock(SesionRepository.class);
    private final PasswordEncoder passwordEncoder =
            mock(PasswordEncoder.class);
    private final ApplicationEventPublisher eventPublisher =
            mock(ApplicationEventPublisher.class);
    private final RecuperacionService service = new RecuperacionService(
            repository,
            sesionRepository,
            passwordEncoder,
            eventPublisher,
            8,
            24
    );

    @Test
    void cuentaActivaGeneraEnlaceHasheadoYPublicaEvento() {
        OffsetDateTime antes = OffsetDateTime.now(ZoneOffset.UTC);
        when(repository.buscarCuentaActiva("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaRecuperacion(
                        12L, "ana@example.org", "Ana")));
        when(repository.ultimoEnlaceVigenteCreadoEn(12L))
                .thenReturn(Optional.empty());

        SolicitudPrimerIngresoResponse response = service.solicitar(
                new SolicitarRecuperacionRequest("67890127", "SOCIO"));

        assertEquals(
                "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.",
                response.message());
        verify(repository).invalidarEnlacesPendientes(12L);
        ArgumentCaptor<String> hash = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<OffsetDateTime> vence =
                ArgumentCaptor.forClass(OffsetDateTime.class);
        verify(repository).crearEnlace(eq(12L), hash.capture(), vence.capture());
        assertTrue(vence.getValue()
                .isAfter(antes.plusHours(24).minusSeconds(1)));

        ArgumentCaptor<RecuperacionLinkSolicitado> evento =
                ArgumentCaptor.forClass(RecuperacionLinkSolicitado.class);
        verify(eventPublisher).publishEvent(evento.capture());
        assertEquals("ana@example.org", evento.getValue().correo());
        assertEquals(TokenHash.sha256(evento.getValue().token()),
                hash.getValue());
    }

    @Test
    void respuestaEsIdenticaSiLaCuentaNoExiste() {
        when(repository.buscarCuentaActiva("67890127", "SOCIO"))
                .thenReturn(Optional.empty());
        when(repository.buscarCuentaPendiente("67890127", "SOCIO"))
                .thenReturn(Optional.empty());

        SolicitudPrimerIngresoResponse response = service.solicitar(
                new SolicitarRecuperacionRequest("67890127", "SOCIO"));

        assertEquals(
                "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.",
                response.message());
        verify(repository, never()).crearEnlace(any(), any(), any());
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void cuentaPendienteRecibeAvisoDePrimerIngresoSinEnlace() {
        when(repository.buscarCuentaActiva("67890127", "SOCIO"))
                .thenReturn(Optional.empty());
        when(repository.buscarCuentaPendiente("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaRecuperacion(
                        12L, "ana@example.org", "Ana")));

        service.solicitar(new SolicitarRecuperacionRequest("67890127", "SOCIO"));

        verify(repository, never()).crearEnlace(any(), any(), any());
        verify(eventPublisher).publishEvent(
                any(CuentaPendienteRecuperacionSolicitada.class));
    }

    @Test
    void solicitudRepetidaDentroDelMinutoNoGeneraOtroEnlace() {
        when(repository.buscarCuentaActiva("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaRecuperacion(
                        12L, "ana@example.org", "Ana")));
        when(repository.ultimoEnlaceVigenteCreadoEn(12L))
                .thenReturn(Optional.of(OffsetDateTime.now(ZoneOffset.UTC)
                        .minusSeconds(30)));

        SolicitudPrimerIngresoResponse response = service.solicitar(
                new SolicitarRecuperacionRequest("67890127", "SOCIO"));

        assertEquals(
                "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.",
                response.message());
        verify(repository, never()).invalidarEnlacesPendientes(12L);
        verify(repository, never()).crearEnlace(any(), any(), any());
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void solicitudConEnlaceAntiguoGeneraUnoNuevo() {
        when(repository.buscarCuentaActiva("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaRecuperacion(
                        12L, "ana@example.org", "Ana")));
        when(repository.ultimoEnlaceVigenteCreadoEn(12L))
                .thenReturn(Optional.of(OffsetDateTime.now(ZoneOffset.UTC)
                        .minusSeconds(120)));

        service.solicitar(new SolicitarRecuperacionRequest("67890127", "SOCIO"));

        verify(repository).invalidarEnlacesPendientes(12L);
        verify(repository).crearEnlace(eq(12L), any(), any());
        verify(eventPublisher).publishEvent(
                any(RecuperacionLinkSolicitado.class));
    }

    @Test
    void solicitudMalFormadaRechazaSinTocarLaBase() {
        assertValidacion(null);
        assertValidacion(new SolicitarRecuperacionRequest(null, "SOCIO"));
        assertValidacion(new SolicitarRecuperacionRequest("67890127", null));
        assertValidacion(new SolicitarRecuperacionRequest("67890127", "OTRO"));
        assertValidacion(new SolicitarRecuperacionRequest("123", "SOCIO"));

        verifyNoInteractions(eventPublisher);
    }

    private void assertValidacion(SolicitarRecuperacionRequest request) {
        ApiException error = assertThrows(ApiException.class, () ->
                service.solicitar(request));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void completarConsumeElEnlaceYRevocaTodasLasSesiones() {
        when(passwordEncoder.encode("Clave-Nueva-1")).thenReturn("hash-nuevo");
        when(repository.completarConEnlace(
                TokenHash.sha256("tok"), "hash-nuevo"))
                .thenReturn(Optional.of(12L));

        service.completar(new CompletarRecuperacionRequest(
                "tok", "Clave-Nueva-1"));

        verify(sesionRepository).revocarOtrasSesiones(12L, null);
    }

    @Test
    void completarConEnlaceInvalidoRechaza() {
        when(passwordEncoder.encode("Clave-Nueva-1")).thenReturn("hash-nuevo");
        when(repository.completarConEnlace(any(), eq("hash-nuevo")))
                .thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () ->
                service.completar(new CompletarRecuperacionRequest(
                        "tok", "Clave-Nueva-1")));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("ENLACE_INVALIDO", error.getCode());
        verifyNoInteractions(sesionRepository);
    }

    @Test
    void completarConDatosInvalidosNoConsumeElEnlace() {
        for (CompletarRecuperacionRequest request
                : new CompletarRecuperacionRequest[]{
                null,
                new CompletarRecuperacionRequest(null, "Clave-Nueva-1"),
                new CompletarRecuperacionRequest("tok", null),
                new CompletarRecuperacionRequest("tok", "corta"),
                new CompletarRecuperacionRequest("tok", "a".repeat(73))
        }) {
            ApiException error = assertThrows(ApiException.class, () ->
                    service.completar(request));
            assertEquals("VALIDACION", error.getCode());
        }
        verify(repository, never()).completarConEnlace(any(), any());
        verifyNoInteractions(sesionRepository);
    }
}
