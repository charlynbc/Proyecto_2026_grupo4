package uy.edu.proyecto.backend.turno;

import java.time.LocalDate;
import java.time.LocalTime;
import java.util.List;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.CuentaMedica;
import uy.edu.proyecto.backend.turno.TurnoSemanalRepository.NumeroExistente;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class TurnoSemanalServiceTest {

    private static final LocalDate INICIO = LocalDate.of(2026, 10, 20);
    private static final LocalDate FIN = LocalDate.of(2026, 10, 27);

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
                java.time.Clock.system(
                        java.time.ZoneId.of("America/Montevideo"))
        );
        lenient().when(repository.bloquearMedico(17L)).thenReturn(Optional.of(
                new CuentaMedica(17L, "MEDICO", true, "Ana", "Pérez")
        ));
        lenient().when(repository.bloquearConsultorio(5L)).thenReturn(Optional.of(
                new Consultorio(5L, "Consultorio 2", "Piso 1")
        ));
        lenient().when(repository.buscarEspecialidadDelMedico(17L, 3L))
                .thenReturn(Optional.of(new Especialidad(3L, "Cardiología", true)));
        lenient().when(repository.buscarNumerosActivos(
                17L,
                5L,
                INICIO,
                FIN
        )).thenReturn(List.of());
    }

    @Test
    void creaPatronNumerosYTurnosConcretosEnCadaFechaSemanal() {
        when(repository.crearPatron(
                17L, 3L, 5L, 91L, 2, INICIO, FIN
        )).thenReturn(41L);
        when(repository.crearNumeroSemanal(
                41L, 1, LocalTime.of(9, 0), LocalTime.of(9, 20)
        )).thenReturn(101L);
        when(repository.crearNumeroSemanal(
                41L, 2, LocalTime.of(9, 20), LocalTime.of(9, 40)
        )).thenReturn(102L);
        when(repository.crearTurno(41L, 5L, INICIO)).thenReturn(201L);
        when(repository.crearTurno(41L, 5L, FIN)).thenReturn(202L);

        TurnoSemanalResponse response = service.crear(request(
                new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                        2, "09:20", "09:40"
                ),
                new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                        1, "09:00", "09:20"
                )
        ), 91L);

        assertEquals(41L, response.id());
        assertEquals(2, response.cantidadTurnos());
        assertEquals("Ana", response.medico().nombre());
        assertEquals("Cardiología", response.especialidad().nombre());
        assertEquals("Consultorio 2", response.consultorio().nombre());
        assertEquals(1, response.numeros().getFirst().numero());
        assertEquals("09:00", response.numeros().getFirst().horaInicio());
        verify(repository).crearNumeros(201L, List.of(
                new TurnoSemanalRepository.NumeroInstancia(
                        101L, 1, LocalTime.of(9, 0), LocalTime.of(9, 20)
                ),
                new TurnoSemanalRepository.NumeroInstancia(
                        102L, 2, LocalTime.of(9, 20), LocalTime.of(9, 40)
                )
        ));
        verify(repository).crearNumeros(202L, List.of(
                new TurnoSemanalRepository.NumeroInstancia(
                        101L, 1, LocalTime.of(9, 0), LocalTime.of(9, 20)
                ),
                new TurnoSemanalRepository.NumeroInstancia(
                        102L, 2, LocalTime.of(9, 20), LocalTime.of(9, 40)
                )
        ));
    }

    @Test
    void rechazaNumerosQueSeSolapanAntesDeConsultarRepositorio() {
        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:00", "09:30"
                        ),
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                2, "09:25", "09:45"
                        )
                ), 91L)
        );

        assertEquals("VALIDACION", exception.getCode());
        verify(repository, never()).bloquearMedico(17L);
    }

    @Test
    void rechazaDuracionFueraDelRangoPermitido() {
        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:00", "09:05"
                        )
                ), 91L)
        );

        assertEquals("VALIDACION", exception.getCode());
        verify(repository, never()).crearPatron(
                17L, 3L, 5L, 91L, 2, INICIO, FIN
        );
    }

    @Test
    void rechazaHorarioQueNoEsMultiploDeCincoMinutos() {
        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:01", "09:20"
                        )
                ), 91L)
        );

        assertEquals("VALIDACION", exception.getCode());
    }

    @Test
    void rechazaNumerosRepetidos() {
        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:00", "09:20"
                        ),
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:20", "09:40"
                        )
                ), 91L)
        );

        assertEquals("VALIDACION", exception.getCode());
    }

    @Test
    void rechazaRangoSinFechaDelDiaIndicado() {
        AltaTurnoSemanalRequest solicitud = new AltaTurnoSemanalRequest(
                17L,
                3L,
                5L,
                2,
                LocalDate.of(2026, 10, 19),
                LocalDate.of(2026, 10, 19),
                List.of(new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                        1, "09:00", "09:20"
                ))
        );

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.crear(solicitud, 91L)
        );

        assertEquals("VALIDACION", exception.getCode());
        verify(repository, never()).bloquearMedico(17L);
    }

    @Test
    void rechazaMedicoInactivo() {
        when(repository.bloquearMedico(17L)).thenReturn(Optional.of(
                new CuentaMedica(17L, "MEDICO", false, "Ana", "Pérez")
        ));

        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:00", "09:20"
                        )
                ), 91L)
        );

        assertEquals("MEDICO_INACTIVO", exception.getCode());
        verify(repository, never()).crearPatron(
                17L, 3L, 5L, 91L, 2, INICIO, FIN
        );
    }

    @Test
    void rechazaEspecialidadQueNoPerteneceAlMedico() {
        when(repository.buscarEspecialidadDelMedico(17L, 3L))
                .thenReturn(Optional.empty());

        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:00", "09:20"
                        )
                ), 91L)
        );

        assertEquals("ESPECIALIDAD_NO_DEL_MEDICO", exception.getCode());
        verify(repository, never()).crearPatron(
                17L, 3L, 5L, 91L, 2, INICIO, FIN
        );
    }

    @Test
    void rechazaSolapamientoConOtroTurnoActivoSinCrearDatos() {
        when(repository.buscarNumerosActivos(
                17L, 5L, INICIO, FIN
        )).thenReturn(List.of(new NumeroExistente(
                INICIO, 17L, 8L, 4,
                LocalTime.of(9, 10), LocalTime.of(9, 30)
        )));

        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:00", "09:20"
                        )
                ), 91L)
        );

        assertEquals("SOLAPAMIENTO_TURNO", exception.getCode());
        assertTrue(exception.getMessage().contains(INICIO.toString()));
        assertTrue(exception.getMessage().contains("número nuevo 1"));
        assertTrue(exception.getMessage().contains("número existente 4"));
        verify(repository, never()).crearPatron(
                17L, 3L, 5L, 91L, 2, INICIO, FIN
        );
    }

    @Test
    void rechazaSolapamientoConOtroMedicoEnElMismoConsultorio() {
        when(repository.buscarNumerosActivos(
                17L, 5L, INICIO, FIN
        )).thenReturn(List.of(new NumeroExistente(
                INICIO, 23L, 5L, 6,
                LocalTime.of(9, 10), LocalTime.of(9, 30)
        )));

        ApiException exception = assertThrows(ApiException.class, () ->
                service.crear(request(
                        new AltaTurnoSemanalRequest.NumeroSemanalRequest(
                                1, "09:00", "09:20"
                        )
                ), 91L)
        );

        assertEquals("SOLAPAMIENTO_TURNO", exception.getCode());
        assertTrue(exception.getMessage().contains("número existente 6"));
        verify(repository, never()).crearPatron(
                17L, 3L, 5L, 91L, 2, INICIO, FIN
        );
    }

    private AltaTurnoSemanalRequest request(
            AltaTurnoSemanalRequest.NumeroSemanalRequest... numeros
    ) {
        return new AltaTurnoSemanalRequest(
                17L,
                3L,
                5L,
                2,
                INICIO,
                FIN,
                List.of(numeros)
        );
    }
}
