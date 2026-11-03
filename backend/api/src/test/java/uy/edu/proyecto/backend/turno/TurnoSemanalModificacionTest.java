package uy.edu.proyecto.backend.turno;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;

import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.NumeroExistente;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.NumeroInstancia;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.PatronSemanal;

/** RF-20: modificacion del consultorio de un turno semanal. */
class TurnoSemanalModificacionTest {

    private static final ZoneId ZONA = ZoneId.of("America/Montevideo");
    private static final LocalDate HOY = LocalDate.of(2026, 10, 20);
    private static final LocalDate FECHA_1 = LocalDate.of(2026, 10, 22);
    private static final LocalDate FECHA_2 = LocalDate.of(2026, 10, 29);

    private final TurnoSemanalRepository repository =
            mock(TurnoSemanalRepository.class);
    private final TurnoConsultaRepository consultaRepository =
            mock(TurnoConsultaRepository.class);
    private final TurnoSemanalService service = new TurnoSemanalService(
            repository,
            consultaRepository,
            Clock.fixed(Instant.from(
                    HOY.atStartOfDay(ZONA).toInstant()), ZONA)
    );

    private PatronSemanal patron() {
        return new PatronSemanal(
                41L, 17L, 3L, 5L, 4,
                LocalDate.of(2026, 10, 1),
                LocalDate.of(2026, 11, 30)
        );
    }

    private TurnoSemanalResponse respuesta(long consultorioId) {
        return new TurnoSemanalResponse(
                41L,
                new TurnoSemanalResponse.MedicoRef(17L, "Ana", "Pérez"),
                new uy.edu.proyecto.backend.especialidad.Especialidad(
                        3L, "Cardiología", true),
                new Consultorio(consultorioId, "Consultorio " + consultorioId,
                        "Piso 1"),
                4,
                LocalDate.of(2026, 10, 1),
                LocalDate.of(2026, 11, 30),
                List.of(new TurnoSemanalResponse.NumeroSemanalResponse(
                        1, "09:00", "09:20")),
                8
        );
    }

    @BeforeEach
    void setUp() {
        lenient().when(repository.bloquearPatron(41L))
                .thenReturn(Optional.of(patron()));
        lenient().when(repository.bloquearConsultorio(7L))
                .thenReturn(Optional.of(
                        new Consultorio(7L, "Consultorio 7", "Piso 2")));
        lenient().when(repository.bloquearFechasActivasDesde(41L, HOY))
                .thenReturn(List.of(FECHA_1, FECHA_2));
        lenient().when(repository.contarConsultasAgendadasDesde(41L, HOY))
                .thenReturn(0);
        lenient().when(repository.numerosDelPatron(41L))
                .thenReturn(List.of(new NumeroInstancia(
                        101L, 1, LocalTime.of(9, 0), LocalTime.of(9, 20))));
        lenient().when(repository.buscarNumerosActivosDeOtrosPatrones(
                17L, 7L, FECHA_1, FECHA_2, 41L))
                .thenReturn(List.of());
        lenient().when(consultaRepository.obtenerPatron(41L))
                .thenReturn(Optional.of(respuesta(7L)));
    }

    @Test
    void modificacionValidaActualizaConfiguracionYFechasVigentes() {
        TurnoSemanalResponse r = service.modificarConsultorio(
                41L, new ModificarTurnoSemanalRequest(7L));

        assertEquals(7L, r.consultorio().id());
        verify(repository).actualizarConsultorio(41L, 7L, HOY);
    }

    @Test
    void patronInexistenteDevuelve404() {
        when(repository.bloquearPatron(99L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        99L, new ModificarTurnoSemanalRequest(7L)));

        assertEquals(HttpStatus.NOT_FOUND, error.getStatus());
        assertEquals("NO_ENCONTRADO", error.getCode());
    }

    @Test
    void consultorioInexistenteDevuelve404() {
        when(repository.bloquearConsultorio(77L)).thenReturn(Optional.empty());

        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(77L)));

        assertEquals(HttpStatus.NOT_FOUND, error.getStatus());
        verify(repository, never()).actualizarConsultorio(any(), any(), any());
    }

    @Test
    void mismoConsultorioEsIdempotenteYNoTocaNada() {
        when(consultaRepository.obtenerPatron(41L))
                .thenReturn(Optional.of(respuesta(5L)));

        TurnoSemanalResponse r = service.modificarConsultorio(
                41L, new ModificarTurnoSemanalRequest(5L));

        assertEquals(5L, r.consultorio().id());
        verify(repository, never()).actualizarConsultorio(any(), any(), any());
        verify(repository, never()).bloquearFechasActivasDesde(any(), any());
    }

    @Test
    void sinFechasVigentesDevuelve409() {
        when(repository.bloquearFechasActivasDesde(41L, HOY))
                .thenReturn(List.of());

        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(7L)));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("TURNO_NO_MODIFICABLE", error.getCode());
        verify(repository, never()).actualizarConsultorio(any(), any(), any());
    }

    @Test
    void conConsultasAgendadasVigentesDevuelve409() {
        when(repository.contarConsultasAgendadasDesde(41L, HOY))
                .thenReturn(2);

        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(7L)));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("TURNO_NO_MODIFICABLE", error.getCode());
        verify(repository, never()).actualizarConsultorio(any(), any(), any());
    }

    @Test
    void solapamientoConOtroTurnoDelConsultorioNuevoDevuelve409() {
        when(repository.buscarNumerosActivosDeOtrosPatrones(
                17L, 7L, FECHA_1, FECHA_2, 41L))
                .thenReturn(List.of(new NumeroExistente(
                        FECHA_1, 88L, 7L, 3,
                        LocalTime.of(9, 10), LocalTime.of(9, 30))));

        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(7L)));

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("SOLAPAMIENTO_TURNO", error.getCode());
        verify(repository, never()).actualizarConsultorio(any(), any(), any());
    }

    @Test
    void solapamientoConOtroTurnoDelMismoMedicoDevuelve409() {
        when(repository.buscarNumerosActivosDeOtrosPatrones(
                17L, 7L, FECHA_1, FECHA_2, 41L))
                .thenReturn(List.of(new NumeroExistente(
                        FECHA_2, 17L, 12L, 1,
                        LocalTime.of(8, 50), LocalTime.of(9, 10))));

        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(7L)));

        assertEquals("SOLAPAMIENTO_TURNO", error.getCode());
    }

    @Test
    void turnoEnLaMismaFranjaPeroEnFechaNoVigenteNoConflicta() {
        // Mismo consultorio nuevo y horario solapado, pero en una fecha en
        // la que este patron no tiene turno activo: no hay conflicto.
        when(repository.buscarNumerosActivosDeOtrosPatrones(
                17L, 7L, FECHA_1, FECHA_2, 41L))
                .thenReturn(List.of(new NumeroExistente(
                        LocalDate.of(2026, 10, 23), 88L, 7L, 3,
                        LocalTime.of(9, 0), LocalTime.of(9, 20))));

        TurnoSemanalResponse r = service.modificarConsultorio(
                41L, new ModificarTurnoSemanalRequest(7L));

        assertEquals(7L, r.consultorio().id());
        verify(repository).actualizarConsultorio(41L, 7L, HOY);
    }

    @Test
    void solicitudInvalidaDevuelve400() {
        for (ModificarTurnoSemanalRequest request
                : new ModificarTurnoSemanalRequest[]{
                null,
                new ModificarTurnoSemanalRequest(null),
                new ModificarTurnoSemanalRequest(0L),
                new ModificarTurnoSemanalRequest(-3L)
        }) {
            ApiException error = assertThrows(ApiException.class, () ->
                    service.modificarConsultorio(41L, request));
            assertEquals("VALIDACION", error.getCode());
        }
        verify(repository, never()).bloquearPatron(any());
    }
}
