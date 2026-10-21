package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TurnoConsultaServiceTest {

    @Mock
    private TurnoConsultaRepository repository;

    @Test
    void aplicaFiltrosDefaultsYPaginacionDelContrato() {
        when(repository.existeMedico(17L)).thenReturn(true);
        when(repository.existeEspecialidad(3L)).thenReturn(true);
        TurnosPageResponse respuesta = new TurnosPageResponse(
                List.of(),
                2,
                15,
                31
        );
        when(repository.listar(new FiltroTurnosDTO(
                17L,
                3L,
                2,
                LocalDate.of(2026, 10, 20),
                LocalDate.of(2026, 12, 20),
                "ACTIVO",
                "medico",
                "desc",
                2,
                15
        ))).thenReturn(respuesta);

        TurnosPageResponse actual = new TurnoConsultaService(repository).listar(
                "17",
                "3",
                "2",
                "2026-10-20",
                "2026-12-20",
                "ACTIVO",
                "medico",
                "desc",
                "2",
                "15"
        );

        assertEquals(respuesta, actual);
    }

    @Test
    void usaOrdenPaginacionPorDefecto() {
        when(repository.listar(new FiltroTurnosDTO(
                null, null, null, null, null, null,
                "fecha", "asc", 0, 20
        ))).thenReturn(new TurnosPageResponse(List.of(), 0, 20, 0));

        new TurnoConsultaService(repository).listar(
                null, null, null, null, null, null, null, null, null, null
        );

        verify(repository).listar(new FiltroTurnosDTO(
                null, null, null, null, null, null,
                "fecha", "asc", 0, 20
        ));
    }

    @Test
    void rechazaValoresDeEstadoOrdenYPaginaFueraDelContrato() {
        TurnoConsultaService service = new TurnoConsultaService(repository);

        for (String[] solicitud : List.of(
                new String[] {null, null, null, null, null, "CANCELADO",
                        null, null, null, null},
                new String[] {null, null, null, null, null, null,
                        "nombre", null, null, null},
                new String[] {null, null, null, null, null, null,
                        null, null, "-1", null},
                new String[] {null, null, null, null, null, null,
                        null, null, null, "101"}
        )) {
            ApiException exception = assertThrows(ApiException.class, () ->
                    service.listar(
                            solicitud[0], solicitud[1], solicitud[2],
                            solicitud[3], solicitud[4], solicitud[5],
                            solicitud[6], solicitud[7], solicitud[8],
                            solicitud[9]
                    )
            );
            assertEquals("VALIDACION", exception.getCode());
        }
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaFechasInvertidasYDiaInvalido() {
        TurnoConsultaService service = new TurnoConsultaService(repository);

        ApiException rango = assertThrows(ApiException.class, () ->
                service.listar(
                        null, null, null, "2026-11-01", "2026-10-01",
                        null, null, null, null, null
                )
        );
        ApiException dia = assertThrows(ApiException.class, () ->
                service.listar(
                        null, null, "8", null, null, null,
                        null, null, null, null
                )
        );

        assertEquals("VALIDACION", rango.getCode());
        assertEquals("VALIDACION", dia.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void devuelveNoEncontradoParaMedicoOEspecialidadInexistente() {
        when(repository.existeMedico(999L)).thenReturn(false);
        TurnoConsultaService service = new TurnoConsultaService(repository);

        ApiException exception = assertThrows(ApiException.class, () ->
                service.listar(
                        "999", null, null, null, null, null,
                        null, null, null, null
                )
        );

        assertEquals("NO_ENCONTRADO", exception.getCode());
    }

    @Test
    void consultaPatronSemanalExistenteYRechazaIdsInvalidos() {
        TurnoSemanalResponse response = new TurnoSemanalResponse(
                4L,
                new TurnoSemanalResponse.MedicoRef(17L, "Marta", "Rodríguez"),
                new uy.edu.proyecto.backend.especialidad.Especialidad(
                        3L, "Cardiología", true
                ),
                new uy.edu.proyecto.backend.consultorio.Consultorio(
                        5L, "Consultorio 5", "Piso 2"
                ),
                2,
                LocalDate.of(2026, 10, 20),
                LocalDate.of(2026, 12, 15),
                List.of(),
                9
        );
        when(repository.obtenerPatron(4L)).thenReturn(java.util.Optional.of(response));
        TurnoConsultaService service = new TurnoConsultaService(repository);

        assertEquals(response, service.obtenerPatron(4L));
        assertEquals(
                "VALIDACION",
                assertThrows(ApiException.class, () -> service.obtenerPatron(0L))
                        .getCode()
        );
        when(repository.obtenerPatron(5L)).thenReturn(java.util.Optional.empty());
        assertEquals(
                "NO_ENCONTRADO",
                assertThrows(ApiException.class, () -> service.obtenerPatron(5L))
                        .getCode()
        );
    }
}
