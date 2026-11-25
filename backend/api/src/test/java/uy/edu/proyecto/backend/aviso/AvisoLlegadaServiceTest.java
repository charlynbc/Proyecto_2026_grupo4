package uy.edu.proyecto.backend.aviso;

import java.time.Clock;
import java.time.Instant;
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

import uy.edu.proyecto.backend.agenda.ConsultaDTO;
import uy.edu.proyecto.backend.aviso.AvisoLlegadaRepository.Funcionario;
import uy.edu.proyecto.backend.aviso.AvisoLlegadaRepository.Socio;
import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.ParametrosDePrueba;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AvisoLlegadaServiceTest {

    private static final LocalDate HOY = LocalDate.of(2026, 10, 21);
    private static final String CI_SOCIO = "67890127";

    @Mock
    private AvisoLlegadaRepository repository;

    private AvisoLlegadaService service;

    @BeforeEach
    void setUp() {
        Clock clock = Clock.fixed(
                Instant.parse("2026-10-21T15:00:00Z"),
                ZoneId.of("America/Montevideo")
        );
        service = new AvisoLlegadaService(repository, clock, ParametroService.porDefecto());
        lenient().when(repository.buscarFuncionarioActivo(31L))
                .thenReturn(Optional.of(new Funcionario(
                        31L, "12345678", "Pablo", "Gómez"
                )));
        lenient().when(repository.bloquearSocioHabilitado(CI_SOCIO))
                .thenReturn(Optional.of(new Socio(
                        91L, CI_SOCIO, "Lucía", "Fernández"
                )));
    }

    @Test
    void registraLlegadaSoloCuandoTieneConsultaAgendadaHoy() {
        AvisoLlegadaDTO aviso = avisoOriginal();
        when(repository.buscarAviso(91L, HOY)).thenReturn(Optional.empty());
        when(repository.socioTieneConsultaAgendadaHoy(91L, HOY))
                .thenReturn(true);
        when(repository.crearSiNoExiste(
                new Socio(91L, CI_SOCIO, "Lucía", "Fernández"),
                new Funcionario(31L, "12345678", "Pablo", "Gómez"),
                HOY
        )).thenReturn(Optional.of(aviso));

        ResultadoAvisoLlegada resultado = service.registrar(CI_SOCIO, 31L);

        assertEquals(aviso, resultado.aviso());
        assertTrue(resultado.creado());
    }

    @Test
    void duplicateReturnsOriginalFuncionarioAndTimestampWithoutModifying() {
        AvisoLlegadaDTO original = avisoOriginal();
        when(repository.buscarAviso(91L, HOY)).thenReturn(Optional.of(original));

        ResultadoAvisoLlegada resultado = service.registrar(CI_SOCIO, 31L);

        assertEquals(original, resultado.aviso());
        assertFalse(resultado.creado());
        verify(repository, never()).socioTieneConsultaAgendadaHoy(91L, HOY);
        verify(repository, never()).crearSiNoExiste(
                new Socio(91L, CI_SOCIO, "Lucía", "Fernández"),
                new Funcionario(31L, "12345678", "Pablo", "Gómez"),
                HOY
        );
    }

    @Test
    void noRegistraSiNoHayConsultaAgendadaHoy() {
        when(repository.buscarAviso(91L, HOY)).thenReturn(Optional.empty());
        when(repository.socioTieneConsultaAgendadaHoy(91L, HOY))
                .thenReturn(false);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.registrar(CI_SOCIO, 31L)
        );

        assertEquals("SIN_CONSULTAS_AGENDADAS", exception.getCode());
        verify(repository, never()).crearSiNoExiste(
                new Socio(91L, CI_SOCIO, "Lucía", "Fernández"),
                new Funcionario(31L, "12345678", "Pablo", "Gómez"),
                HOY
        );
    }

    @Test
    void rejectsFuncionarioRegisteringOwnSocioArrival() {
        when(repository.buscarFuncionarioActivo(31L))
                .thenReturn(Optional.of(new Funcionario(
                        31L, CI_SOCIO, "Lucía", "Fernández"
                )));

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.registrar(CI_SOCIO, 31L)
        );

        assertEquals("CONFLICTO_INTERES", exception.getCode());
        verify(repository, never()).buscarAviso(91L, HOY);
    }

    @Test
    void reusesOriginalIfUniqueConstraintWinsConcurrentInsert() {
        AvisoLlegadaDTO original = avisoOriginal();
        when(repository.buscarAviso(91L, HOY))
                .thenReturn(Optional.empty(), Optional.of(original));
        when(repository.socioTieneConsultaAgendadaHoy(91L, HOY))
                .thenReturn(true);
        when(repository.crearSiNoExiste(
                new Socio(91L, CI_SOCIO, "Lucía", "Fernández"),
                new Funcionario(31L, "12345678", "Pablo", "Gómez"),
                HOY
        )).thenReturn(Optional.empty());

        ResultadoAvisoLlegada resultado = service.registrar(CI_SOCIO, 31L);

        assertEquals(original, resultado.aviso());
        assertFalse(resultado.creado());
        verify(repository, times(2)).buscarAviso(91L, HOY);
    }

    @Test
    void usaFechaDelServidorParaConsultaHoyYNormalizaCi() {
        when(repository.buscarSocioHabilitado(CI_SOCIO))
                .thenReturn(Optional.of(new Socio(
                        91L, CI_SOCIO, "Lucía", "Fernández"
                )));
        when(repository.listarConsultasAgendadas(CI_SOCIO, HOY))
                .thenReturn(List.of());

        assertTrue(service.consultasDeHoy("67.890.127").items().isEmpty());
        verify(repository).buscarSocioHabilitado(CI_SOCIO);
        verify(repository).listarConsultasAgendadas(CI_SOCIO, HOY);
    }

    @Test
    void sinLlegadaDeHoyLaRespuestaTraeLlegadaNula() {
        when(repository.buscarSocioHabilitado(CI_SOCIO))
                .thenReturn(Optional.of(new Socio(
                        91L, CI_SOCIO, "Lucía", "Fernández"
                )));
        when(repository.listarConsultasAgendadas(CI_SOCIO, HOY))
                .thenReturn(List.of(consultaAgendada()));
        when(repository.buscarAviso(91L, HOY)).thenReturn(Optional.empty());

        ConsultasDeHoyDTO respuesta = service.consultasDeHoy(CI_SOCIO);

        assertEquals(List.of(consultaAgendada()), respuesta.items());
        assertNull(respuesta.llegada());
    }

    @Test
    void conLlegadaDeHoyLaRespuestaTraeLaHoraYQuienLaRegistro() {
        when(repository.buscarSocioHabilitado(CI_SOCIO))
                .thenReturn(Optional.of(new Socio(
                        91L, CI_SOCIO, "Lucía", "Fernández"
                )));
        when(repository.listarConsultasAgendadas(CI_SOCIO, HOY))
                .thenReturn(List.of(consultaAgendada()));
        when(repository.buscarAviso(91L, HOY))
                .thenReturn(Optional.of(avisoOriginal()));

        ConsultasDeHoyDTO respuesta = service.consultasDeHoy(CI_SOCIO);

        assertEquals(List.of(consultaAgendada()), respuesta.items());
        assertEquals(
                new LlegadaDeHoyDTO(
                        OffsetDateTime.parse("2026-10-21T08:55:12-03:00"),
                        new AvisoLlegadaDTO.FuncionarioRef(31L, "Pablo", "Gómez")
                ),
                respuesta.llegada()
        );
    }

    @Test
    void conLlegadaPeroSinConsultasAgendadasHoyIgualDevuelveLaLlegada() {
        when(repository.buscarSocioHabilitado(CI_SOCIO))
                .thenReturn(Optional.of(new Socio(
                        91L, CI_SOCIO, "Lucía", "Fernández"
                )));
        when(repository.listarConsultasAgendadas(CI_SOCIO, HOY))
                .thenReturn(List.of());
        when(repository.buscarAviso(91L, HOY))
                .thenReturn(Optional.of(avisoOriginal()));

        ConsultasDeHoyDTO respuesta = service.consultasDeHoy(CI_SOCIO);

        assertTrue(respuesta.items().isEmpty());
        assertEquals(
                OffsetDateTime.parse("2026-10-21T08:55:12-03:00"),
                respuesta.llegada().registradaEn()
        );
        assertEquals("Pablo", respuesta.llegada().registradaPor().nombre());
    }

    // --- cancelable en las consultas de hoy: ahora es 2026-10-21 12:00 en Montevideo ---

    private ConsultaDTO consultaDeHoyA(long id, String hora) {
        return new ConsultaDTO(
                id, "AGENDADA", HOY, 2, hora, "23:00",
                new ConsultaDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                new Especialidad(3L, "Cardiología", true),
                new Consultorio(5L, "Consultorio 5", "Piso 2"),
                null,
                OffsetDateTime.parse("2026-10-14T10:12:45-03:00"),
                null, null, false);
    }

    private void socioConConsultasDeHoy(boolean conLlegada, ConsultaDTO... consultas) {
        when(repository.buscarSocioHabilitado(CI_SOCIO))
                .thenReturn(Optional.of(new Socio(91L, CI_SOCIO, "Lucía", "Fernández")));
        when(repository.listarConsultasAgendadas(CI_SOCIO, HOY)).thenReturn(List.of(consultas));
        when(repository.buscarAviso(91L, HOY)).thenReturn(
                conLlegada ? Optional.of(avisoOriginal()) : Optional.empty());
    }

    @Test
    void sinLlegadaCadaConsultaDeHoyEsCancelableSegunElPlazo() {
        socioConConsultasDeHoy(false,
                consultaDeHoyA(9001, "15:00"),
                consultaDeHoyA(9002, "14:00"),
                consultaDeHoyA(9003, "13:59"),
                consultaDeHoyA(9004, "09:00"));

        List<ConsultaDTO> items = service.consultasDeHoy(CI_SOCIO).items();

        assertEquals(List.of(true, true, false, false),
                items.stream().map(ConsultaDTO::cancelable).toList());
        assertEquals(consultaDeHoyA(9001, "15:00").conCancelable(true), items.get(0));
    }

    @Test
    void conLlegadaDeHoyNingunaConsultaEsCancelableAunqueFalteMucho() {
        socioConConsultasDeHoy(true,
                consultaDeHoyA(9001, "15:00"),
                consultaDeHoyA(9002, "20:00"));

        ConsultasDeHoyDTO respuesta = service.consultasDeHoy(CI_SOCIO);

        assertEquals(List.of(false, false),
                respuesta.items().stream().map(ConsultaDTO::cancelable).toList());
        assertEquals(
                new LlegadaDeHoyDTO(
                        OffsetDateTime.parse("2026-10-21T08:55:12-03:00"),
                        new AvisoLlegadaDTO.FuncionarioRef(31L, "Pablo", "Gómez")),
                respuesta.llegada());
    }

    @Test
    void consultasDeHoyUsaLasHorasMinimasDelParametro() {
        AvisoLlegadaService con5Horas = new AvisoLlegadaService(repository,
                Clock.fixed(Instant.parse("2026-10-21T15:00:00Z"), ZoneId.of("America/Montevideo")),
                ParametrosDePrueba.nuevo().cancelarHoras(5).construir());
        socioConConsultasDeHoy(false,
                consultaDeHoyA(9001, "17:00"),
                consultaDeHoyA(9002, "16:59"));

        List<ConsultaDTO> items = con5Horas.consultasDeHoy(CI_SOCIO).items();

        assertEquals(List.of(true, false), items.stream().map(ConsultaDTO::cancelable).toList());
    }

    @Test
    void rejectsInvalidCiAndUnknownSocioOrFuncionario() {
        ApiException ciException = assertThrows(
                ApiException.class,
                () -> service.registrar("123", 31L)
        );
        assertEquals("VALIDACION", ciException.getCode());

        when(repository.buscarFuncionarioActivo(32L)).thenReturn(Optional.empty());
        ApiException funcionarioException = assertThrows(
                ApiException.class,
                () -> service.registrar(CI_SOCIO, 32L)
        );
        assertEquals("NO_ENCONTRADO", funcionarioException.getCode());

        when(repository.buscarSocioHabilitado(CI_SOCIO)).thenReturn(Optional.empty());
        ApiException socioException = assertThrows(
                ApiException.class,
                () -> service.consultasDeHoy(CI_SOCIO)
        );
        assertEquals("NO_ENCONTRADO", socioException.getCode());
    }

    private ConsultaDTO consultaAgendada() {
        return new ConsultaDTO(
                9001L,
                "AGENDADA",
                HOY,
                2,
                "09:20",
                "09:40",
                new ConsultaDTO.MedicoRef(17L, "Marta", "Rodríguez"),
                new Especialidad(3L, "Cardiología", true),
                new Consultorio(5L, "Consultorio 5", "Piso 2"),
                77L,
                OffsetDateTime.parse("2026-10-14T10:12:45-03:00"),
                null,
                null,
                false
        );
    }

    private AvisoLlegadaDTO avisoOriginal() {
        return new AvisoLlegadaDTO(
                7001L,
                new AvisoLlegadaDTO.SocioRef(
                        CI_SOCIO, "Lucía", "Fernández"
                ),
                HOY,
                OffsetDateTime.parse("2026-10-21T08:55:12-03:00"),
                new AvisoLlegadaDTO.FuncionarioRef(
                        31L, "Pablo", "Gómez"
                )
        );
    }
}
