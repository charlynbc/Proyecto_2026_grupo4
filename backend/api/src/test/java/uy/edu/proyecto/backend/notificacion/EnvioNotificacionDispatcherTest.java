package uy.edu.proyecto.backend.notificacion;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.correo.CorreoException;
import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.EnvioNotificacion;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EnvioNotificacionDispatcherTest {

    /** 03/11/2026 10:00 en Montevideo (UTC-3). */
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-11-03T13:00:00Z"), ZoneId.of("America/Montevideo"));
    private static final OffsetDateTime AHORA =
            OffsetDateTime.parse("2026-11-03T10:00:00-03:00");

    @Mock
    private TurnoFechasRepository repository;

    @Mock
    private CorreoSender correoSender;

    @Mock
    private PushSender pushSender;

    private EnvioNotificacionDispatcher dispatcher() {
        return new EnvioNotificacionDispatcher(repository, correoSender, pushSender, RELOJ);
    }

    @Test
    void marcaEnviadoSoloCuandoProveedorConfirmaLaEntrega() {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio("SUSPENSION", "CORREO", null)));
        when(repository.marcarEnvio(601L, "ENVIADO")).thenReturn(1);

        dispatcher().despachar(601L);

        verify(correoSender).enviar(new CorreoMensaje(
                "socio@example.com",
                "Turno suspendido",
                "Contenido de prueba"
        ));
        verify(repository).marcarEnvio(601L, "ENVIADO");
    }

    @ParameterizedTest
    @CsvSource({
            "AGENDA,Consulta agendada",
            "CANCELACION,Consulta cancelada",
            "SUSPENSION,Turno suspendido",
            "HISTORIA_ACTUALIZADA,Historia clínica actualizada",
            "RECORDATORIO,Recordatorio de consulta"
    })
    void elCorreoLlevaElTituloDelTipoYElContenidoGuardado(String tipo, String titulo) {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio(tipo, "CORREO", null)));
        when(repository.marcarEnvio(601L, "ENVIADO")).thenReturn(1);

        dispatcher().despachar(601L);

        verify(correoSender).enviar(new CorreoMensaje(
                "socio@example.com", titulo, "Contenido de prueba"));
    }

    @ParameterizedTest
    @CsvSource({
            "AGENDA,Consulta agendada",
            "CANCELACION,Consulta cancelada",
            "SUSPENSION,Turno suspendido",
            "HISTORIA_ACTUALIZADA,Historia clínica actualizada",
            "RECORDATORIO,Recordatorio de consulta"
    })
    void elPushLlevaElTituloYElTipoRealDelAviso(String tipo, String titulo) {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio(tipo, "PUSH", "token-1")));
        when(repository.marcarEnvio(601L, "ENVIADO")).thenReturn(1);

        dispatcher().despachar(601L);

        verify(pushSender).enviar(
                "token-1",
                titulo,
                "Contenido de prueba",
                Map.of("tipo", tipo, "notificacionId", "701")
        );
        verify(repository).marcarEnvio(601L, "ENVIADO");
    }

    @Test
    void registraFalloCuandoNoHayProveedorOperativo() {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio("SUSPENSION", "CORREO", null)));
        doThrow(new CorreoException("sin proveedor"))
                .when(correoSender).enviar(any());
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        dispatcher().despachar(601L);

        verify(repository).marcarEnvio(601L, "FALLIDO");
        verify(repository, never()).marcarEnvio(601L, "ENVIADO");
    }

    @Test
    void unaFallaInesperadaDelCorreoQuedaRegistradaComoFallidaEnVezDeSalirComoExcepcion() {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio("CANCELACION", "CORREO", null)));
        doThrow(new UnsupportedOperationException("proveedor caido"))
                .when(correoSender).enviar(any());
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        dispatcher().despachar(601L);

        verify(repository).marcarEnvio(601L, "FALLIDO");
        verify(repository, never()).marcarEnvio(601L, "ENVIADO");
    }

    @Test
    void unaFallaInesperadaDelPushQuedaRegistradaComoFallida() {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio("AGENDA", "PUSH", "token-1")));
        doThrow(new NullPointerException("respuesta vacia"))
                .when(pushSender).enviar(any(), any(), any(), any());
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        dispatcher().despachar(601L);

        verify(repository).marcarEnvio(601L, "FALLIDO");
    }

    @Test
    void unPushSinTokenQuedaFallidoSinLlamarAlProveedor() {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio("AGENDA", "PUSH", " ")));
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        dispatcher().despachar(601L);

        verifyNoInteractions(pushSender);
        verify(repository).marcarEnvio(601L, "FALLIDO");
    }

    @Test
    void unPushQueElProveedorRechazaQuedaFallido() {
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio("AGENDA", "PUSH", "token-1")));
        doThrow(new PushException("token vencido"))
                .when(pushSender).enviar(any(), any(), any(), any());
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        dispatcher().despachar(601L);

        verify(repository).marcarEnvio(601L, "FALLIDO");
    }

    @Test
    void informaSiElEnvioPersistidoNoExiste() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.empty());

        assertThrows(IllegalStateException.class, () -> dispatcher().despachar(601L));
    }

    @Test
    void despachaElSiguientePendienteDeCualquierTipo() {
        when(repository.bloquearSiguienteEnvioPendiente(AHORA)).thenReturn(Optional.of(601L));
        when(repository.buscarEnvio(601L))
                .thenReturn(Optional.of(envio("AGENDA", "CORREO", null)));
        when(repository.marcarEnvio(601L, "ENVIADO")).thenReturn(1);

        assertTrue(dispatcher().despacharSiguientePendiente());

        verify(repository).marcarEnvio(601L, "ENVIADO");
    }

    @Test
    void sinPendientesNoHaceNada() {
        when(repository.bloquearSiguienteEnvioPendiente(AHORA)).thenReturn(Optional.empty());

        assertFalse(dispatcher().despacharSiguientePendiente());

        verifyNoInteractions(correoSender, pushSender);
    }

    private EnvioNotificacion envio(String tipo, String canal, String token) {
        return new EnvioNotificacion(
                601L, 701L, tipo, canal, "socio@example.com", token,
                "Contenido de prueba",
                LocalDate.of(2026, 10, 21),
                LocalTime.of(9, 0),
                LocalTime.of(9, 20),
                "Cardiología",
                "Socio"
        );
    }
}
