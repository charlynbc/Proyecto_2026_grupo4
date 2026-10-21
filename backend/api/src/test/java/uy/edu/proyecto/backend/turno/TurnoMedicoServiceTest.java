package uy.edu.proyecto.backend.turno;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

class TurnoMedicoServiceTest {

    private static final Clock RELOJ = Clock.fixed(
            OffsetDateTime.parse("2026-10-20T08:00:00-03:00").toInstant(),
            ZoneId.of("America/Montevideo")
    );

    @Test
    void listaTurnosDelMedicoYFechaIndicados() {
        TurnoMedicoRepository repository = mock(TurnoMedicoRepository.class);
        when(repository.listar(17L, LocalDate.of(2026, 10, 20)))
                .thenReturn(List.of());

        TurnosMedicoResponse response = new TurnoMedicoService(
                repository,
                RELOJ
        ).listar(17L, "2026-10-20");

        assertEquals(List.of(), response.items());
        verify(repository).listar(17L, LocalDate.of(2026, 10, 20));
    }

    @Test
    void rechazaFechaInvalidaAntesDeConsultarRepositorio() {
        TurnoMedicoRepository repository = mock(TurnoMedicoRepository.class);

        assertThrows(ApiException.class, () ->
                new TurnoMedicoService(repository, RELOJ)
                        .listar(17L, "20-10-2026")
        );
    }

    @Test
    void validaOrdenYDevuelveNoEncontradoParaTurnoAjeno() {
        TurnoMedicoRepository repository = mock(TurnoMedicoRepository.class);
        TurnoMedicoService service = new TurnoMedicoService(
                repository,
                RELOJ
        );

        assertThrows(ApiException.class, () ->
                service.obtenerNumeros(17L, 44L, null, "numero", "asc")
        );
        when(repository.obtenerNumeros(
                17L,
                44L,
                null,
                "hora",
                "asc",
                LocalDate.of(2026, 10, 20),
                LocalDate.of(2026, 11, 19),
                OffsetDateTime.parse("2026-10-20T10:00:00-03:00")
        )).thenReturn(Optional.empty());

        assertThrows(ApiException.class, () ->
                service.obtenerNumeros(17L, 44L, null, null, null)
        );
    }
}
