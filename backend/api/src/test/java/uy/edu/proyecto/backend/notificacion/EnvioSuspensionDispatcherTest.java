package uy.edu.proyecto.backend.notificacion;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.correo.CorreoException;
import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.EnvioNotificacion;

import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class EnvioSuspensionDispatcherTest {

    @Mock
    private TurnoFechasRepository repository;

    @Mock
    private CorreoSender correoSender;

    @Test
    void marcaEnviadoSoloCuandoProveedorConfirmaLaEntrega() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.of(envio("CORREO")));
        EnvioSuspensionDispatcher dispatcher = new EnvioSuspensionDispatcher(
                repository, correoSender
        );
        when(repository.marcarEnvio(601L, "ENVIADO")).thenReturn(1);

        dispatcher.despachar(601L);

        verify(correoSender).enviar(new CorreoMensaje(
                "socio@example.com",
                "Turno suspendido",
                "Tu turno fue suspendido"
        ));
        verify(repository).marcarEnvio(601L, "ENVIADO");
    }

    @Test
    void registraFalloCuandoNoHayProveedorOperativo() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.of(envio("CORREO")));
        doThrow(new CorreoException("sin proveedor"))
                .when(correoSender).enviar(org.mockito.ArgumentMatchers.any());
        EnvioSuspensionDispatcher dispatcher = new EnvioSuspensionDispatcher(
                repository, correoSender
        );
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        dispatcher.despachar(601L);

        verify(repository).marcarEnvio(601L, "FALLIDO");
    }

    @Test
    void informaSiElEnvioPersistidoNoExiste() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.empty());
        EnvioSuspensionDispatcher dispatcher = new EnvioSuspensionDispatcher(
                repository, correoSender
        );

        assertThrows(IllegalStateException.class, () -> dispatcher.despachar(601L));
    }

    private EnvioNotificacion envio(String canal) {
        return new EnvioNotificacion(
                601L, 701L, canal, "socio@example.com", null,
                "Tu turno fue suspendido",
                LocalDate.of(2026, 10, 21),
                LocalTime.of(9, 0),
                LocalTime.of(9, 20),
                "Cardiología",
                "Socio"
        );
    }
}
