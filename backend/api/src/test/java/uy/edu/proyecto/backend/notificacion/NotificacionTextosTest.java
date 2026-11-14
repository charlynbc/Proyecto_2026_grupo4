package uy.edu.proyecto.backend.notificacion;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

import static org.junit.jupiter.api.Assertions.assertEquals;

class NotificacionTextosTest {

    @ParameterizedTest
    @CsvSource({
            "AGENDA,Consulta agendada",
            "CANCELACION,Consulta cancelada",
            "SUSPENSION,Turno suspendido",
            "HISTORIA_ACTUALIZADA,Historia clínica actualizada",
            "RECORDATORIO,Recordatorio de consulta"
    })
    void cadaTipoTieneSuTitulo(String tipo, String titulo) {
        assertEquals(titulo, NotificacionTextos.titulo(tipo));
    }

    @Test
    void unTipoDesconocidoOAusenteUsaUnTituloGenerico() {
        assertEquals("Aviso de tu consulta", NotificacionTextos.titulo("OTRO"));
        assertEquals("Aviso de tu consulta", NotificacionTextos.titulo(null));
    }
}
