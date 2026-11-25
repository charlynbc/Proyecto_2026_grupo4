package uy.edu.proyecto.backend.notificacion;

import static org.junit.jupiter.api.Assertions.assertEquals;

import com.google.firebase.messaging.AndroidConfig;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.CsvSource;

/** Canal, prioridad y TTL del aviso push en Android, con los valores escritos a mano. */
class PoliticaAndroidAvisoTest {

    @Test
    void elCanalEsAvisosConsultas() {
        assertEquals("avisos_consultas", PoliticaAndroidAviso.CANAL_AVISOS);
    }

    @Test
    void elRecordatorioUsaCanalPrioridadAltaYDosHoras() {
        PoliticaAndroidAviso politica = PoliticaAndroidAviso.de("RECORDATORIO");

        assertEquals("avisos_consultas", politica.canal());
        assertEquals(AndroidConfig.Priority.HIGH, politica.prioridad());
        assertEquals(7_200_000L, politica.ttlMilisegundos());
    }

    @ParameterizedTest
    @CsvSource({
            "AGENDA",
            "CANCELACION",
            "SUSPENSION",
            "HISTORIA_ACTUALIZADA"
    })
    void losDemasTiposUsanCanalPrioridadAltaYSieteDias(String tipo) {
        PoliticaAndroidAviso politica = PoliticaAndroidAviso.de(tipo);

        assertEquals("avisos_consultas", politica.canal());
        assertEquals(AndroidConfig.Priority.HIGH, politica.prioridad());
        assertEquals(604_800_000L, politica.ttlMilisegundos());
    }

    @Test
    void unTipoDesconocidoUsaCanalPrioridadAltaYSieteDias() {
        PoliticaAndroidAviso politica = PoliticaAndroidAviso.de("OTRO_TIPO");

        assertEquals("avisos_consultas", politica.canal());
        assertEquals(AndroidConfig.Priority.HIGH, politica.prioridad());
        assertEquals(604_800_000L, politica.ttlMilisegundos());
    }

    @Test
    void unTipoNuloUsaCanalPrioridadAltaYSieteDias() {
        PoliticaAndroidAviso politica = PoliticaAndroidAviso.de(null);

        assertEquals("avisos_consultas", politica.canal());
        assertEquals(AndroidConfig.Priority.HIGH, politica.prioridad());
        assertEquals(604_800_000L, politica.ttlMilisegundos());
    }

    @Test
    void elTipoEnMinusculasNoEsElRecordatorio() {
        assertEquals(604_800_000L, PoliticaAndroidAviso.de("recordatorio").ttlMilisegundos());
    }
}
