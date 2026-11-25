package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.ZonedDateTime;
import java.util.Optional;
import java.util.Set;
import java.util.stream.Stream;

import org.junit.jupiter.params.ParameterizedTest;
import org.junit.jupiter.params.provider.Arguments;
import org.junit.jupiter.params.provider.MethodSource;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * El campo cancelable del socio tiene que dar false exactamente cuando la
 * cancelacion del socio responde 409 por CONSULTA_NO_AGENDADA,
 * LLEGADA_YA_REGISTRADA o CANCELACION_FUERA_DE_PLAZO, y true cuando la
 * cancelacion se hace. Cada escenario trae el resultado esperado escrito a
 * mano, para que la comparacion no sea circular.
 *
 * No se compara sin base de datos: el 404 por socio no habilitado o consulta
 * ajena (no es un dato de la consulta que se lista) y la carrera del UPDATE
 * condicionado, que responde 409 CONSULTA_NO_AGENDADA solo si otra operacion
 * cambia la consulta entre la lectura y la escritura.
 */
class EquivalenciaCancelableSocioTest {

    private static final ZoneId MONTEVIDEO = ZoneId.of("America/Montevideo");
    // 2026-11-03 07:00 en Montevideo.
    private static final Clock RELOJ = Clock.fixed(Instant.parse("2026-11-03T10:00:00Z"), MONTEVIDEO);
    private static final LocalDate HOY = LocalDate.of(2026, 11, 3);
    private static final OffsetDateTime CANCELADA = OffsetDateTime.parse("2026-11-03T07:00:00-03:00");
    private static final Set<String> CODIGOS_DE_CANCELABLE = Set.of(
            "CONSULTA_NO_AGENDADA", "LLEGADA_YA_REGISTRADA", "CANCELACION_FUERA_DE_PLAZO");

    static Stream<Arguments> escenarios() {
        return Stream.of(
                // nombre, estado, hora de inicio, aviso de llegada hoy, horas minimas, cancelable esperado
                Arguments.of("agendada lejana sin llegada", "AGENDADA", "15:00", false, 2, true),
                Arguments.of("agendada lejana con llegada", "AGENDADA", "15:00", true, 2, false),
                Arguments.of("borde exacto de 2 horas", "AGENDADA", "09:00", false, 2, true),
                Arguments.of("un minuto antes del borde", "AGENDADA", "08:59", false, 2, false),
                Arguments.of("ya iniciada", "AGENDADA", "06:00", false, 2, false),
                Arguments.of("con llegada y fuera de plazo", "AGENDADA", "08:00", true, 2, false),
                Arguments.of("con llegada en el borde", "AGENDADA", "09:00", true, 2, false),
                Arguments.of("atendida", "ATENDIDA", "15:00", false, 2, false),
                Arguments.of("cancelada por el socio", "CANCELADA_SOCIO", "15:00", false, 2, false),
                Arguments.of("cancelada por la institucion", "CANCELADA_INSTITUCION", "15:00", false, 2, false),
                Arguments.of("no se presento", "NO_SE_PRESENTO", "15:00", false, 2, false),
                Arguments.of("no asistio (estado que se presenta)", "NO_ASISTIO", "15:00", false, 2, false),
                Arguments.of("no atendida (estado que se presenta)", "NO_ATENDIDA", "15:00", true, 2, false),
                Arguments.of("con 5 horas, en el borde de las 12:00", "AGENDADA", "12:00", false, 5, true),
                Arguments.of("con 5 horas, un minuto antes", "AGENDADA", "11:59", false, 5, false),
                Arguments.of("con 5 horas, lejana", "AGENDADA", "15:00", false, 5, true)
        );
    }

    @ParameterizedTest(name = "{0}")
    @MethodSource("escenarios")
    void cancelableCoincideConLaCancelacionDelSocio(
            String nombre, String estado, String hora, boolean llegada, int horas, boolean esperado) {
        ParametroService parametros = ParametrosDePrueba.nuevo().cancelarHoras(horas).construir();
        ConsultaRepository repository = mock(ConsultaRepository.class);
        when(repository.bloquearSocioHabilitado(91L)).thenReturn(true);
        when(repository.bloquearConsultaDelSocio(91L, 9001L)).thenReturn(Optional.of(
                new ConsultaRepository.ConsultaParaCancelar(estado, HOY, LocalTime.parse(hora), null)));
        when(repository.existeAvisoLlegada(91L, HOY)).thenReturn(llegada);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.of(CANCELADA));
        CancelacionService cancelacion = new CancelacionService(repository, RELOJ, parametros);

        boolean seCancela;
        try {
            cancelacion.cancelarPorSocio(91L, "9001");
            seCancela = true;
        } catch (ApiException conflicto) {
            assertTrue(CODIGOS_DE_CANCELABLE.contains(conflicto.getCode()),
                    "codigo inesperado en " + nombre + ": " + conflicto.getCode());
            seCancela = false;
        }

        boolean cancelable = ReglaCancelableSocio.evaluar(
                estado, HOY, hora, MONTEVIDEO, ZonedDateTime.now(RELOJ), horas, llegada);

        assertEquals(esperado, cancelable, "valor escrito a mano en " + nombre);
        assertEquals(seCancela, cancelable, "cancelable debe coincidir con la cancelacion en " + nombre);
    }
}
