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
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
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
        service = new AvisoLlegadaService(repository, clock);
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

        assertTrue(service.consultasDeHoy("67.890.127").isEmpty());
        verify(repository).buscarSocioHabilitado(CI_SOCIO);
        verify(repository).listarConsultasAgendadas(CI_SOCIO, HOY);
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
