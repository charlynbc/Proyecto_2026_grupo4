package uy.edu.proyecto.backend.usuario;

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

import uy.edu.proyecto.backend.auth.TokenHash;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.DatosPersonalesRepository.ContactoCuenta;

class DatosPersonalesServiceTest {

    private final DatosPersonalesRepository repository =
            mock(DatosPersonalesRepository.class);
    private final ApplicationEventPublisher eventPublisher =
            mock(ApplicationEventPublisher.class);
    private final DatosPersonalesService service = new DatosPersonalesService(
            repository,
            eventPublisher,
            24
    );

    private ContactoCuenta contactoActual() {
        return new ContactoCuenta(
                "viejo@example.org",
                "Calle Vieja 1",
                "099111222",
                null
        );
    }

    private DatosPersonalesResponse datos(String correo) {
        return new DatosPersonalesResponse(
                42L, "45678911", "Ana", "Perez", "SOCIO", correo,
                null, "099111222", null, "Calle Vieja 1"
        );
    }

    @Test
    void obtenerDevuelveDatosConCorreoPendiente() {
        when(repository.buscarDatos(42L)).thenReturn(
                Optional.of(datos("viejo@example.org")));
        when(repository.buscarCorreoPendiente(42L))
                .thenReturn(Optional.of("nuevo@example.org"));

        DatosPersonalesResponse r = service.obtener(42L);

        assertEquals("45678911", r.ci());
        assertEquals("viejo@example.org", r.correo());
        assertEquals("nuevo@example.org", r.correoPendiente());
    }

    @Test
    void actualizarContactoAplicaSoloLosCamposEnviados() {
        when(repository.bloquearCuentaHabilitada(42L))
                .thenReturn(Optional.of(contactoActual()));
        when(repository.buscarDatos(42L))
                .thenReturn(Optional.of(datos("viejo@example.org")));

        service.actualizar(42L, new ActualizarDatosPersonalesRequest(
                "Calle Nueva 9", null, null, null));

        verify(repository).actualizarContacto(
                42L, "Calle Nueva 9", "099111222", null);
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void telefono2VacioLoBorraYTelefono2AusenteLoConserva() {
        when(repository.bloquearCuentaHabilitada(42L))
                .thenReturn(Optional.of(new ContactoCuenta(
                        "viejo@example.org", "Calle Vieja 1",
                        "099111222", "099333444")));
        when(repository.buscarDatos(42L))
                .thenReturn(Optional.of(datos("viejo@example.org")));

        service.actualizar(42L, new ActualizarDatosPersonalesRequest(
                null, null, "", null));
        verify(repository).actualizarContacto(
                42L, "Calle Vieja 1", "099111222", null);

        service.actualizar(42L, new ActualizarDatosPersonalesRequest(
                null, "099555666", null, null));
        verify(repository).actualizarContacto(
                42L, "Calle Vieja 1", "099555666", "099333444");
    }

    @Test
    void correoNuevoGeneraEnlaceInvalidaAnterioresYPublicaEvento() {
        OffsetDateTime antes = OffsetDateTime.now(ZoneOffset.UTC);
        when(repository.bloquearCuentaHabilitada(42L))
                .thenReturn(Optional.of(contactoActual()));
        when(repository.buscarDatos(42L))
                .thenReturn(Optional.of(datos("viejo@example.org")));

        service.actualizar(42L, new ActualizarDatosPersonalesRequest(
                null, null, null, "  Nuevo@Example.org  "));

        verify(repository).invalidarEnlacesCambioCorreo(42L);
        ArgumentCaptor<String> hash = ArgumentCaptor.forClass(String.class);
        ArgumentCaptor<OffsetDateTime> vence =
                ArgumentCaptor.forClass(OffsetDateTime.class);
        verify(repository).crearEnlaceCambioCorreo(
                eq(42L), hash.capture(), eq("Nuevo@Example.org"),
                vence.capture());
        assertTrue(vence.getValue()
                .isAfter(antes.plusHours(24).minusSeconds(1)));

        ArgumentCaptor<CambioCorreoSolicitado> evento =
                ArgumentCaptor.forClass(CambioCorreoSolicitado.class);
        verify(eventPublisher).publishEvent(evento.capture());
        assertEquals("Nuevo@Example.org", evento.getValue().correoNuevo());
        assertEquals(TokenHash.sha256(evento.getValue().token()),
                hash.getValue());
    }

    @Test
    void mismoCorreoNoGeneraEnlaceNiEvento() {
        when(repository.bloquearCuentaHabilitada(42L))
                .thenReturn(Optional.of(contactoActual()));
        when(repository.buscarDatos(42L))
                .thenReturn(Optional.of(datos("viejo@example.org")));

        service.actualizar(42L, new ActualizarDatosPersonalesRequest(
                null, null, null, "VIEJO@example.org"));

        verify(repository, never()).invalidarEnlacesCambioCorreo(42L);
        verify(repository, never()).crearEnlaceCambioCorreo(
                eq(42L), any(), any(), any());
        verifyNoInteractions(eventPublisher);
    }

    @Test
    void cuentaInactivaNoPuedeEditar() {
        when(repository.bloquearCuentaHabilitada(42L))
                .thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () ->
                service.actualizar(42L, new ActualizarDatosPersonalesRequest(
                        "Calle Nueva 9", null, null, null)));

        assertEquals(HttpStatus.UNAUTHORIZED, error.getStatus());
        assertEquals("NO_AUTENTICADO", error.getCode());
        verify(repository, never()).actualizarContacto(
                eq(42L), any(), any(), any());
    }

    @Test
    void validacionesRechazanAntesDeTocarLaBase() {
        assertValidacion(null);
        assertValidacion(new ActualizarDatosPersonalesRequest(
                null, null, null, null));
        assertValidacion(new ActualizarDatosPersonalesRequest(
                "   ", null, null, null));
        assertValidacion(new ActualizarDatosPersonalesRequest(
                null, "", null, null));
        assertValidacion(new ActualizarDatosPersonalesRequest(
                null, "0".repeat(31), null, null));
        assertValidacion(new ActualizarDatosPersonalesRequest(
                null, null, "0".repeat(31), null));
        assertValidacion(new ActualizarDatosPersonalesRequest(
                null, null, null, "sin-arroba"));
        assertValidacion(new ActualizarDatosPersonalesRequest(
                null, null, null, "a@b".repeat(90)));

        verify(repository, never()).bloquearCuentaHabilitada(42L);
        verifyNoInteractions(eventPublisher);
    }

    private void assertValidacion(ActualizarDatosPersonalesRequest request) {
        ApiException error = assertThrows(ApiException.class, () ->
                service.actualizar(42L, request));
        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
    }

    @Test
    void confirmarCambioCorreoConsumeElEnlace() {
        when(repository.confirmarCambioCorreo(TokenHash.sha256("tok")))
                .thenReturn(Optional.of(42L));

        service.confirmarCambioCorreo(new ConfirmarCambioCorreoRequest("tok"));

        verify(repository).confirmarCambioCorreo(TokenHash.sha256("tok"));
    }

    @Test
    void confirmarConEnlaceInvalidoRechaza() {
        when(repository.confirmarCambioCorreo(any()))
                .thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () ->
                service.confirmarCambioCorreo(
                        new ConfirmarCambioCorreoRequest("tok")));

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("ENLACE_INVALIDO", error.getCode());
    }

    @Test
    void confirmarSinTokenRechaza() {
        ApiException error = assertThrows(ApiException.class, () ->
                service.confirmarCambioCorreo(
                        new ConfirmarCambioCorreoRequest(" ")));
        assertEquals("VALIDACION", error.getCode());
    }
}
