package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.ZoneId;
import java.time.ZonedDateTime;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Regla de cancelable del socio: la consulta se presenta AGENDADA, el socio no
 * registro llegada ese dia y el inicio no cae antes de ahora mas el plazo. Los
 * horarios estan escritos a mano contra un "ahora" fijo de las 07:00.
 */
class ReglaCancelableSocioTest {

    private static final ZoneId ZONA = ZoneId.of("America/Montevideo");
    private static final ZonedDateTime AHORA =
            ZonedDateTime.of(2026, 11, 3, 7, 0, 0, 0, ZONA);
    private static final LocalDate HOY = LocalDate.of(2026, 11, 3);

    private static boolean evaluar(String estado, LocalDate fecha, String hora,
                                   int horasMinimas, boolean llegada) {
        return ReglaCancelableSocio.evaluar(estado, fecha, hora, ZONA, AHORA, horasMinimas, llegada);
    }

    @Test
    void agendadaLejanaSinLlegadaEsCancelable() {
        assertTrue(evaluar("AGENDADA", HOY, "15:00", 2, false));
        assertTrue(evaluar("AGENDADA", HOY.plusDays(1), "08:00", 2, false));
    }

    @Test
    void agendadaLejanaConLlegadaNoEsCancelable() {
        assertFalse(evaluar("AGENDADA", HOY, "15:00", 2, true));
        assertFalse(evaluar("AGENDADA", HOY.plusDays(1), "08:00", 2, true));
    }

    @Test
    void elBordeExactoDeDosHorasEsCancelable() {
        // Ahora 07:00 y el numero empieza 09:00: justo dos horas.
        assertTrue(evaluar("AGENDADA", HOY, "09:00", 2, false));
    }

    @Test
    void unMinutoAntesDelBordeNoEsCancelable() {
        assertFalse(evaluar("AGENDADA", HOY, "08:59", 2, false));
    }

    @Test
    void unaConsultaYaIniciadaOPasadaNoEsCancelable() {
        assertFalse(evaluar("AGENDADA", HOY, "06:00", 2, false));
        assertFalse(evaluar("AGENDADA", HOY.minusDays(1), "15:00", 2, false));
    }

    @Test
    void ningunEstadoDistintoDeAgendadaEsCancelable() {
        for (String estado : new String[] {
                "ATENDIDA", "CANCELADA_SOCIO", "CANCELADA_INSTITUCION",
                "NO_SE_PRESENTO", "NO_ASISTIO", "NO_ATENDIDA"}) {
            assertFalse(evaluar(estado, HOY.plusDays(1), "08:00", 2, false), estado);
        }
    }

    @Test
    void lasHorasMinimasVienenDelParametroYNoDeUnValorFijo() {
        // Con 5 horas el borde es 12:00.
        assertTrue(evaluar("AGENDADA", HOY, "12:00", 5, false));
        assertFalse(evaluar("AGENDADA", HOY, "11:59", 5, false));
        // La misma hora, 11:59, con 2 horas si es cancelable.
        assertTrue(evaluar("AGENDADA", HOY, "11:59", 2, false));
        // Con 1 hora el borde es 08:00.
        assertTrue(evaluar("AGENDADA", HOY, "08:00", 1, false));
        assertFalse(evaluar("AGENDADA", HOY, "07:59", 1, false));
    }

    @Test
    void laLlegadaGanaAunqueElPlazoSeCumpla() {
        assertFalse(evaluar("AGENDADA", HOY, "09:00", 2, true));
    }
}
