package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;

import org.junit.jupiter.api.Test;
import org.springframework.test.context.TestPropertySource;

/** Con la antelacion configurada en 1 hora la ventana del recordatorio cambia. */
@TestPropertySource(properties = "app.parametros.recordatorio-antelacion-horas=1")
class RecordatorioAntelacion1IT extends RecordatorioITBase {

    @Test
    void unaConsultaQueEmpiezaEn1HoraYSeAgendoHaceUnDiaGeneraElRecordatorio() {
        reloj.fijar(diaDelTurno().atTime(9, 0));
        consultaAgendadaEn(diaDelTurno().minusDays(1).atTime(9, 0));

        proceso.generarRecordatorios();

        assertEquals(1, recordatorios());
    }

    @Test
    void unaConsultaQueEmpiezaEn2HorasTodaviaNoGeneraRecordatorio() {
        reloj.fijar(diaDelTurno().atTime(8, 0));
        consultaAgendadaEn(diaDelTurno().minusDays(1).atTime(8, 0));

        proceso.generarRecordatorios();

        assertEquals(0, recordatorios());
    }
}
