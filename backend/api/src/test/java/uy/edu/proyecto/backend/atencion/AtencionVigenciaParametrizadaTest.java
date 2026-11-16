package uy.edu.proyecto.backend.atencion;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.atencion.AtencionRepository.ConsultaResultado;
import uy.edu.proyecto.backend.atencion.ResultadoConsultaRequest.PaseNuevoRequest;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.notificacion.NotificacionEnvios;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

// La vigencia de un pase (inicial, minima y maxima) sale de los parametros.
@ExtendWith(MockitoExtension.class)
class AtencionVigenciaParametrizadaTest {

    private static final Long MEDICO_ID = 17L;
    private static final Long CONSULTA_ID = 9001L;
    private static final Long SOCIO_ID = 91L;
    private static final LocalDate HOY = LocalDate.of(2026, 10, 20);
    private static final OffsetDateTime AHORA =
            OffsetDateTime.parse("2026-10-20T09:41:00-03:00");
    private static final Clock RELOJ = Clock.fixed(
            AHORA.toInstant(), ZoneId.of("America/Montevideo"));
    private static final Especialidad DESTINO = new Especialidad(4L, "Nutrición", true);

    @Mock
    private AtencionRepository repository;

    @Mock
    private NotificacionEnvios envios;

    @BeforeEach
    void setUp() {
        lenient().when(repository.buscarSocioId(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(SOCIO_ID));
        lenient().when(repository.bloquearSocio(SOCIO_ID)).thenReturn(true);
        lenient().when(repository.bloquearConsulta(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(new ConsultaResultado(
                        CONSULTA_ID, SOCIO_ID, "AGENDADA", HOY, "34567894", "23456789")));
        lenient().when(repository.existeAvisoLlegada(SOCIO_ID, HOY)).thenReturn(true);
        lenient().when(repository.buscarEspecialidad(4L)).thenReturn(Optional.of(DESTINO));
        lenient().when(repository.tienePaseVigenteOConsultaAgendada(
                SOCIO_ID, 4L, CONSULTA_ID, HOY)).thenReturn(false);
        lenient().when(repository.crearAtencion(
                CONSULTA_ID, MEDICO_ID, "Control", "Dieta", null, AHORA)).thenReturn(5530L);
        lenient().when(repository.registrarAtendida(CONSULTA_ID, MEDICO_ID, AHORA))
                .thenReturn(true);
    }

    private AtencionService servicio(ParametroService parametros) {
        return new AtencionService(repository, RELOJ, parametros, envios);
    }

    private ResultadoConsultaResponse registrar(ParametroService parametros, Integer vigencia) {
        return servicio(parametros).registrarResultado(
                MEDICO_ID, CONSULTA_ID,
                new ResultadoConsultaRequest("ATENDIDA", "Control", "Dieta", null,
                        List.of(new PaseNuevoRequest(4L, vigencia))));
    }

    private ApiException rechazo(ParametroService parametros, Integer vigencia) {
        ApiException exception = assertThrows(ApiException.class,
                () -> registrar(parametros, vigencia));
        assertEquals("VALIDACION", exception.getCode());
        verify(repository, never()).crearPase(any(), any(), any(), any());
        return exception;
    }

    private void aceptada(ParametroService parametros, int vigencia) {
        when(repository.crearPase(5530L, DESTINO, AHORA, HOY.plusDays(vigencia)))
                .thenReturn(78L);

        ResultadoConsultaResponse response = registrar(parametros, vigencia);

        assertEquals(HOY.plusDays(vigencia), response.pases().getFirst().venceEl());
    }

    @Test
    void sinVigenciaIndicadaUsaLaInicialConfigurada() {
        ParametroService parametros = ParametrosDePrueba.nuevo().paseVigencia(30, 5, 60).construir();
        when(repository.crearPase(5530L, DESTINO, AHORA, HOY.plusDays(30))).thenReturn(78L);

        ResultadoConsultaResponse response = registrar(parametros, null);

        assertEquals(HOY.plusDays(30), response.pases().getFirst().venceEl());
    }

    @Test
    void conMinimoDeCincoRechazaUnPaseDeCuatroDias() {
        ParametroService parametros = ParametrosDePrueba.nuevo().paseVigencia(30, 5, 60).construir();

        ApiException exception = rechazo(parametros, 4);

        assertEquals("vigenciaDias debe estar entre 5 y 60", exception.getMessage());
    }

    @Test
    void conMinimoDeCincoAceptaUnPaseDeCincoDias() {
        aceptada(ParametrosDePrueba.nuevo().paseVigencia(30, 5, 60).construir(), 5);
    }

    @Test
    void conMaximoDeSesentaRechazaUnPaseDeSesentaYUnDias() {
        ParametroService parametros = ParametrosDePrueba.nuevo().paseVigencia(30, 5, 60).construir();

        ApiException exception = rechazo(parametros, 61);

        assertEquals("vigenciaDias debe estar entre 5 y 60", exception.getMessage());
    }

    @Test
    void conMaximoDeSesentaAceptaUnPaseDeSesentaDias() {
        aceptada(ParametrosDePrueba.nuevo().paseVigencia(30, 5, 60).construir(), 60);
    }

    @Test
    void conMaximoDeSesentaRechazaLos90DiasQueAntesEranLaVigenciaInicial() {
        rechazo(ParametrosDePrueba.nuevo().paseVigencia(30, 5, 60).construir(), 90);
    }

    @Test
    void conLosValoresPorDefectoSeConservaElMensajeDeSiempre() {
        assertEquals("vigenciaDias debe estar entre 1 y 365",
                rechazo(ParametroService.porDefecto(), 366).getMessage());
        assertEquals("vigenciaDias debe estar entre 1 y 365",
                rechazo(ParametroService.porDefecto(), 0).getMessage());
    }
}
