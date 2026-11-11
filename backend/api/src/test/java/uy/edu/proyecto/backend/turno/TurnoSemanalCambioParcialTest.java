package uy.edu.proyecto.backend.turno;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDate;
import java.time.LocalTime;
import java.time.ZoneId;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.FechaTurno;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.NumeroExistente;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.NumeroInstancia;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.PatronSemanal;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TurnoSemanalCambioParcialTest {
    private static final LocalDate HOY = LocalDate.of(2026, 11, 10);
    private static final Consultorio ANTERIOR =
            new Consultorio(5L, "Consultorio 5", "Piso 1");
    private static final Consultorio NUEVO =
            new Consultorio(7L, "Consultorio 7", "Piso 2");
    private static final PatronSemanal PATRON = new PatronSemanal(
            41L, 17L, 3L, 5L, 2, HOY, HOY.plusDays(7)
    );
    private static final FechaTurno PRIMERA =
            new FechaTurno(301L, HOY, "ACTIVO", ANTERIOR);
    private static final FechaTurno SEGUNDA =
            new FechaTurno(302L, HOY.plusDays(7), "SUSPENDIDO", ANTERIOR);

    @Mock
    private TurnoSemanalRepository repository;
    @Mock
    private TurnoConsultaRepository consultaRepository;

    private TurnoSemanalService service;

    @BeforeEach
    void setUp() {
        service = new TurnoSemanalService(
                repository,
                consultaRepository,
                Clock.fixed(Instant.parse("2026-11-10T15:00:00Z"),
                        ZoneId.of("America/Montevideo"))
        );
    }

    private void prepararCambio() {
        when(repository.bloquearPatron(41L)).thenReturn(Optional.of(PATRON));
        when(repository.bloquearConsultorio(7L)).thenReturn(Optional.of(NUEVO));
        when(repository.listarFechasDesde(41L, HOY, true))
                .thenReturn(List.of(PRIMERA, SEGUNDA));
    }

    private void prepararRespuesta() {
        when(consultaRepository.obtenerPatron(41L)).thenReturn(Optional.of(
                new TurnoSemanalResponse(
                        41L,
                        new TurnoSemanalResponse.MedicoRef(17L, "Ana", "Pérez"),
                        new Especialidad(3L, "Cardiología", true),
                        ANTERIOR, 2, HOY, HOY.plusDays(7),
                        List.of(), 2, true
                )
        ));
    }

    @Test
    void cambioParcialActualizaSoloLaFechaElegida() {
        prepararCambio();
        prepararRespuesta();
        var respuesta = service.modificarConsultorio(
                41L, new ModificarTurnoSemanalRequest(
                        7L, List.of(301L), false
                )
        );

        assertTrue(respuesta.consultorioVariaPorFecha());
        verify(repository).actualizarConsultorioDeFechas(
                41L, 7L, List.of(301L), HOY
        );
        verify(repository, never()).actualizarConsultorioDelPatron(41L, 7L);
    }

    @Test
    void seleccionDeTodasLasFechasActualizaTambienPatron() {
        prepararCambio();
        prepararRespuesta();
        service.modificarConsultorio(
                41L, new ModificarTurnoSemanalRequest(
                        7L, List.of(301L, 302L), false
                )
        );
        verify(repository).actualizarConsultorioDeFechas(
                41L, 7L, List.of(301L, 302L), HOY
        );
        verify(repository).actualizarConsultorioDelPatron(41L, 7L);
    }

    @Test
    void rechazaFechasAjenasYDuplicadas() {
        prepararCambio();
        ApiException ajena = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(
                                7L, List.of(999L), false
                        )
                )
        );
        assertEquals("VALIDACION", ajena.getCode());
        ApiException duplicada = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(
                                7L, List.of(301L, 301L), false
                        )
                )
        );
        assertEquals("VALIDACION", duplicada.getCode());
        verify(repository, never()).actualizarConsultorioDelPatron(41L, 7L);
    }

    @Test
    void consultasAgendadasExigenConfirmacion() {
        prepararCambio();
        when(repository.contarAgendadasPorFecha(41L, HOY))
                .thenReturn(Map.of(301L, 2));
        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(
                                7L, List.of(301L), false
                        )
                )
        );
        assertEquals("TURNO_NO_MODIFICABLE", error.getCode());
        assertTrue(error.getMessage().contains(HOY.toString()));
        verify(repository, never()).actualizarConsultorioDeFechas(
                41L, 7L, List.of(301L), HOY
        );
    }

    @Test
    void confirmacionPermiteElCambioSinCancelarConsultas() {
        prepararCambio();
        prepararRespuesta();
        when(repository.contarAgendadasPorFecha(41L, HOY))
                .thenReturn(Map.of(301L, 2));
        service.modificarConsultorio(
                41L, new ModificarTurnoSemanalRequest(
                        7L, List.of(301L), true
                )
        );
        verify(repository).actualizarConsultorioDeFechas(
                41L, 7L, List.of(301L), HOY
        );
    }

    @Test
    void confirmacionNoPermiteForzarUnSolapamiento() {
        prepararCambio();
        when(repository.numerosDelPatron(41L)).thenReturn(List.of(
                new NumeroInstancia(1L, 1,
                        LocalTime.of(9, 0), LocalTime.of(9, 20))
        ));
        when(repository.buscarNumerosActivosDeOtrosPatrones(
                17L, 7L, HOY, HOY, 41L
        )).thenReturn(List.of(
                new NumeroExistente(HOY, 22L, 7L, 3,
                        LocalTime.of(9, 10), LocalTime.of(9, 30))
        ));
        ApiException error = assertThrows(ApiException.class, () ->
                service.modificarConsultorio(
                        41L, new ModificarTurnoSemanalRequest(
                                7L, List.of(301L), true
                        )
                )
        );
        assertEquals("SOLAPAMIENTO_TURNO", error.getCode());
        verify(repository, never()).actualizarConsultorioDelPatron(41L, 7L);
    }

    @Test
    void vistaPreviaNoEscribeYMuestraFechasSuspendidas() {
        when(repository.obtenerPatronSinBloqueo(41L))
                .thenReturn(Optional.of(PATRON));
        when(repository.obtenerConsultorioSinBloqueo(7L))
                .thenReturn(Optional.of(NUEVO));
        when(repository.listarFechasDesde(41L, HOY, false))
                .thenReturn(List.of(PRIMERA, SEGUNDA));
        when(repository.contarAgendadasPorFecha(41L, HOY))
                .thenReturn(Map.of(301L, 2));

        var vista = service.vistaPreviaConsultorio(
                41L, new ModificarTurnoSemanalRequest(7L)
        );

        assertEquals(2, vista.fechas().size());
        assertEquals(2, vista.fechas().getFirst().consultasAgendadas());
        assertEquals("SUSPENDIDO", vista.fechas().getLast().estado());
        assertFalse(vista.fechas().getLast().solapamientos().iterator().hasNext());
        verify(repository, never()).actualizarConsultorioDelPatron(41L, 7L);
    }
}
