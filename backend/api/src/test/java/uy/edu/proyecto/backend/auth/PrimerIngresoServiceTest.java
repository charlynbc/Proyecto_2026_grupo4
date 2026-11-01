package uy.edu.proyecto.backend.auth;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
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

import uy.edu.proyecto.backend.auth.PrimerIngresoRepository.CuentaPendiente;
import uy.edu.proyecto.backend.exception.ApiException;

class PrimerIngresoServiceTest {

    private final PrimerIngresoRepository repository =
            mock(PrimerIngresoRepository.class);
    private final PasswordEncoder passwordEncoder = mock(PasswordEncoder.class);
    private final ApplicationEventPublisher eventPublisher =
            mock(ApplicationEventPublisher.class);
    private final PrimerIngresoService service = new PrimerIngresoService(
            repository,
            passwordEncoder,
            eventPublisher,
            8,
            24
    );

    @Test
    void solicitudRespondeIgualConCuentaPendienteYPublicaCorreoTrasCommit() {
        OffsetDateTime antes = OffsetDateTime.now(ZoneOffset.UTC);
        when(repository.buscarCuentaPendiente("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaPendiente(
                        12L,
                        "ana@example.org",
                        "Ana"
                )));

        SolicitudPrimerIngresoResponse response = service.solicitar(
                new SolicitarPrimerIngresoRequest("67890127", "SOCIO")
        );

        assertEquals(
                "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.",
                response.message()
        );

        ArgumentCaptor<PrimerIngresoLinkSolicitado> event =
                ArgumentCaptor.forClass(PrimerIngresoLinkSolicitado.class);
        ArgumentCaptor<String> hash = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<OffsetDateTime> expiry =
                ArgumentCaptor.forClass(OffsetDateTime.class);
        verify(repository).invalidarEnlacesPendientes(12L);
        verify(repository).crearEnlace(eq(12L), hash.capture(), expiry.capture());
        verify(eventPublisher).publishEvent(event.capture());
        assertEquals("ana@example.org", event.getValue().correo());
        assertEquals(12L, event.getValue().idCuenta());
        assertEquals(TokenHash.sha256(event.getValue().token()), hash.getValue());
        assertTrue(expiry.getValue().isAfter(antes.plusHours(24).minusSeconds(1)));
        assertTrue(expiry.getValue().isBefore(
                OffsetDateTime.now(ZoneOffset.UTC).plusHours(24).plusSeconds(1)
        ));
    }

    @Test
    void cuentaActivaRecibeInstruccionesDeRecuperacionSinCrearEnlace() {
        when(repository.buscarCuentaPendiente("67890127", "SOCIO"))
                .thenReturn(Optional.empty());
        when(repository.buscarCuentaActiva("67890127", "SOCIO"))
                .thenReturn(Optional.of(new CuentaPendiente(
                        12L,
                        "ana@example.org",
                        "Ana"
                )));

        SolicitudPrimerIngresoResponse response = service.solicitar(
                new SolicitarPrimerIngresoRequest("67890127", "SOCIO")
        );

        assertEquals(
                "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.",
                response.message()
        );
        ArgumentCaptor<CuentaActivaPrimerIngresoSolicitada> event =
                ArgumentCaptor.forClass(CuentaActivaPrimerIngresoSolicitada.class);
        verify(eventPublisher).publishEvent(event.capture());
        assertEquals("ana@example.org", event.getValue().correo());
        assertEquals(12L, event.getValue().idCuenta());
        assertFalse(event.getValue().toString().contains("ana@example.org"));
        verify(repository, never()).invalidarEnlacesPendientes(any());
        verify(repository, never()).crearEnlace(any(), any(), any());
    }

    @Test
    void solicitudSinCuentaDevuelveElMismoMensajeSinPublicarCorreo() {
        when(repository.buscarCuentaPendiente("67890127", "EMPLEADO"))
                .thenReturn(Optional.empty());
        when(repository.buscarCuentaActiva("67890127", "EMPLEADO"))
                .thenReturn(Optional.empty());

        SolicitudPrimerIngresoResponse response = service.solicitar(
                new SolicitarPrimerIngresoRequest("67890127", "EMPLEADO")
        );

        assertEquals(
                "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.",
                response.message()
        );
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void solicitudRechazaAccesoInvalidoSinConsultarLaCuenta() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.solicitar(
                        new SolicitarPrimerIngresoRequest("67890127", "MEDICO")
                )
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository, eventPublisher);
    }

    @Test
    void completaPrimerIngresoConEnlaceYGuardaHashDeContrasena() {
        CuentaActivadaResponse cuenta = new CuentaActivadaResponse(
                12L,
                "67890127",
                "Ana",
                "Perez",
                "SOCIO",
                "ACTIVA",
                true
        );
        when(passwordEncoder.encode("claveSegura1")).thenReturn("hash-password");
        when(repository.activarConEnlace(
                eq(TokenHash.sha256("token-valido")),
                eq("Av. 18 de Julio"),
                eq("099111222"),
                eq("098222333"),
                eq("hash-password")
        )).thenReturn(Optional.of(cuenta));

        CuentaActivadaResponse response = service.completar(
                new CompletarPrimerIngresoRequest(
                        "token-valido",
                        " Av. 18 de Julio ",
                        "099111222",
                        " 098222333 ",
                        "claveSegura1"
                )
        );

        assertEquals(12L, response.id());
        assertEquals("SOCIO", response.rol());
        assertEquals(true, response.activada());
        verify(repository).activarConEnlace(
                TokenHash.sha256("token-valido"),
                "Av. 18 de Julio",
                "099111222",
                "098222333",
                "hash-password"
        );
    }

    @Test
    void enlaceVencidoUsadoODeCuentaInactivaDevuelveElMismoError() {
        when(passwordEncoder.encode("claveSegura1")).thenReturn("hash-password");
        when(repository.activarConEnlace(any(), any(), any(), any(), any()))
                .thenReturn(Optional.empty());

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.completar(new CompletarPrimerIngresoRequest(
                        "token-invalido",
                        "Direccion",
                        "099111222",
                        null,
                        "claveSegura1"
                ))
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("ENLACE_INVALIDO", error.getCode());
        assertEquals(
                "El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.",
                error.getMessage()
        );
    }

    @Test
    void rechazaContrasenaCortaAntesDeConsultarElEnlace() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.completar(new CompletarPrimerIngresoRequest(
                        "token-valido",
                        "Direccion",
                        "099111222",
                        null,
                        "corta"
                ))
        );

        assertEquals("VALIDACION", error.getCode());
        verify(repository, never()).activarConEnlace(
                any(),
                any(),
                any(),
                any(),
                any()
        );
        verifyNoInteractions(passwordEncoder);
    }

    @Test
    void rechazaDireccionAusenteAntesDeConsultarElEnlace() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.completar(new CompletarPrimerIngresoRequest(
                        "token-valido",
                        " ",
                        "099111222",
                        null,
                        "claveSegura1"
                ))
        );

        assertEquals("VALIDACION", error.getCode());
        verify(repository, never()).activarConEnlace(any(), any(), any(), any(), any());
        verifyNoInteractions(passwordEncoder);
    }

    @Test
    void rechazaTelefonoAusenteAntesDeConsultarElEnlace() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.completar(new CompletarPrimerIngresoRequest(
                        "token-valido",
                        "Direccion",
                        " ",
                        null,
                        "claveSegura1"
                ))
        );

        assertEquals("VALIDACION", error.getCode());
        verify(repository, never()).activarConEnlace(any(), any(), any(), any(), any());
        verifyNoInteractions(passwordEncoder);
    }
}
