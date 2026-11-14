package uy.edu.proyecto.backend.agenda;

import java.time.LocalDate;
import java.time.LocalTime;
import java.time.OffsetDateTime;
import java.util.Optional;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.agenda.ConsultaRepository.NumeroParaAgendar;
import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertAll;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class ConsultaServiceTest {

    private static final Long SOCIO_ID = 91L;
    private static final Long NUMERO_ID = 4501L;
    private static final CrearConsultaRequest SOLICITUD =
            new CrearConsultaRequest(NUMERO_ID, null);

    @Mock
    private ConsultaRepository repository;

    private ConsultaService service;

    @BeforeEach
    void setUp() {
        service = new ConsultaService(repository, ParametroService.porDefecto());
        lenient().when(repository.bloquearSocioHabilitado(SOCIO_ID)).thenReturn(true);
        lenient().when(repository.bloquearNumero(NUMERO_ID))
                .thenReturn(Optional.of(numero(false)));
        lenient().when(repository.contarConsultasAgendadas(SOCIO_ID)).thenReturn(0L);
        lenient().when(repository.contarConsultasAgendadasEnEspecialidad(SOCIO_ID, 3L))
                .thenReturn(0L);
        lenient().when(repository.tieneConsultaSuperpuesta(
                SOCIO_ID,
                LocalDate.of(2026, 11, 3),
                LocalTime.of(9, 0),
                LocalTime.of(9, 20)
        )).thenReturn(false);
    }

    @Test
    void agendaConsultaYRegistraNotificacionDentroDelFlujo() {
        ConsultaDTO expected = consultaEsperada(null);
        when(repository.crear(SOCIO_ID, numero(false), null))
                .thenReturn(Optional.of(expected));

        ConsultaDTO actual = service.agendar(SOCIO_ID, SOLICITUD);

        assertAll(
                () -> assertEquals(expected, actual),
                () -> verify(repository).crearNotificacionAgenda(9001L)
        );
    }

    @Test
    void traduceElIndiceUnicoDeNumeroOcupadoAConflicto409SinNotificarNiTocarOtrasConsultas() {
        when(repository.crear(SOCIO_ID, numero(false), null))
                .thenThrow(new org.springframework.dao.DuplicateKeyException(
                        "uq_consulta_numero_no_cancelada"));

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertAll(
                () -> assertEquals(org.springframework.http.HttpStatus.CONFLICT, exception.getStatus()),
                () -> assertEquals("NUMERO_NO_DISPONIBLE", exception.getCode()),
                () -> verify(repository, never()).crearNotificacionAgenda(org.mockito.ArgumentMatchers.anyLong()),
                () -> verify(repository, org.mockito.Mockito.times(1)).crear(SOCIO_ID, numero(false), null)
        );
    }

    @Test
    void rechazaSocioInexistenteOInhabilitado() {
        when(repository.bloquearSocioHabilitado(SOCIO_ID)).thenReturn(false);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("NO_ENCONTRADO", exception.getCode());
        verify(repository, never()).bloquearNumero(NUMERO_ID);
    }

    @Test
    void rechazaNumeroDesconocido() {
        when(repository.bloquearNumero(NUMERO_ID)).thenReturn(Optional.empty());

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("NO_ENCONTRADO", exception.getCode());
        verify(repository, never()).crear(SOCIO_ID, numero(false), null);
    }

    @Test
    void rechazaFechaSuspendidaOMedicoInactivo() {
        when(repository.bloquearNumero(NUMERO_ID))
                .thenReturn(Optional.of(numero(false, "SUSPENDIDO", true)));

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("NUMERO_NO_DISPONIBLE", exception.getCode());
        verify(repository, never()).crear(SOCIO_ID, numero(false), null);
    }

    @Test
    void rechazaVentanaFueraDeDosHorasYTtreintaDias() {
        when(repository.bloquearNumero(NUMERO_ID))
                .thenReturn(Optional.of(numero(false, "ACTIVO", false)));

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("ANTICIPACION_INVALIDA", exception.getCode());
        verify(repository, never()).contarConsultasAgendadas(SOCIO_ID);
    }

    @Test
    void limitaATresConsultasAgendadas() {
        when(repository.contarConsultasAgendadas(SOCIO_ID)).thenReturn(3L);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("LIMITE_TOTAL", exception.getCode());
        assertEquals("El socio ya tiene el máximo de 3 consultas agendadas",
                exception.getMessage());
        verify(repository, never()).crear(SOCIO_ID, numero(false), null);
    }

    @Test
    void limitaUnaConsultaAgendadaPorEspecialidad() {
        when(repository.contarConsultasAgendadasEnEspecialidad(SOCIO_ID, 3L))
                .thenReturn(1L);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("LIMITE_ESPECIALIDAD", exception.getCode());
        assertEquals("El socio ya tiene una consulta agendada en esta especialidad",
                exception.getMessage());
        verify(repository, never()).crear(SOCIO_ID, numero(false), null);
    }

    private ConsultaService conParametros(ParametroService parametros) {
        return new ConsultaService(repository, parametros);
    }

    @Test
    void conTotalDeCincoSePermiteLaTerceraYSeRechazaLaQuinta() {
        ConsultaService cinco = conParametros(
                ParametrosDePrueba.nuevo().consultasTotal(5).construir());
        when(repository.contarConsultasAgendadas(SOCIO_ID)).thenReturn(3L);
        when(repository.crear(SOCIO_ID, numero(false), null))
                .thenReturn(Optional.of(consultaEsperada(null)));

        assertEquals(9001L, cinco.agendar(SOCIO_ID, SOLICITUD).id());

        when(repository.contarConsultasAgendadas(SOCIO_ID)).thenReturn(5L);
        ApiException exception = assertThrows(
                ApiException.class, () -> cinco.agendar(SOCIO_ID, SOLICITUD));
        assertEquals("LIMITE_TOTAL", exception.getCode());
        assertEquals("El socio ya tiene el máximo de 5 consultas agendadas",
                exception.getMessage());
    }

    @Test
    void conTotalDeUnaElMensajeVaEnSingular() {
        ConsultaService una = conParametros(
                ParametrosDePrueba.nuevo().consultasTotal(1).construir());
        when(repository.contarConsultasAgendadas(SOCIO_ID)).thenReturn(1L);

        ApiException exception = assertThrows(
                ApiException.class, () -> una.agendar(SOCIO_ID, SOLICITUD));

        assertEquals("LIMITE_TOTAL", exception.getCode());
        assertEquals("El socio ya tiene el máximo de 1 consulta agendada",
                exception.getMessage());
    }

    @Test
    void conDosPorEspecialidadSePermiteLaSegundaYSeRechazaLaTercera() {
        ConsultaService dos = conParametros(
                ParametrosDePrueba.nuevo().consultasPorEspecialidad(2).construir());
        when(repository.contarConsultasAgendadasEnEspecialidad(SOCIO_ID, 3L)).thenReturn(1L);
        when(repository.crear(SOCIO_ID, numero(false), null))
                .thenReturn(Optional.of(consultaEsperada(null)));

        assertEquals(9001L, dos.agendar(SOCIO_ID, SOLICITUD).id());

        when(repository.contarConsultasAgendadasEnEspecialidad(SOCIO_ID, 3L)).thenReturn(2L);
        ApiException exception = assertThrows(
                ApiException.class, () -> dos.agendar(SOCIO_ID, SOLICITUD));
        assertEquals("LIMITE_ESPECIALIDAD", exception.getCode());
        assertEquals("El socio ya tiene el máximo de 2 consultas agendadas en esta especialidad",
                exception.getMessage());
    }

    @Test
    void conElValorPorDefectoUnaConsultaEnLaEspecialidadNoImpideLaDeOtra() {
        // contarConsultasAgendadasEnEspecialidad solo cuenta la especialidad 3: 0 deja pasar.
        when(repository.crear(SOCIO_ID, numero(false), null))
                .thenReturn(Optional.of(consultaEsperada(null)));

        assertEquals(9001L, service.agendar(SOCIO_ID, SOLICITUD).id());
    }

    @Test
    void rechazaHorariosSuperpuestosDelSocio() {
        when(repository.tieneConsultaSuperpuesta(
                SOCIO_ID,
                LocalDate.of(2026, 11, 3),
                LocalTime.of(9, 0),
                LocalTime.of(9, 20)
        )).thenReturn(true);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("CONSULTA_SUPERPUESTA", exception.getCode());
    }

    @Test
    void exigePaseCuandoEspecialidadLoRequiere() {
        when(repository.bloquearNumero(NUMERO_ID))
                .thenReturn(Optional.of(numero(true)));

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("PASE_NO_VALIDO", exception.getCode());
        verify(repository, never()).crear(SOCIO_ID, numero(true), null);
    }

    @Test
    void consumePasePropioVigenteYGuardaSuIdentificador() {
        CrearConsultaRequest solicitud = new CrearConsultaRequest(NUMERO_ID, 77L);
        when(repository.bloquearNumero(NUMERO_ID))
                .thenReturn(Optional.of(numero(true)));
        when(repository.bloquearPaseDisponible(
                77L,
                SOCIO_ID,
                3L,
                LocalDate.of(2026, 11, 3)
        )).thenReturn(Optional.of(
                new ConsultaRepository.PaseParaAgendar(
                        77L,
                        LocalDate.of(2027, 1, 31)
                )
        ));
        ConsultaDTO expected = consultaEsperada(77L);
        when(repository.crear(SOCIO_ID, numero(true), 77L))
                .thenReturn(Optional.of(expected));

        ConsultaDTO response = service.agendar(SOCIO_ID, solicitud);

        assertEquals(77L, response.paseId());
        verify(repository).bloquearPaseDisponible(
                77L, SOCIO_ID, 3L, LocalDate.of(2026, 11, 3)
        );
    }

    @Test
    void rechazaPaseAjenoVencidoOYaUtilizado() {
        CrearConsultaRequest solicitud = new CrearConsultaRequest(NUMERO_ID, 88L);
        when(repository.bloquearNumero(NUMERO_ID))
                .thenReturn(Optional.of(numero(true)));
        when(repository.bloquearPaseDisponible(
                88L, SOCIO_ID, 3L, LocalDate.of(2026, 11, 3)
        )).thenReturn(Optional.empty());

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, solicitud)
        );

        assertEquals("PASE_NO_VALIDO", exception.getCode());
        verify(repository, never()).crear(SOCIO_ID, numero(true), 88L);
    }

    @Test
    void rechazaPaseEnEspecialidadQueNoLoExige() {
        CrearConsultaRequest solicitud = new CrearConsultaRequest(NUMERO_ID, 77L);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, solicitud)
        );

        assertEquals("VALIDACION", exception.getCode());
        verify(repository, never()).bloquearPaseDisponible(
                77L, SOCIO_ID, 3L, LocalDate.of(2026, 11, 3)
        );
    }

    @Test
    void rechazaIdsInvalidosAntesDeConsultarRepositorio() {
        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(0L, SOLICITUD)
        );

        assertEquals("VALIDACION", exception.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaNumeroQueDejoDeEstarDisponible() {
        when(repository.crear(SOCIO_ID, numero(false), null))
                .thenReturn(Optional.empty());

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.agendar(SOCIO_ID, SOLICITUD)
        );

        assertEquals("NUMERO_NO_DISPONIBLE", exception.getCode());
        verify(repository, never()).crearNotificacionAgenda(9001L);
    }

    private NumeroParaAgendar numero(boolean requierePase) {
        return numero(requierePase, "ACTIVO", true);
    }

    private NumeroParaAgendar numero(
            boolean requierePase,
            String estado,
            boolean ventanaValida
    ) {
        return new NumeroParaAgendar(
                NUMERO_ID,
                2,
                LocalTime.of(9, 0),
                LocalTime.of(9, 20),
                301L,
                LocalDate.of(2026, 11, 3),
                estado,
                17L,
                "Marta",
                "Rodríguez",
                new Especialidad(3L, "Cardiología", requierePase),
                new Consultorio(5L, "Consultorio 5", "Piso 2"),
                true,
                ventanaValida
        );
    }

    private ConsultaDTO consultaEsperada(Long paseId) {
        return new ConsultaDTO(
                9001L,
                "AGENDADA",
                LocalDate.of(2026, 11, 3),
                2,
                "09:00",
                "09:20",
                new ConsultaDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                new Especialidad(3L, "Cardiología", false),
                new Consultorio(5L, "Consultorio 5", "Piso 2"),
                paseId,
                OffsetDateTime.parse("2026-10-21T15:00:00-03:00"),
                null,
                null
        );
    }
}
