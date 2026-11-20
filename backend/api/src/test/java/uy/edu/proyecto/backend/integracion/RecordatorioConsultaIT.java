package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

import java.time.LocalDateTime;
import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.correo.CorreoMensaje;

/**
 * Recordatorio de consulta (RNF-25) contra PostgreSQL real, con la antelacion por
 * defecto de 24 horas. El turno sembrado empieza a las 10:00 del dia del turno.
 */
class RecordatorioConsultaIT extends RecordatorioITBase {

    @Test
    void unaConsultaQueEmpiezaEn23HorasYSeAgendoHaceUnDiaGeneraElRecordatorio() {
        reloj.fijar(diaDelTurno().minusDays(1).atTime(11, 0));
        long consulta = consultaAgendadaEn(diaDelTurno().minusDays(2).atTime(11, 0));

        proceso.generarRecordatorios();

        assertEquals(1, recordatorios());
        assertEquals(
                "Recordatorio de consulta: Medicina General con Mario Medina, el "
                        + fechaUruguaya(diaDelTurno()) + " a las 10:00, en Consultorio 1 (Planta baja)",
                jdbc.queryForObject(
                        "SELECT contenido FROM notificacion WHERE id_consulta = ?",
                        String.class, consulta));
        assertEquals(
                diaDelTurno().minusDays(1).atTime(10, 0).atZone(ZONA).toInstant(),
                jdbc.queryForObject(
                        "SELECT programada_para FROM notificacion WHERE id_consulta = ?",
                        OffsetDateTime.class, consulta).toInstant());
        assertEquals(1, contar("envio_notificacion"));
    }

    @Test
    void laMismaConsultaAgendadaHace30MinutosNoGeneraRecordatorio() {
        LocalDateTime ahora = diaDelTurno().minusDays(1).atTime(11, 0);
        reloj.fijar(ahora);
        consultaAgendadaEn(ahora.minusMinutes(30));

        proceso.generarRecordatorios();

        assertEquals(0, recordatorios());
        assertEquals(0, contar("envio_notificacion"));
    }

    @Test
    void unaConsultaQueEmpiezaEn25HorasTodaviaNoGeneraRecordatorio() {
        reloj.fijar(diaDelTurno().minusDays(1).atTime(9, 0));
        consultaAgendadaEn(diaDelTurno().minusDays(3).atTime(9, 0));

        proceso.generarRecordatorios();

        assertEquals(0, recordatorios());
    }

    @Test
    void unaConsultaQueYaEmpezoNoGeneraRecordatorio() {
        reloj.fijar(diaDelTurno().atTime(10, 1));
        consultaAgendadaEn(diaDelTurno().minusDays(3).atTime(9, 0));

        proceso.generarRecordatorios();

        assertEquals(0, recordatorios());
    }

    @Test
    void dosCorridasSeguidasGeneranUnSoloRecordatorioYUnSoloJuegoDeEnvios() {
        reloj.fijar(diaDelTurno().minusDays(1).atTime(11, 0));
        consultaAgendadaEn(diaDelTurno().minusDays(2).atTime(11, 0));

        proceso.generarRecordatorios();
        proceso.generarRecordatorios();

        assertEquals(1, recordatorios());
        assertEquals(1, contar("envio_notificacion"));
    }

    @Test
    void elEnvioDeUnRecordatorioProgramadoParaMasTardeNoSeDespachaHastaSuHora() {
        reloj.fijar(diaDelTurno().minusDays(1).atTime(9, 0));
        long consulta = consultaAgendadaEn(diaDelTurno().minusDays(3).atTime(9, 0));
        long notificacion = jdbc.queryForObject(
                "INSERT INTO notificacion (id_consulta, tipo, contenido, programada_para)"
                        + " VALUES (?, 'RECORDATORIO', 'Recordatorio de consulta: prueba', ?)"
                        + " RETURNING id_notificacion",
                Long.class, consulta,
                diaDelTurno().minusDays(1).atTime(10, 0).atZone(ZONA).toOffsetDateTime());
        jdbc.update("INSERT INTO envio_notificacion (id_notificacion, canal, correo_destino)"
                + " VALUES (?, 'CORREO', ?)", notificacion, "u" + ciSocio1 + "@ejemplo.invalid");

        poller.despacharPendientes();

        verify(correoSender, never()).enviar(any());
        assertEquals("PENDIENTE", jdbc.queryForObject(
                "SELECT estado FROM envio_notificacion WHERE id_notificacion = ?",
                String.class, notificacion));

        reloj.fijar(diaDelTurno().minusDays(1).atTime(10, 0));
        poller.despacharPendientes();

        verify(correoSender).enviar(new CorreoMensaje(
                "u" + ciSocio1 + "@ejemplo.invalid",
                "Recordatorio de consulta",
                "Recordatorio de consulta: prueba"));
        assertEquals("ENVIADO", jdbc.queryForObject(
                "SELECT estado FROM envio_notificacion WHERE id_notificacion = ?",
                String.class, notificacion));
    }
}
