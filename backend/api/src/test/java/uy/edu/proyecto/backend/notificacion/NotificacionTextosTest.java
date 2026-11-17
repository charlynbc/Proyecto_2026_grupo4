package uy.edu.proyecto.backend.notificacion;

import java.time.LocalDate;
import java.time.LocalTime;

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
                        "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 11, 3),
                        LocalTime.of(9, 0))
        );
    }

    @Test
    void laHoraDelCuerpoDeAgendaVaDe24HorasSinSegundos() {
        assertEquals(
                "Tu consulta de Pediatría con Jorge Pereira quedó agendada "
                        + "para el 05/01/2027 a las 14:05.",
                NotificacionTextos.cuerpoAgenda(
                        "Pediatría", "Jorge Pereira", LocalDate.of(2027, 1, 5),
                        LocalTime.of(14, 5, 30))
        );
    }

    @Test
    void laFechaVaComoDiaMesAnio() {
        assertEquals("20/10/2026", NotificacionTextos.fecha(LocalDate.of(2026, 10, 20)));
        assertEquals("05/01/2027", NotificacionTextos.fecha(LocalDate.of(2027, 1, 5)));
    }

    @Test
    void laHoraVaDe24HorasConMinutosYSinSegundos() {
        assertEquals("09:05", NotificacionTextos.hora(LocalTime.of(9, 5)));
        assertEquals("14:30", NotificacionTextos.hora(LocalTime.of(14, 30)));
        assertEquals("00:00", NotificacionTextos.hora(LocalTime.MIDNIGHT));
        assertEquals("09:00", NotificacionTextos.hora(LocalTime.of(9, 0, 30)));
    }

    @Test
    void elCuerpoDeCancelacionASolicitudDelSocioUsaFechaDiaMesAnio() {
        assertEquals(
                "Tu consulta del 20/10/2026 fue cancelada a tu solicitud.",
                NotificacionTextos.cuerpoCancelacionASolicitudDelSocio(
                        LocalDate.of(2026, 10, 20))
        );
    }

    @Test
    void elCuerpoDeCancelacionDelMedicoUsaFechaDiaMesAnioYElMotivo() {
        assertEquals(
                "Tu consulta del 20/10/2026 fue cancelada por la institución. "
                        + "Motivo: Imprevisto",
                NotificacionTextos.cuerpoCancelacionPorMedico(
                        LocalDate.of(2026, 10, 20), "Imprevisto")
        );
    }

    @Test
    void elCuerpoDeSuspensionPorElMedicoLlevaFechaHorarioNumeroYMotivo() {
        assertEquals(
                "Tu consulta del 20/10/2026 fue cancelada por la institución. "
                        + "Horario: 09:00 a 09:20 (número 3). Motivo: Imprevisto",
                NotificacionTextos.cuerpoSuspensionPorMedico(
                        LocalDate.of(2026, 10, 20),
                        LocalTime.of(9, 0), LocalTime.of(9, 20), 3, "Imprevisto")
        );
    }

    @Test
    void elCuerpoDeSuspensionDelFuncionarioLlevaFechaHorarioNumeroYObservacion() {
        assertEquals(
                "Tu consulta del 20/10/2026 fue cancelada por la institución. "
                        + "Horario: 09:00 a 09:20 (número 3). Aviso a los socios",
                NotificacionTextos.cuerpoSuspensionPorFuncionario(
                        LocalDate.of(2026, 10, 20),
                        LocalTime.of(9, 0), LocalTime.of(9, 20), 3, "Aviso a los socios")
        );
    }

    @Test
    void laSuspensionDelFuncionarioSinObservacionTerminaEnElNumero() {
        assertEquals(
                "Tu consulta del 20/10/2026 fue cancelada por la institución. "
                        + "Horario: 09:00 a 09:20 (número 3).",
                NotificacionTextos.cuerpoSuspensionPorFuncionario(
                        LocalDate.of(2026, 10, 20),
                        LocalTime.of(9, 0), LocalTime.of(9, 20), 3, null)
        );
    }

    @Test
    void laSuspensionDelFuncionarioSinHorarioNoInventaUno() {
        assertEquals(
                "Tu consulta del 20/10/2026 fue cancelada por la institución. Aviso",
                NotificacionTextos.cuerpoSuspensionPorFuncionario(
                        LocalDate.of(2026, 10, 20), null, null, 3, "Aviso")
        );
        assertEquals(
                "Tu consulta del 20/10/2026 fue cancelada por la institución.",
                NotificacionTextos.cuerpoSuspensionPorFuncionario(
                        LocalDate.of(2026, 10, 20), null, null, 3, null)
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
