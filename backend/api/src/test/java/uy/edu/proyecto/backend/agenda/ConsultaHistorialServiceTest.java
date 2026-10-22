package uy.edu.proyecto.backend.agenda;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;
import org.junit.jupiter.api.extension.ExtendWith;

import uy.edu.proyecto.backend.exception.ApiException;

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
        service = new ConsultaHistorialService(repository, RELOJ);
    }

    @Test
    void usaFiltrosPredeterminadosPaginacionYFechaDeUruguay() {
        when(repository.listarHistorial(
                SOCIO_ID,
                new ConsultaHistorialFiltro(
                        null, null, null, null, null, "fecha", "desc", 0, 20
                ),
                HOY
        )).thenReturn(new ConsultaHistorialPageResponse(List.of(), 0, 20, 0));

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
                .thenReturn(new ConsultaHistorialPageResponse(List.of(), 2, 10, 21));

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
                .thenReturn(java.util.Optional.empty());
        assertEquals(
                "NO_ENCONTRADO",
                assertThrows(ApiException.class, () -> service.obtener(SOCIO_ID, "44"))
                        .getCode()
        );
        verify(repository).obtenerHistorialDelSocio(SOCIO_ID, 44L, HOY);
    }
}
