package uy.edu.proyecto.backend.turno;

import java.time.Clock;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;

// La duracion de un numero y el paso de sus horarios salen de los parametros.
class TurnoSemanalDuracionParametrizadaTest {

    private static final LocalDate INICIO = LocalDate.of(2026, 10, 20);
    private static final LocalDate FIN = LocalDate.of(2026, 10, 27);

    private final TurnoSemanalRepository repository = mock(TurnoSemanalRepository.class);

    private TurnoSemanalService servicio(ParametroService parametros) {
        return new TurnoSemanalService(
                repository,
                mock(TurnoConsultaRepository.class),
                Clock.system(ZoneId.of("America/Montevideo")),
                parametros
        );
    }

    private AltaTurnoSemanalRequest solicitud(String inicio, String fin) {
        return new AltaTurnoSemanalRequest(
                17L, 3L, 5L, 2, INICIO, FIN,
                List.of(new AltaTurnoSemanalRequest.NumeroSemanalRequest(1, inicio, fin))
        );
    }

    private ApiException rechazo(ParametroService parametros, String inicio, String fin) {
        ApiException exception = assertThrows(ApiException.class,
                () -> servicio(parametros).crear(solicitud(inicio, fin), 91L));
        assertEquals("VALIDACION", exception.getCode());
        verify(repository, never()).bloquearMedico(17L);
        return exception;
    }

    // Pasa la validacion cuando llega a buscar al medico (el mock no lo encuentra).
    private void aceptado(ParametroService parametros, String inicio, String fin) {
        ApiException exception = assertThrows(ApiException.class,
                () -> servicio(parametros).crear(solicitud(inicio, fin), 91L));
        assertEquals("NO_ENCONTRADO", exception.getCode());
        verify(repository).bloquearMedico(17L);
    }

    @Test
    void conMinimoDeVeinteRechazaUnNumeroDeQuinceMinutos() {
        ParametroService parametros = ParametrosDePrueba.nuevo().duracion(20, 60, 5).construir();

        ApiException exception = rechazo(parametros, "09:00", "09:15");

        assertEquals("La duración debe estar entre 20 y 60 minutos", exception.getMessage());
    }

    @Test
    void conMinimoDeVeinteAceptaUnNumeroDeVeinteMinutos() {
        aceptado(ParametrosDePrueba.nuevo().duracion(20, 60, 5).construir(), "09:00", "09:20");
    }

    @Test
    void conMaximoDeCuarentaYCincoRechazaUnNumeroDeCincuenta() {
        ParametroService parametros = ParametrosDePrueba.nuevo().duracion(15, 45, 5).construir();

        ApiException exception = rechazo(parametros, "09:00", "09:50");

        assertEquals("La duración debe estar entre 15 y 45 minutos", exception.getMessage());
    }

    @Test
    void conMaximoDeCuarentaYCincoAceptaUnNumeroDeCuarentaYCinco() {
        aceptado(ParametrosDePrueba.nuevo().duracion(15, 45, 5).construir(), "09:00", "09:45");
    }

    @Test
    void conPasoDeQuinceRechazaUnHorarioEnMinutoCinco() {
        ParametroService parametros = ParametrosDePrueba.nuevo().duracion(15, 45, 15).construir();

        ApiException exception = rechazo(parametros, "09:05", "09:30");

        assertEquals("Los horarios deben estar en múltiplos de 15 minutos", exception.getMessage());
    }

    @Test
    void conPasoDeQuinceRechazaUnHorarioDeFinEnMinutoVeinte() {
        rechazo(ParametrosDePrueba.nuevo().duracion(15, 45, 15).construir(), "09:00", "09:20");
    }

    @Test
    void conPasoDeQuinceAceptaHorariosEnMinutoQuince() {
        aceptado(ParametrosDePrueba.nuevo().duracion(15, 45, 15).construir(), "09:15", "09:45");
    }

    @Test
    void conPasoDeDiezAceptaUnHorarioEnMinutoDiezQueConCincoTambienSeria() {
        aceptado(ParametrosDePrueba.nuevo().duracion(10, 60, 10).construir(), "09:10", "09:30");
    }

    @Test
    void conPasoDeDiezRechazaUnHorarioEnMinutoCinco() {
        rechazo(ParametrosDePrueba.nuevo().duracion(10, 60, 10).construir(), "09:05", "09:30");
    }

    @Test
    void elMensajeUsaSingularCuandoElMaximoEsUnMinuto() {
        ParametroService parametros = ParametrosDePrueba.nuevo().duracion(1, 1, 1).construir();

        ApiException exception = rechazo(parametros, "09:00", "09:02");

        assertEquals("La duración debe estar entre 1 y 1 minuto", exception.getMessage());
    }

    @Test
    void conLosValoresPorDefectoSeConservanLosMensajesDeSiempre() {
        ParametroService porDefecto = ParametroService.porDefecto();

        assertEquals("Los horarios deben estar en múltiplos de 5 minutos",
                rechazo(porDefecto, "09:01", "09:20").getMessage());
        assertEquals("La duración debe estar entre 10 y 60 minutos",
                rechazo(porDefecto, "09:00", "09:05").getMessage());
    }
}
