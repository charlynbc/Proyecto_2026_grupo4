package uy.edu.proyecto.backend.usuario;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.context.ApplicationEventPublisher;

import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;
import uy.edu.proyecto.backend.usuario.DatosPersonalesRepository.ContactoCuenta;

// La validez del enlace de cambio de correo sale de ParametroService.
class DatosPersonalesEnlaceParametrizadoTest {

    private final DatosPersonalesRepository repository = mock(DatosPersonalesRepository.class);
    private final ApplicationEventPublisher eventos = mock(ApplicationEventPublisher.class);

    @Test
    void elEnlaceDeCambioDeCorreoVenceCuandoLoIndicaElParametro() {
        OffsetDateTime antes = OffsetDateTime.now(ZoneOffset.UTC);
        when(repository.bloquearCuentaHabilitada(42L)).thenReturn(Optional.of(
                new ContactoCuenta("viejo@example.org", "Calle Vieja 1", "099111222", null)));
        when(repository.buscarDatos(42L)).thenReturn(Optional.of(new DatosPersonalesResponse(
                42L, "45678911", "Ana", "Perez", "SOCIO", "viejo@example.org",
                null, "099111222", null, "Calle Vieja 1")));
        DatosPersonalesService servicio = new DatosPersonalesService(
                repository, eventos,
                ParametrosDePrueba.nuevo().enlaces(7, 36, 9).construir());

        servicio.actualizar(42L, new ActualizarDatosPersonalesRequest(
                null, null, null, "nuevo@example.org"));

        ArgumentCaptor<OffsetDateTime> vence = ArgumentCaptor.forClass(OffsetDateTime.class);
        verify(repository).crearEnlaceCambioCorreo(
                eq(42L), org.mockito.ArgumentMatchers.any(), eq("nuevo@example.org"),
                vence.capture());
        assertTrue(vence.getValue().isAfter(antes.plusHours(36).minusSeconds(1)));
        assertTrue(vence.getValue().isBefore(
                OffsetDateTime.now(ZoneOffset.UTC).plusHours(36).plusSeconds(1)));
        ArgumentCaptor<CambioCorreoSolicitado> evento =
                ArgumentCaptor.forClass(CambioCorreoSolicitado.class);
        verify(eventos).publishEvent(evento.capture());
        assertEquals(36, evento.getValue().validezHoras());
    }
}
