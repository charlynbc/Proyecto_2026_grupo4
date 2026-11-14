package uy.edu.proyecto.backend.notificacion;

import java.time.LocalDate;

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
    void elCuerpoDeAgendaDiceEspecialidadMedicoFechaYHora() {
        assertEquals(
                "Tu consulta de Cardiología con Marta Rodríguez quedó agendada "
                        + "para el 03/11/2026 a las 09:00.",
                NotificacionTextos.cuerpoAgenda(
                        "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 11, 3), "09:00")
        );
    }

    @Test
    void elCuerpoDeHistoriaNoLlevaDatosClinicos() {
        assertEquals(
                "Tu historia clínica fue actualizada.",
                NotificacionTextos.CUERPO_HISTORIA_ACTUALIZADA
        );
    }

    @Test
    void unTipoDesconocidoOAusenteUsaUnTituloGenerico() {
        assertEquals("Aviso de tu consulta", NotificacionTextos.titulo("OTRO"));
        assertEquals("Aviso de tu consulta", NotificacionTextos.titulo(null));
    }
}
