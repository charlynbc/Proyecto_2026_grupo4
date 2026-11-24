package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.context.ApplicationEventPublisher;

import uy.edu.proyecto.backend.agenda.CancelacionFuncionarioRepository.DatosConsulta;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.TurnoFecha;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * La anticipacion minima para cancelar sale del parametro (RNF-26) en los tres
 * servicios de cancelacion. Los relojes fijan "ahora" a las 09:00 locales (el
 * del socio a las 07:00); una consulta a 3 horas no se puede cancelar con 4
 * horas de anticipacion y una a 5 horas si.
 */
class CancelacionAnticipacionParametrizadaTest {

    private static final ZoneId MONTEVIDEO = ZoneId.of("America/Montevideo");
    // 2026-10-30 09:00 en Montevideo.
    private static final Clock RELOJ_09 =
            Clock.fixed(Instant.parse("2026-10-30T12:00:00Z"), MONTEVIDEO);
    // 2026-11-03 07:00 en Montevideo.
    private static final Clock RELOJ_07 =
            Clock.fixed(Instant.parse("2026-11-03T10:00:00Z"), MONTEVIDEO);
    private static final LocalDate HOY = LocalDate.of(2026, 10, 30);
    private static final LocalDate HOY_SOCIO = LocalDate.of(2026, 11, 3);
    private static final OffsetDateTime CANCELADA =
            OffsetDateTime.parse("2026-10-30T09:01:00-03:00");

    private static ParametroService cancelarCon(int horas) {
        return ParametrosDePrueba.nuevo().cancelarHoras(horas).construir();
    }

    /* ---------- CancelacionService (el socio, reloj 07:00) ---------- */

    private CancelacionService servicioDelSocio(ParametroService parametros, LocalTime hora) {
        ConsultaRepository repository = mock(ConsultaRepository.class);
        when(repository.bloquearSocioHabilitado(91L)).thenReturn(true);
        when(repository.bloquearConsultaDelSocio(91L, 9001L)).thenReturn(Optional.of(
                new ConsultaRepository.ConsultaParaCancelar("AGENDADA", HOY_SOCIO, hora, null)));
        when(repository.existeAvisoLlegada(91L, HOY_SOCIO)).thenReturn(false);
        when(repository.cancelarPorSocio(9001L, 91L)).thenReturn(Optional.of(CANCELADA));
        return new CancelacionService(repository, RELOJ_07, parametros);
    }

    @Test
    void elSocioConCuatroHorasNoCancelaUnaConsultaEnTresHoras() {
        ApiException error = assertThrows(ApiException.class,
                () -> servicioDelSocio(cancelarCon(4), LocalTime.of(10, 0))
                        .cancelarPorSocio(91L, "9001"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        assertEquals("Faltan menos de 4 horas para la hora del número", error.getMessage());
    }

    @Test
    void elSocioConCuatroHorasCancelaUnaConsultaEnCincoHoras() {
        CancelacionDTO dto = servicioDelSocio(cancelarCon(4), LocalTime.of(12, 0))
                .cancelarPorSocio(91L, "9001");

        assertEquals("CANCELADA_SOCIO", dto.estado());
    }

    @Test
    void elSocioConCuatroHorasTieneElLimiteExactoALas11() {
        assertEquals("CANCELADA_SOCIO", servicioDelSocio(cancelarCon(4), LocalTime.of(11, 0))
                .cancelarPorSocio(91L, "9001").estado());
        ApiException error = assertThrows(ApiException.class,
                () -> servicioDelSocio(cancelarCon(4), LocalTime.of(10, 59))
                        .cancelarPorSocio(91L, "9001"));
        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
    }

    @Test
    void elMensajeDelSocioConElValorPorDefectoDiceDosHoras() {
        ApiException error = assertThrows(ApiException.class,
                () -> servicioDelSocio(ParametroService.porDefecto(), LocalTime.of(8, 59))
                        .cancelarPorSocio(91L, "9001"));

        assertEquals("Faltan menos de 2 horas para la hora del número", error.getMessage());
    }

    @Test
    void elMensajeDelSocioConUnaHoraVaEnSingular() {
        ApiException error = assertThrows(ApiException.class,
                () -> servicioDelSocio(cancelarCon(1), LocalTime.of(7, 59))
                        .cancelarPorSocio(91L, "9001"));

        assertEquals("Faltan menos de 1 hora para la hora del número", error.getMessage());
    }

    /* ---------- CancelacionMedicoService (reloj 09:00) ---------- */

    private CancelacionMedicoService servicioDelMedico(
            ParametroService parametros, CancelacionMedicoRepository repository,
            ConsultaRepository consultaRepository, TurnoFechasRepository turnoFechas) {
        when(repository.ciMedico(5L)).thenReturn(Optional.of("10000044"));
        return new CancelacionMedicoService(repository, consultaRepository, turnoFechas,
                mock(ApplicationEventPublisher.class), RELOJ_09, parametros);
    }

    private CancelacionMedicoService medicoConConsultaIndividual(
            ParametroService parametros, LocalTime hora) {
        CancelacionMedicoRepository repository = mock(CancelacionMedicoRepository.class);
        ConsultaRepository consultaRepository = mock(ConsultaRepository.class);
        TurnoFechasRepository turnoFechas = mock(TurnoFechasRepository.class);
        when(repository.buscarSocioEnConsultaDelMedico(12L, 5L)).thenReturn(Optional.of(7L));
        when(consultaRepository.bloquearSocioHabilitado(7L)).thenReturn(true);
        when(repository.bloquearConsultaDelMedico(12L, 7L, 5L)).thenReturn(Optional.of(
                new CancelacionMedicoRepository.DatosConsulta(7L, "20000012",
                        "socio@example.com", "AGENDADA", HOY, hora, LocalDate.of(2026, 12, 15),
                        "Cardiología", "Marta Rodríguez")));
        when(repository.cancelarConsulta(12L, 5L, "Imprevisto"))
                .thenReturn(Optional.of(CANCELADA));
        when(repository.crearNotificacionCancelacion(eq(12L), anyString())).thenReturn(90L);
        when(turnoFechas.registrarEnviosNotificacion(90L, 7L, "socio@example.com"))
                .thenReturn(List.of(91L));
        return servicioDelMedico(parametros, repository, consultaRepository, turnoFechas);
    }

    @Test
    void elMedicoConCuatroHorasNoCancelaUnaConsultaEnTresHoras() {
        ApiException error = assertThrows(ApiException.class,
                () -> medicoConConsultaIndividual(cancelarCon(4), LocalTime.of(12, 0))
                        .cancelarConsulta(5L, "12", "Imprevisto"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        assertEquals("Faltan menos de 4 horas para la hora del número", error.getMessage());
    }

    @Test
    void elMedicoConCuatroHorasCancelaUnaConsultaEnCincoHoras() {
        CancelacionDTO dto = medicoConConsultaIndividual(cancelarCon(4), LocalTime.of(14, 0))
                .cancelarConsulta(5L, "12", "Imprevisto");

        assertEquals("CANCELADA_INSTITUCION", dto.estado());
    }

    @Test
    void elMensajeDelMedicoConElValorPorDefectoDiceDosHoras() {
        ApiException error = assertThrows(ApiException.class,
                () -> medicoConConsultaIndividual(ParametroService.porDefecto(), LocalTime.of(10, 30))
                        .cancelarConsulta(5L, "12", "Imprevisto"));

        assertEquals("Faltan menos de 2 horas para la hora del número", error.getMessage());
    }

    @Test
    void elMensajeDelMedicoConUnaHoraVaEnSingular() {
        ApiException error = assertThrows(ApiException.class,
                () -> medicoConConsultaIndividual(cancelarCon(1), LocalTime.of(9, 59))
                        .cancelarConsulta(5L, "12", "Imprevisto"));

        assertEquals("Faltan menos de 1 hora para la hora del número", error.getMessage());
    }

    private CancelacionMedicoService medicoConTurno(
            ParametroService parametros, LocalTime primera, LocalTime segunda) {
        CancelacionMedicoRepository repository = mock(CancelacionMedicoRepository.class);
        ConsultaRepository consultaRepository = mock(ConsultaRepository.class);
        TurnoFechasRepository turnoFechas = mock(TurnoFechasRepository.class);
        List<TurnoFechasRepository.ConsultaParaCancelar> consultas = List.of(
                consultaDeTurno(1L, 7L, primera),
                consultaDeTurno(2L, 8L, segunda));
        when(turnoFechas.bloquearTurnos(List.of(30L))).thenReturn(List.of(30L));
        when(turnoFechas.buscarTurnos(List.of(30L))).thenReturn(List.of(
                new TurnoFecha(30L, 3L, HOY, "ACTIVO", 5L, 9L, 4L, "10:00", "11:00", 2)));
        when(turnoFechas.bloquearConsultasAgendadas(List.of(30L))).thenReturn(consultas);
        when(repository.resumenCancelables(List.of(1L, 2L))).thenReturn(List.of(
                new CancelacionMedicoRepository.ResumenCancelable(1L, "20000012", null),
                new CancelacionMedicoRepository.ResumenCancelable(2L, "20000021", null)));
        when(turnoFechas.crearEvento(30L, 5L, "SUSPENSION", "Imprevisto")).thenReturn(60L);
        when(turnoFechas.cancelarConsulta(anyLong(), eq(5L), any(), eq("Imprevisto"), eq(60L)))
                .thenReturn(1);
        when(turnoFechas.crearNotificacionSuspension(anyLong(), anyString())).thenReturn(90L, 91L);
        when(turnoFechas.registrarEnviosNotificacion(anyLong(), anyLong(), anyString()))
                .thenReturn(List.of(95L));
        return servicioDelMedico(parametros, repository, consultaRepository, turnoFechas);
    }

    private static TurnoFechasRepository.ConsultaParaCancelar consultaDeTurno(
            long id, long socioId, LocalTime inicio) {
        return new TurnoFechasRepository.ConsultaParaCancelar(
                id, socioId, 100L + id, 30L, HOY, inicio, inicio.plusMinutes(20), (int) id,
                "socio" + id + "@example.com", "Cardiología", "Marta Rodríguez");
    }

    @Test
    void elMedicoConCuatroHorasNoSuspendeUnTurnoConUnaConsultaEnTresHoras() {
        ApiException error = assertThrows(ApiException.class,
                () -> medicoConTurno(cancelarCon(4), LocalTime.of(14, 0), LocalTime.of(12, 0))
                        .cancelarTurno(5L, "30", "Imprevisto"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        assertEquals("Faltan menos de 4 horas para la hora del número", error.getMessage());
    }

    @Test
    void elMedicoConCuatroHorasSuspendeUnTurnoSiTodasEmpiezanEnCincoHorasOMas() {
        CancelacionTurnoMedicoDTO dto = medicoConTurno(
                cancelarCon(4), LocalTime.of(14, 0), LocalTime.of(14, 20))
                .cancelarTurno(5L, "30", "Imprevisto");

        assertEquals("SUSPENDIDO", dto.estado());
        assertEquals(2, dto.consultasCanceladas());
    }

    /* ---------- CancelacionFuncionarioService (reloj 09:00) ---------- */

    private CancelacionFuncionarioService funcionarioConConsulta(
            ParametroService parametros, LocalTime hora) {
        CancelacionFuncionarioRepository repository = mock(CancelacionFuncionarioRepository.class);
        ConsultaRepository consultaRepository = mock(ConsultaRepository.class);
        TurnoFechasRepository notificaciones = mock(TurnoFechasRepository.class);
        when(repository.ciFuncionario(5L)).thenReturn(Optional.of("87654321"));
        when(repository.buscarSocio(12L)).thenReturn(Optional.of(7L));
        when(consultaRepository.bloquearSocioHabilitado(7L)).thenReturn(true);
        when(repository.bloquearConsulta(12L, 7L)).thenReturn(Optional.of(new DatosConsulta(
                7L, "12345678", "socio@example.com", "AGENDADA", HOY, hora,
                LocalDate.of(2026, 12, 15), "Cardiología", "Marta Rodríguez")));
        when(repository.cancelar(12L, 5L)).thenReturn(Optional.of(CANCELADA));
        when(repository.crearNotificacion(eq(12L), anyString())).thenReturn(90L);
        when(notificaciones.registrarEnviosNotificacion(90L, 7L, "socio@example.com"))
                .thenReturn(List.of(91L));
        return new CancelacionFuncionarioService(repository, consultaRepository,
                notificaciones, mock(ApplicationEventPublisher.class), RELOJ_09, parametros);
    }

    @Test
    void elFuncionarioConCuatroHorasNoCancelaUnaConsultaEnTresHoras() {
        ApiException error = assertThrows(ApiException.class,
                () -> funcionarioConConsulta(cancelarCon(4), LocalTime.of(12, 0))
                        .cancelar(5L, "12"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
        assertEquals("Faltan menos de 4 horas para la consulta", error.getMessage());
    }

    @Test
    void elFuncionarioConCuatroHorasCancelaUnaConsultaEnCincoHoras() {
        CancelacionDTO dto = funcionarioConConsulta(cancelarCon(4), LocalTime.of(14, 0))
                .cancelar(5L, "12");

        assertEquals("CANCELADA_SOCIO", dto.estado());
    }

    @Test
    void elFuncionarioConCuatroHorasCancelaUnaConsultaQueEmpiezaExactamenteALas13() {
        CancelacionDTO dto = funcionarioConConsulta(cancelarCon(4), LocalTime.of(13, 0))
                .cancelar(5L, "12");

        assertEquals("CANCELADA_SOCIO", dto.estado());
    }

    @Test
    void elFuncionarioConCuatroHorasNoCancelaUnaConsultaQueEmpiezaALas1259() {
        ApiException error = assertThrows(ApiException.class,
                () -> funcionarioConConsulta(cancelarCon(4), LocalTime.of(12, 59))
                        .cancelar(5L, "12"));

        assertEquals("CANCELACION_FUERA_DE_PLAZO", error.getCode());
    }

    @Test
    void elMensajeDelFuncionarioConElValorPorDefectoDiceDosHoras() {
        ApiException error = assertThrows(ApiException.class,
                () -> funcionarioConConsulta(ParametroService.porDefecto(), LocalTime.of(10, 0))
                        .cancelar(5L, "12"));

        assertEquals("Faltan menos de 2 horas para la consulta", error.getMessage());
    }

    @Test
    void elMensajeDelFuncionarioConUnaHoraVaEnSingular() {
        ApiException error = assertThrows(ApiException.class,
                () -> funcionarioConConsulta(cancelarCon(1), LocalTime.of(9, 59))
                        .cancelar(5L, "12"));

        assertEquals("Faltan menos de 1 hora para la consulta", error.getMessage());
    }
}
