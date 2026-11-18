package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.when;

/**
 * El campo cancelable de GET /api/agendas: verdadero solo si el estado efectivo
 * es AGENDADA y el inicio no cae antes de ahora mas el plazo minimo.
 */
@ExtendWith(MockitoExtension.class)
class AgendaConsultaCancelableTest {

    private static final ZoneId ZONA = ZoneId.of("America/Montevideo");
    // Ahora son las 12:00 del 23/10/2026 en Montevideo (UTC-3).
    private static final Clock MEDIODIA = Clock.fixed(
            Instant.parse("2026-10-23T15:00:00Z"), ZONA);
    // Ahora son las 23:00 del 22/10/2026 en Montevideo.
    private static final Clock NOCHE_ANTERIOR = Clock.fixed(
            Instant.parse("2026-10-23T02:00:00Z"), ZONA);

    private static final LocalDate HOY = LocalDate.of(2026, 10, 23);
    private static final LocalDate MANANA = LocalDate.of(2026, 10, 24);

    @Mock
    private AgendaConsultaRepository repository;

    private AgendaOperativaDTO consulta(
            long id, String estado, LocalDate fecha, String horaInicio) {
        return new AgendaOperativaDTO(
                id,
                new AgendaOperativaDTO.Socio("45678911", "Lucía", "Fernández"),
                new AgendaOperativaDTO.Medico(17L, "Marta", "Rodríguez"),
                new AgendaOperativaDTO.Especialidad(3L, "Cardiología", true),
                fecha,
                horaInicio,
                "23:59",
                new AgendaOperativaDTO.Consultorio(5L, "Consultorio 5", "Piso 2"),
                estado,
                null,
                false
        );
    }

    private List<Boolean> cancelables(
            Clock reloj, ParametroService parametros, AgendaOperativaDTO... filas) {
        when(repository.listar(any(), any())).thenReturn(
                new AgendaOperativaPageResponse(List.of(filas), 0, 20, filas.length));
        var servicio = new AgendaConsultaService(repository, reloj, parametros);
        return servicio.consultar(null, null, null, null, null, null,
                        null, null, null, null)
                .items().stream().map(AgendaOperativaDTO::cancelable).toList();
    }

    @Test
    void conElPlazoDeDosHorasSoloLasQueEmpiezanEnDosHorasOMasSonCancelables() {
        var resultado = cancelables(MEDIODIA, ParametroService.porDefecto(),
                consulta(1, "AGENDADA", HOY, "11:00"),
                consulta(2, "AGENDADA", HOY, "13:00"),
                consulta(3, "AGENDADA", HOY, "13:59"),
                consulta(4, "AGENDADA", HOY, "14:00"),
                consulta(5, "AGENDADA", HOY, "14:01"),
                consulta(6, "AGENDADA", HOY, "15:00"));

        // 11:00 ya empezo; 13:00 faltan 1 h; 13:59 faltan 1 h 59; 14:00 faltan
        // exactamente 2 h (el limite es cancelable); 14:01 y 15:00 pasan.
        assertEquals(List.of(false, false, false, true, true, true), resultado);
    }

    @Test
    void unaConsultaQueNoEstaAgendadaNuncaEsCancelable() {
        var resultado = cancelables(MEDIODIA, ParametroService.porDefecto(),
                consulta(1, "AGENDADA", MANANA, "10:00"),
                consulta(2, "CANCELADA_SOCIO", MANANA, "10:00"),
                consulta(3, "CANCELADA_INSTITUCION", MANANA, "10:00"),
                consulta(4, "ATENDIDA", MANANA, "10:00"),
                consulta(5, "NO_SE_PRESENTO", MANANA, "10:00"),
                consulta(6, "NO_ATENDIDA", MANANA, "10:00"),
                consulta(7, "NO_ASISTIO", MANANA, "10:00"));

        assertEquals(List.of(true, false, false, false, false, false, false),
                resultado);
    }

    @Test
    void conElPlazoEnCuatroHorasUsaElParametroConfigurado() {
        var cuatroHoras = ParametrosDePrueba.nuevo().cancelarHoras(4).construir();

        var resultado = cancelables(MEDIODIA, cuatroHoras,
                consulta(1, "AGENDADA", HOY, "15:00"),
                consulta(2, "AGENDADA", HOY, "15:59"),
                consulta(3, "AGENDADA", HOY, "16:00"),
                consulta(4, "AGENDADA", HOY, "17:00"));

        // A 3 h y a 3 h 59 no alcanza; a 4 h exactas y a 5 h si.
        assertEquals(List.of(false, false, true, true), resultado);
    }

    @Test
    void calculaElPlazoAtravesDeLaMedianocheEnHoraDeMontevideo() {
        var resultado = cancelables(NOCHE_ANTERIOR, ParametroService.porDefecto(),
                consulta(1, "AGENDADA", HOY, "08:00"),
                consulta(2, "AGENDADA", HOY, "00:30"),
                consulta(3, "AGENDADA", HOY, "01:00"),
                consulta(4, "AGENDADA", LocalDate.of(2026, 10, 22), "23:30"),
                consulta(5, "AGENDADA", MANANA, "08:00"));

        // Son las 23:00 del 22/10: las 08:00 del 23/10 faltan 9 h; las 00:30
        // faltan 1 h 30; las 01:00 faltan exactamente 2 h; las 23:30 del 22/10
        // faltan 30 minutos; las 08:00 del 24/10 faltan 33 h.
        assertEquals(List.of(true, false, true, false, true), resultado);
    }

    @Test
    void conservaLaPaginaYElRestoDeLosDatosDeCadaConsulta() {
        var original = consulta(9001, "AGENDADA", HOY, "14:00");
        when(repository.listar(any(), any())).thenReturn(
                new AgendaOperativaPageResponse(List.of(original), 3, 5, 17));
        var servicio = new AgendaConsultaService(
                repository, MEDIODIA, ParametroService.porDefecto());

        var respuesta = servicio.consultar(null, null, null, null, null, null,
                null, null, null, null);

        assertEquals(3, respuesta.page());
        assertEquals(5, respuesta.size());
        assertEquals(17, respuesta.total());
        assertEquals(List.of(original.conCancelable(true)), respuesta.items());
    }
}
