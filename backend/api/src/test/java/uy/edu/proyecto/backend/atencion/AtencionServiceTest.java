package uy.edu.proyecto.backend.atencion;

import java.time.Clock;
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

import uy.edu.proyecto.backend.atencion.AtencionRepository.ConsultaResultado;
import uy.edu.proyecto.backend.atencion.ResultadoConsultaRequest.PaseNuevoRequest;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.lenient;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class AtencionServiceTest {

    private static final Long MEDICO_ID = 17L;
    private static final Long CONSULTA_ID = 9001L;
    private static final Long SOCIO_ID = 91L;
    private static final LocalDate HOY = LocalDate.of(2026, 10, 20);
    private static final OffsetDateTime AHORA =
            OffsetDateTime.parse("2026-10-20T09:41:00-03:00");
    private static final Clock RELOJ = Clock.fixed(
            AHORA.toInstant(),
            ZoneId.of("America/Montevideo")
    );

    @Mock
    private AtencionRepository repository;

    private AtencionService service;

    @BeforeEach
    void setUp() {
        service = new AtencionService(repository, RELOJ);
        lenient().when(repository.buscarSocioId(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(SOCIO_ID));
        lenient().when(repository.bloquearSocio(SOCIO_ID)).thenReturn(true);
        lenient().when(repository.bloquearConsulta(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(consulta("AGENDADA", HOY)));
        lenient().when(repository.existeAvisoLlegada(SOCIO_ID, HOY))
                .thenReturn(true);
    }

    @Test
    void noSePresentoGuardaResultadoDefinitivoSinAtencionNiPases() {
        when(repository.registrarNoPresentacion(
                CONSULTA_ID,
                MEDICO_ID,
                AHORA
        )).thenReturn(true);

        ResultadoConsultaResponse response = service.registrarResultado(
                MEDICO_ID,
                CONSULTA_ID,
                new ResultadoConsultaRequest("NO_SE_PRESENTO", null, null, null, null)
        );

        assertEquals("NO_SE_PRESENTO", response.estado());
        assertNull(response.atencionId());
        assertEquals(List.of(), response.pases());
        verify(repository).registrarNoPresentacion(CONSULTA_ID, MEDICO_ID, AHORA);
        verify(repository, never()).crearAtencion(
                any(), any(), any(), any(), any(), any()
        );
        verify(repository, never()).crearNotificacionHistoriaActualizada(any());
    }

    @Test
    void atendidaGuardaAtencionPaseResultadoYNotificacion() {
        Especialidad destino = new Especialidad(4L, "Nutrición", true);
        when(repository.buscarEspecialidad(4L)).thenReturn(Optional.of(destino));
        when(repository.tienePaseVigenteOConsultaAgendada(
                SOCIO_ID,
                4L,
                CONSULTA_ID,
                HOY
        )).thenReturn(false);
        when(repository.crearAtencion(
                CONSULTA_ID,
                MEDICO_ID,
                "Hipertensión arterial leve",
                "Control de dieta",
                null,
                AHORA
        )).thenReturn(5530L);
        when(repository.crearPase(5530L, destino, AHORA, HOY.plusDays(90)))
                .thenReturn(78L);
        when(repository.registrarAtendida(
                CONSULTA_ID,
                MEDICO_ID,
                AHORA
        )).thenReturn(true);

        ResultadoConsultaResponse response = service.registrarResultado(
                MEDICO_ID,
                CONSULTA_ID,
                new ResultadoConsultaRequest(
                        "ATENDIDA",
                        " Hipertensión arterial leve ",
                        "Control de dieta",
                        " ",
                        List.of(new PaseNuevoRequest(4L, null))
                )
        );

        assertEquals("ATENDIDA", response.estado());
        assertEquals(5530L, response.atencionId());
        assertEquals(AHORA, response.registradoEn());
        assertEquals(1, response.pases().size());
        assertEquals(78L, response.pases().getFirst().id());
        assertEquals(destino, response.pases().getFirst().especialidadDestino());
        assertEquals(HOY.plusDays(90), response.pases().getFirst().venceEl());
        verify(repository).registrarAtendida(CONSULTA_ID, MEDICO_ID, AHORA);
        verify(repository).crearNotificacionHistoriaActualizada(CONSULTA_ID);
    }

    @Test
    void rechazaResultadoClinicoSinAfeccionAntesDeConsultar() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest(
                                "ATENDIDA", " ", null, null, null
                        )
                )
        );

        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void noPresentacionNoAdmiteCamposClinicosNiPases() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest(
                                "NO_SE_PRESENTO",
                                null,
                                null,
                                null,
                                List.of()
                        )
                )
        );

        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaPasesDuplicadosEnLaMismaSolicitud() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest(
                                "ATENDIDA",
                                "Control",
                                null,
                                null,
                                List.of(
                                        new PaseNuevoRequest(4L, 30),
                                        new PaseNuevoRequest(4L, 60)
                                )
                        )
                )
        );

        assertEquals("VALIDACION", error.getCode());
        verify(repository, never()).crearAtencion(
                any(), any(), any(), any(), any(), any()
        );
    }

    @Test
    void rechazaPaseDuplicadoVigenteSinGuardarAtencion() {
        when(repository.buscarEspecialidad(4L)).thenReturn(
                Optional.of(new Especialidad(4L, "Nutrición", true))
        );
        when(repository.tienePaseVigenteOConsultaAgendada(
                SOCIO_ID, 4L, CONSULTA_ID, HOY
        )).thenReturn(true);

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest(
                                "ATENDIDA",
                                "Control",
                                null,
                                null,
                                List.of(new PaseNuevoRequest(4L, 90))
                        )
                )
        );

        assertEquals("PASE_DUPLICADO", error.getCode());
        verify(repository, never()).crearAtencion(
                any(), any(), any(), any(), any(), any()
        );
    }

    @Test
    void rechazaMedicoPropioSocioConsultaYSinAviso() {
        when(repository.bloquearConsulta(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(new ConsultaResultado(
                        CONSULTA_ID,
                        SOCIO_ID,
                        "AGENDADA",
                        HOY,
                        "12345678",
                        "12345678"
                )));

        ApiException conflicto = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest("NO_SE_PRESENTO", null, null, null, null)
                )
        );
        assertEquals("CONFLICTO_DE_INTERES", conflicto.getCode());

        when(repository.bloquearConsulta(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(consulta("AGENDADA", HOY)));
        when(repository.existeAvisoLlegada(SOCIO_ID, HOY)).thenReturn(false);
        ApiException sinAviso = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest("NO_SE_PRESENTO", null, null, null, null)
                )
        );
        assertEquals("SIN_AVISO_LLEGADA", sinAviso.getCode());
        verify(repository, never()).registrarNoPresentacion(any(), any(), any());
    }

    @Test
    void exigeConsultaDeHoyYEstadoAgendada() {
        when(repository.bloquearConsulta(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(consulta(
                        "CANCELADA_SOCIO",
                        HOY
                )));
        ApiException noAgendada = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest("NO_SE_PRESENTO", null, null, null, null)
                )
        );
        assertEquals("CONSULTA_NO_AGENDADA", noAgendada.getCode());

        when(repository.bloquearConsulta(MEDICO_ID, CONSULTA_ID))
                .thenReturn(Optional.of(consulta(
                        "AGENDADA",
                        HOY.minusDays(1)
                )));
        ApiException otraFecha = assertThrows(
                ApiException.class,
                () -> service.registrarResultado(
                        MEDICO_ID,
                        CONSULTA_ID,
                        new ResultadoConsultaRequest("NO_SE_PRESENTO", null, null, null, null)
                )
        );
        assertEquals("CONSULTA_NO_ES_DE_HOY", otraFecha.getCode());
    }

    private ConsultaResultado consulta(String estado, LocalDate fecha) {
        return new ConsultaResultado(
                CONSULTA_ID,
                SOCIO_ID,
                estado,
                fecha,
                "34567894",
                "23456789"
        );
    }
}
