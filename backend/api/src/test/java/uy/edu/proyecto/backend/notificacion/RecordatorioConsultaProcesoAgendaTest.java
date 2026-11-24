package uy.edu.proyecto.backend.notificacion;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.lang.reflect.Method;

import org.junit.jupiter.api.Test;
import org.springframework.scheduling.annotation.Scheduled;

/**
 * Los valores por defecto del agendador del recordatorio: en produccion el
 * barrido arranca de inmediato (retraso inicial 0) y repite cada 60 segundos.
 * Los ITs suben las dos propiedades para que no corra de fondo.
 */
class RecordatorioConsultaProcesoAgendaTest {

    private static Scheduled agenda() throws NoSuchMethodException {
        Method metodo = RecordatorioConsultaProceso.class.getMethod("generarRecordatorios");
        return metodo.getAnnotation(Scheduled.class);
    }

    @Test
    void elRetrasoInicialPorDefectoEsCeroParaQueProduccionNoCambie() throws Exception {
        assertEquals(
                "${app.notificaciones.recordatorios.retraso-inicial-ms:0}",
                agenda().initialDelayString());
    }

    @Test
    void elIntervaloPorDefectoSigueSiendoSesentaMilMilisegundos() throws Exception {
        assertEquals(
                "${app.notificaciones.recordatorios.intervalo-ms:60000}",
                agenda().fixedDelayString());
    }
}
