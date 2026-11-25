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
    void elCuerpoDeCancelacionASolicitudDelSocioDiceEspecialidadMedicoFechaYHora() {
        assertEquals(
                "Tu consulta de Cardiología con Marta Rodríguez del 20/10/2026 "
                        + "a las 09:00 fue cancelada a tu solicitud.",
                NotificacionTextos.cuerpoCancelacionASolicitudDelSocio(
                        "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 10, 20),
                        LocalTime.of(9, 0))
        );
    }

    @Test
    void laCancelacionASolicitudDelSocioUsaFechaDiaMesAnioYHoraDe24Horas() {
        assertEquals(
                "Tu consulta de Pediatría con Jorge Pereira del 05/01/2027 "
                        + "a las 14:05 fue cancelada a tu solicitud.",
                NotificacionTextos.cuerpoCancelacionASolicitudDelSocio(
                        "Pediatría", "Jorge Pereira", LocalDate.of(2027, 1, 5),
                        LocalTime.of(14, 5, 30))
        );
    }

    @Test
    void elCuerpoDeCancelacionPorLaInstitucionDiceEspecialidadMedicoFechaHoraYMotivo() {
        assertEquals(
                "Tu consulta de Cardiología con Marta Rodríguez del 20/10/2026 "
                        + "a las 09:00 fue cancelada por la institución. "
                        + "Motivo: Imprevisto",
                NotificacionTextos.cuerpoCancelacionPorInstitucion(
                        "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 10, 20),
                        LocalTime.of(9, 0), "Imprevisto")
        );
    }

    @Test
    void laCancelacionPorLaInstitucionCompletaConCeroElDiaElMesYLaHora() {
        assertEquals(
                "Tu consulta de Pediatría con Jorge Pereira del 05/01/2026 "
                        + "a las 08:05 fue cancelada por la institución. Motivo: Feriado",
                NotificacionTextos.cuerpoCancelacionPorInstitucion(
                        "Pediatría", "Jorge Pereira", LocalDate.of(2026, 1, 5),
                        LocalTime.of(8, 5), "Feriado")
        );
    }

    @Test
    void laCancelacionPorLaInstitucionCopiaElMotivoTalCual() {
        assertEquals(
                "Tu consulta de Cardiología con Marta Rodríguez del 31/12/2026 "
                        + "a las 10:30 fue cancelada por la institución. "
                        + "Motivo: Corte de luz: se reprograma (ver 5/1).",
                NotificacionTextos.cuerpoCancelacionPorInstitucion(
                        "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 12, 31),
                        LocalTime.of(10, 30), "Corte de luz: se reprograma (ver 5/1).")
        );
    }

    @Test
    void laCancelacionPorLaInstitucionSinMotivoNoLlevaLaOracionDelMotivo() {
        String esperado = "Tu consulta de Cardiología con Marta Rodríguez del 20/10/2026 "
                + "a las 09:00 fue cancelada por la institución.";

        assertEquals(esperado, NotificacionTextos.cuerpoCancelacionPorInstitucion(
                "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 10, 20),
                LocalTime.of(9, 0), null));
        assertEquals(esperado, NotificacionTextos.cuerpoCancelacionPorInstitucion(
                "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 10, 20),
                LocalTime.of(9, 0), "   "));
    }

    @Test
    void elCuerpoDeSuspensionDiceEspecialidadMedicoFechaHorarioNumeroYMotivo() {
        assertEquals(
                "Tu consulta de Cardiología con Marta Rodríguez del 20/10/2026 "
                        + "fue cancelada por la institución. "
                        + "Horario: 09:00 a 09:20 (número 3). Motivo: Imprevisto",
                NotificacionTextos.cuerpoSuspension(
                        "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 10, 20),
                        LocalTime.of(9, 0), LocalTime.of(9, 20), 3, "Imprevisto")
        );
    }

    @Test
    void laSuspensionAnteponeLaPalabraMotivoALaObservacionDelFuncionario() {
        assertEquals(
                "Tu consulta de Pediatría con Jorge Pereira del 05/01/2027 "
                        + "fue cancelada por la institución. "
                        + "Horario: 08:05 a 08:25 (número 1). Motivo: Aviso a los socios",
                NotificacionTextos.cuerpoSuspension(
                        "Pediatría", "Jorge Pereira", LocalDate.of(2027, 1, 5),
                        LocalTime.of(8, 5), LocalTime.of(8, 25), 1, "Aviso a los socios")
        );
    }

    @Test
    void laSuspensionSinMotivoTerminaEnElNumero() {
        String esperado = "Tu consulta de Cardiología con Marta Rodríguez del 20/10/2026 "
                + "fue cancelada por la institución. Horario: 09:00 a 09:20 (número 3).";

        assertEquals(esperado, NotificacionTextos.cuerpoSuspension(
                "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 10, 20),
                LocalTime.of(9, 0), LocalTime.of(9, 20), 3, null));
        assertEquals(esperado, NotificacionTextos.cuerpoSuspension(
                "Cardiología", "Marta Rodríguez", LocalDate.of(2026, 10, 20),
                LocalTime.of(9, 0), LocalTime.of(9, 20), 3, ""));
    }

    @Test
    void elCuerpoDelRecordatorioLlevaLosCincoDatosYLaUbicacionEntreParentesis() {
        assertEquals(
                "Recordatorio de consulta: Cardiología con Marta Rodríguez, "
                        + "el 03/11/2026 a las 09:05, en Consultorio 3 (Piso 2)",
                NotificacionTextos.cuerpoRecordatorio(
                        "Cardiología", "Marta", "Rodríguez", LocalDate.of(2026, 11, 3),
                        LocalTime.of(9, 5), "Consultorio 3", "Piso 2")
        );
    }

    @Test
    void elRecordatorioSinUbicacionNoDejaParentesisVacios() {
        String esperado = "Recordatorio de consulta: Pediatría con Ana Pérez, "
                + "el 15/01/2027 a las 18:30, en Consultorio 1";

        assertEquals(esperado, NotificacionTextos.cuerpoRecordatorio(
                "Pediatría", "Ana", "Pérez", LocalDate.of(2027, 1, 15),
                LocalTime.of(18, 30), "Consultorio 1", null));
        assertEquals(esperado, NotificacionTextos.cuerpoRecordatorio(
                "Pediatría", "Ana", "Pérez", LocalDate.of(2027, 1, 15),
                LocalTime.of(18, 30), "Consultorio 1", "  "));
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
