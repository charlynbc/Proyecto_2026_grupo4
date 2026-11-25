package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.junit.jupiter.api.extension.ExtendWith;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ConsultaHistorialServiceTest {

    private static final Long SOCIO_ID = 91L;
    private static final LocalDate HOY = LocalDate.of(2026, 10, 22);
    private static final Clock RELOJ = Clock.fixed(
            Instant.parse("2026-10-22T03:00:00Z"),
            ZoneId.of("America/Montevideo")
    );

    @Mock
    private ConsultaRepository repository;

    private ConsultaHistorialService service;

    @BeforeEach
    void setUp() {
        service = new ConsultaHistorialService(repository, RELOJ, ParametroService.porDefecto());
    }

    private static ConsultaRepository.PaginaHistorial paginaVacia(int page, int size, long total) {
        return new ConsultaRepository.PaginaHistorial(List.of(), page, size, total);
    }

    @Test
    void usaFiltrosPredeterminadosPaginacionYFechaDeUruguay() {
        when(repository.listarHistorial(
                SOCIO_ID,
                new ConsultaHistorialFiltro(
                        null, null, null, null, null, "fecha", "desc", 0, 20
                ),
                HOY
        )).thenReturn(paginaVacia(0, 20, 0));

        ConsultaHistorialPageResponse response = service.listar(
                SOCIO_ID, null, null, null, null, null, null, null, null, null
        );

        assertEquals(0, response.total());
        verify(repository).listarHistorial(
                SOCIO_ID,
                new ConsultaHistorialFiltro(
                        null, null, null, null, null, "fecha", "desc", 0, 20
                ),
                HOY
        );
    }

    @Test
    void aceptaEstadosCalculadosYCombinaFiltros() {
        ConsultaHistorialFiltro filtro = new ConsultaHistorialFiltro(
                "NO_ATENDIDA",
                LocalDate.of(2026, 10, 1),
                HOY,
                3L,
                17L,
                "especialidad",
                "asc",
                2,
                10
        );
        when(repository.listarHistorial(SOCIO_ID, filtro, HOY))
                .thenReturn(paginaVacia(2, 10, 21));

        ConsultaHistorialPageResponse response = service.listar(
                SOCIO_ID,
                "NO_ATENDIDA",
                "2026-10-01",
                "2026-10-22",
                "3",
                "17",
                "especialidad",
                "asc",
                "2",
                "10"
        );

        assertEquals(21, response.total());
        assertEquals(2, response.page());
        verify(repository).listarHistorial(SOCIO_ID, filtro, HOY);
    }

    @Test
    void rechazaRangoDeFechasInvertido() {
        assertEquals(
                "VALIDACION",
                assertThrows(ApiException.class, () -> service.listar(
                        SOCIO_ID, null, "2026-10-23", "2026-10-22",
                        null, null, null, null, null, null
                )).getCode()
        );
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaEstadosYOrdenNoPermitidos() {
        assertEquals(
                "VALIDACION",
                assertThrows(ApiException.class, () -> service.listar(
                        SOCIO_ID, "BORRADA", null, null,
                        null, null, null, null, null, null
                )).getCode()
        );
        assertEquals(
                "VALIDACION",
                assertThrows(ApiException.class, () -> service.listar(
                        SOCIO_ID, null, null, null,
                        null, null, "id; DROP TABLE consulta", null, null, null
                )).getCode()
        );
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaFechasIdsYPaginacionInvalidos() {
        for (String[] values : List.of(
                new String[] {"2026-13-01", null, null, null, null, null, null},
                new String[] {null, "0", null, null, null, null, null},
                new String[] {null, "9223372036854775808", null, null, null, null, null},
                new String[] {null, null, null, "-1", null, null, null},
                new String[] {null, null, null, null, "101", null, null}
        )) {
            assertEquals(
                    "VALIDACION",
                    assertThrows(ApiException.class, () -> service.listar(
                            SOCIO_ID, null, values[0], null,
                            values[1], null, null, null, values[3], values[4]
                    )).getCode()
            );
        }
        verifyNoInteractions(repository);
    }

    @Test
    void detalleValidaIdYBuscaUnicamenteParaElSocio() {
        assertEquals(
                "VALIDACION",
                assertThrows(ApiException.class, () -> service.obtener(SOCIO_ID, "0"))
                        .getCode()
        );

        when(repository.obtenerHistorialDelSocio(SOCIO_ID, 44L, HOY))
                .thenReturn(Optional.empty());
        assertEquals(
                "NO_ENCONTRADO",
                assertThrows(ApiException.class, () -> service.obtener(SOCIO_ID, "44"))
                        .getCode()
        );
        verify(repository).obtenerHistorialDelSocio(SOCIO_ID, 44L, HOY);
    }

    // --- cancelable: ahora es 2026-10-22 00:00 en Montevideo ---

    private static ConsultaDTO consulta(long id, String estado, LocalDate fecha, String hora) {
        return new ConsultaDTO(
                id,
                estado,
                fecha,
                2,
                hora,
                "23:00",
                new ConsultaDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                new Especialidad(3L, "Cardiología", false),
                new Consultorio(5L, "Consultorio 5", "Piso 2"),
                null,
                OffsetDateTime.parse("2026-10-14T10:12:45-03:00"),
                null,
                null,
                false
        );
    }

    private static ConsultaRepository.ConsultaConLlegada fila(
            long id, String estado, LocalDate fecha, String hora, boolean llegada) {
        return new ConsultaRepository.ConsultaConLlegada(consulta(id, estado, fecha, hora), llegada);
    }

    private List<ConsultaDTO> listarCon(ParametroService parametros,
                                        ConsultaRepository.ConsultaConLlegada... filas) {
        ConsultaHistorialService servicio = new ConsultaHistorialService(repository, RELOJ, parametros);
        when(repository.listarHistorial(
                SOCIO_ID,
                new ConsultaHistorialFiltro(null, null, null, null, null, "fecha", "desc", 0, 20),
                HOY
        )).thenReturn(new ConsultaRepository.PaginaHistorial(List.of(filas), 0, 20, filas.length));
        return servicio.listar(SOCIO_ID, null, null, null, null, null, null, null, null, null).items();
    }

    @Test
    void listarCalculaCancelableConLlegadaEstadoYPlazoDeCadaConsulta() {
        List<ConsultaDTO> items = listarCon(
                ParametroService.porDefecto(),
                fila(9001, "AGENDADA", HOY, "09:00", false),
                fila(9002, "AGENDADA", HOY, "09:00", true),
                fila(9003, "AGENDADA", HOY, "02:00", false),
                fila(9004, "AGENDADA", HOY, "01:59", false),
                fila(9005, "NO_ASISTIO", HOY.minusDays(1), "09:00", false),
                fila(9006, "NO_ATENDIDA", HOY.minusDays(1), "09:00", true),
                fila(9007, "CANCELADA_SOCIO", HOY.plusDays(1), "09:00", false)
        );

        assertEquals(List.of(true, false, true, false, false, false, false),
                items.stream().map(ConsultaDTO::cancelable).toList());
        // El resto de cada consulta llega igual que lo devolvio el repositorio.
        assertEquals(consulta(9001, "AGENDADA", HOY, "09:00").conCancelable(true), items.get(0));
        assertEquals(consulta(9002, "AGENDADA", HOY, "09:00"), items.get(1));
    }

    @Test
    void listarUsaLasHorasMinimasDelParametroYNoElValorPorDefecto() {
        List<ConsultaDTO> items = listarCon(
                ParametrosDePrueba.nuevo().cancelarHoras(5).construir(),
                fila(9001, "AGENDADA", HOY, "05:00", false),
                fila(9002, "AGENDADA", HOY, "04:59", false),
                fila(9003, "AGENDADA", HOY, "02:00", false)
        );

        assertEquals(List.of(true, false, false),
                items.stream().map(ConsultaDTO::cancelable).toList());
    }

    @Test
    void obtenerCalculaCancelableConLaMismaReglaQueElListado() {
        when(repository.obtenerHistorialDelSocio(SOCIO_ID, 44L, HOY)).thenReturn(Optional.of(
                fila(44, "AGENDADA", HOY, "09:00", false)));
        when(repository.obtenerHistorialDelSocio(SOCIO_ID, 45L, HOY)).thenReturn(Optional.of(
                fila(45, "AGENDADA", HOY, "09:00", true)));
        when(repository.obtenerHistorialDelSocio(SOCIO_ID, 46L, HOY)).thenReturn(Optional.of(
                fila(46, "AGENDADA", HOY, "01:59", false)));
        when(repository.obtenerHistorialDelSocio(SOCIO_ID, 47L, HOY)).thenReturn(Optional.of(
                fila(47, "NO_ASISTIO", HOY.minusDays(1), "09:00", false)));

        assertEquals(consulta(44, "AGENDADA", HOY, "09:00").conCancelable(true),
                service.obtener(SOCIO_ID, "44"));
        assertEquals(false, service.obtener(SOCIO_ID, "45").cancelable());
        assertEquals(false, service.obtener(SOCIO_ID, "46").cancelable());
        assertEquals(false, service.obtener(SOCIO_ID, "47").cancelable());
    }

    @Test
    void obtenerUsaLasHorasMinimasDelParametro() {
        ConsultaHistorialService con5Horas = new ConsultaHistorialService(
                repository, RELOJ, ParametrosDePrueba.nuevo().cancelarHoras(5).construir());
        when(repository.obtenerHistorialDelSocio(SOCIO_ID, 44L, HOY)).thenReturn(Optional.of(
                fila(44, "AGENDADA", HOY, "04:59", false)));
        when(repository.obtenerHistorialDelSocio(SOCIO_ID, 45L, HOY)).thenReturn(Optional.of(
                fila(45, "AGENDADA", HOY, "05:00", false)));

        assertEquals(false, con5Horas.obtener(SOCIO_ID, "44").cancelable());
        assertEquals(true, con5Horas.obtener(SOCIO_ID, "45").cancelable());
    }
}
