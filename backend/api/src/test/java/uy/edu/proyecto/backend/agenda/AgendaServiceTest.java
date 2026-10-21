package uy.edu.proyecto.backend.agenda;

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
class AgendaServiceTest {

    @Mock
    private AgendaRepository repository;

    @Test
    void consultaDisponibilidadConOrdenYSentidoPorDefecto() {
        when(repository.existeEspecialidad(3L)).thenReturn(true);
        when(repository.consultarDisponibilidad(
                new FiltroDisponibilidadDTO(3L, null, null, null, "fecha", "asc")
        )).thenReturn(List.of());

        AgendaService service = new AgendaService(repository);

        assertEquals(
                List.of(),
                service.consultarDisponibilidad(
                        "3", null, null, null, null, null
                )
        );
        verify(repository).existeEspecialidad(3L);
        verify(repository).consultarDisponibilidad(
                new FiltroDisponibilidadDTO(3L, null, null, null, "fecha", "asc")
        );
    }

    @Test
    void convierteFiltrosOpcionalesYOrdenSolicitados() {
        when(repository.existeEspecialidad(3L)).thenReturn(true);
        when(repository.existeMedico(17L)).thenReturn(true);
        when(repository.consultarDisponibilidad(
                new FiltroDisponibilidadDTO(
                        3L,
                        17L,
                        LocalDate.of(2026, 10, 20),
                        LocalDate.of(2026, 11, 20),
                        "apellidoMedico",
                        "desc"
                )
        )).thenReturn(List.of());

        AgendaService service = new AgendaService(repository);
        service.consultarDisponibilidad(
                "3",
                "17",
                "2026-10-20",
                "2026-11-20",
                "apellidoMedico",
                "desc"
        );

        verify(repository).consultarDisponibilidad(new FiltroDisponibilidadDTO(
                3L,
                17L,
                LocalDate.of(2026, 10, 20),
                LocalDate.of(2026, 11, 20),
                "apellidoMedico",
                "desc"
        ));
    }

    @Test
    void rechazaEspecialidadFaltanteAntesDeConsultarRepositorio() {
        AgendaService service = new AgendaService(repository);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.consultarDisponibilidad(
                        null, null, null, null, null, null
                )
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaIdsNoNumericosConErrorDeValidacion() {
        AgendaService service = new AgendaService(repository);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.consultarDisponibilidad(
                        "abc", null, null, null, null, null
                )
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaRangoDeFechasInvertido() {
        AgendaService service = new AgendaService(repository);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.consultarDisponibilidad(
                        "3",
                        null,
                        "2026-11-20",
                        "2026-10-20",
                        null,
                        null
                )
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaOrdenNoPermitido() {
        AgendaService service = new AgendaService(repository);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.consultarDisponibilidad(
                        "3", null, null, null, "nombre", "asc"
                )
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void especialidadInexistenteDevuelveNoEncontrado() {
        when(repository.existeEspecialidad(33L)).thenReturn(false);
        AgendaService service = new AgendaService(repository);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.consultarDisponibilidad(
                        "33", null, null, null, null, null
                )
        );

        assertEquals("NO_ENCONTRADO", exception.getCode());
        verify(repository).existeEspecialidad(33L);
    }

    @Test
    void medicoInexistenteDevuelveNoEncontrado() {
        when(repository.existeEspecialidad(3L)).thenReturn(true);
        when(repository.existeMedico(17L)).thenReturn(false);
        AgendaService service = new AgendaService(repository);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.consultarDisponibilidad(
                        "3", "17", null, null, null, null
                )
        );

        assertEquals("NO_ENCONTRADO", exception.getCode());
    }

    @Test
    void rechazaFormatoDeFechaInvalido() {
        AgendaService service = new AgendaService(repository);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.consultarDisponibilidad(
                        "3", null, "20/10/2026", null, null, null
                )
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }
}
