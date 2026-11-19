package uy.edu.proyecto.backend.notificacion;

import java.time.Clock;
import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.util.List;
import org.junit.jupiter.api.Test;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** GET /api/notificaciones: la lista de avisos del socio, con el repositorio simulado y un reloj fijo. */
class NotificacionServiceTest {
    // 15:00 UTC es 12:00 en Uruguay (-03:00).
    private static final Clock RELOJ = Clock.fixed(Instant.parse("2026-11-17T15:00:00Z"),
            ZoneId.of("America/Montevideo"));
    private static final OffsetDateTime AHORA = OffsetDateTime.parse("2026-11-17T12:00:00-03:00");

    private final NotificacionRepository repository = mock(NotificacionRepository.class);
    private final NotificacionService service = new NotificacionService(repository, RELOJ);

    private static NotificacionRepository.Fila fila(long id, String tipo, String creadaEn, long consulta) {
        return new NotificacionRepository.Fila(id, tipo, "Contenido " + id, OffsetDateTime.parse(creadaEn), consulta);
    }

    private ApiException rechaza(Long socio, String page, String size) {
        return assertThrows(ApiException.class, () -> service.listar(socio, page, size));
    }

    @Test
    void sinParametrosPideLaPrimeraPaginaDe20() {
        when(repository.listar(7L, AHORA, 0, 20)).thenReturn(List.of());
        when(repository.total(7L, AHORA)).thenReturn(0L);

        var respuesta = service.listar(7L, null, null);

        assertEquals(0, respuesta.page());
        assertEquals(20, respuesta.size());
        assertEquals(0L, respuesta.total());
        assertEquals(List.of(), respuesta.items());
        verify(repository).listar(7L, AHORA, 0, 20);
    }

    @Test
    void unParametroEnBlancoEsElValorPorDefecto() {
        when(repository.total(7L, AHORA)).thenReturn(0L);

        var respuesta = service.listar(7L, "  ", "");

        assertEquals(0, respuesta.page());
        assertEquals(20, respuesta.size());
    }

    @Test
    void usaLaPaginaYElTamanoPedidos() {
        when(repository.listar(7L, AHORA, 2, 5)).thenReturn(List.of());
        when(repository.total(7L, AHORA)).thenReturn(42L);

        var respuesta = service.listar(7L, "2", "5");

        assertEquals(2, respuesta.page());
        assertEquals(5, respuesta.size());
        assertEquals(42L, respuesta.total());
        verify(repository).listar(7L, AHORA, 2, 5);
    }

    @Test
    void elSocioDelTokenVaALaListaYAlConteo() {
        service.listar(31L, "0", "20");

        verify(repository).listar(31L, AHORA, 0, 20);
        verify(repository).total(31L, AHORA);
    }

    @Test
    void sizeAdmiteDe1A100() {
        service.listar(7L, "0", "1");
        service.listar(7L, "0", "100");

        verify(repository).listar(7L, AHORA, 0, 1);
        verify(repository).listar(7L, AHORA, 0, 100);
    }

    @Test
    void sizeFueraDeRangoOInvalidoEs400ConMensajeClaro() {
        for (String size : new String[] {"0", "101", "-1", "abc", "1.5", "1000000000000"}) {
            var error = rechaza(7L, null, size);
            assertEquals("VALIDACION", error.getCode(), size);
            assertEquals(400, error.getStatus().value(), size);
            assertEquals("size debe estar entre 1 y 100", error.getMessage(), size);
        }
        verifyNoInteractions(repository);
    }

    @Test
    void pageNegativaONoNumericaEs400ConMensajeClaro() {
        for (String page : new String[] {"-1", "x", "1.5", "99999999999"}) {
            var error = rechaza(7L, page, null);
            assertEquals("VALIDACION", error.getCode(), page);
            assertEquals(400, error.getStatus().value(), page);
            assertEquals("page debe ser un entero mayor o igual a 0", error.getMessage(), page);
        }
        verifyNoInteractions(repository);
    }

    @Test
    void sinSocioEs400SinConsultarLaBase() {
        for (Long socio : new Long[] {null, 0L, -4L}) {
            assertEquals("VALIDACION", rechaza(socio, null, null).getCode());
        }
        verifyNoInteractions(repository);
    }

    @Test
    void elTituloSaleDeNotificacionTextosSegunElTipo() {
        when(repository.listar(7L, AHORA, 0, 20)).thenReturn(List.of(
                fila(5, "AGENDA", "2026-11-17T09:00:00-03:00", 100),
                fila(4, "CANCELACION", "2026-11-17T08:00:00-03:00", 100),
                fila(3, "SUSPENSION", "2026-11-17T07:00:00-03:00", 101),
                fila(2, "HISTORIA_ACTUALIZADA", "2026-11-17T06:00:00-03:00", 102),
                fila(1, "RECORDATORIO", "2026-11-17T05:00:00-03:00", 103)));
        when(repository.total(7L, AHORA)).thenReturn(5L);

        var items = service.listar(7L, null, null).items();

        assertEquals(List.of("Consulta agendada", "Consulta cancelada", "Turno suspendido",
                "Historia clínica actualizada", "Recordatorio de consulta"),
                items.stream().map(NotificacionDTO::titulo).toList());
        assertEquals(List.of("AGENDA", "CANCELACION", "SUSPENSION", "HISTORIA_ACTUALIZADA", "RECORDATORIO"),
                items.stream().map(NotificacionDTO::tipo).toList());
    }

    @Test
    void unTipoDesconocidoLlevaElTituloGenerico() {
        when(repository.listar(7L, AHORA, 0, 20)).thenReturn(List.of(
                fila(9, "OTRO", "2026-11-17T09:00:00-03:00", 100)));
        when(repository.total(7L, AHORA)).thenReturn(1L);

        assertEquals("Aviso de tu consulta", service.listar(7L, null, null).items().getFirst().titulo());
    }

    @Test
    void cadaItemLlevaLosCamposDelContratoYConservaElOrdenDelRepositorio() {
        when(repository.listar(7L, AHORA, 0, 20)).thenReturn(List.of(
                fila(15002, "CANCELACION", "2026-10-16T14:20:00Z", 9002),
                fila(15001, "SUSPENSION", "2026-10-16T11:20:00-03:00", 9001)));
        when(repository.total(7L, AHORA)).thenReturn(2L);

        var items = service.listar(7L, null, null).items();

        assertEquals(2, items.size());
        assertEquals(15002L, items.get(0).id());
        assertEquals("Contenido 15002", items.get(0).contenido());
        assertEquals(9002L, items.get(0).consultaId());
        assertEquals(15001L, items.get(1).id());
        assertEquals(9001L, items.get(1).consultaId());
    }

    @Test
    void creadaEnVaConLaHoraDeUruguay() {
        // 14:20 UTC es 11:20 en Uruguay: el mismo instante con desfase -03:00.
        when(repository.listar(7L, AHORA, 0, 20)).thenReturn(List.of(
                fila(1, "AGENDA", "2026-10-16T14:20:00Z", 100)));
        when(repository.total(7L, AHORA)).thenReturn(1L);

        var creadaEn = service.listar(7L, null, null).items().getFirst().creadaEn();

        assertEquals(OffsetDateTime.parse("2026-10-16T11:20:00-03:00"), creadaEn);
        assertEquals("-03:00", creadaEn.getOffset().toString());
    }

    @Test
    void elRelojDelServidorEsElAhoraDeLosRecordatorios() {
        service.listar(7L, null, null);

        verify(repository).listar(anyLong(), org.mockito.ArgumentMatchers.eq(AHORA), anyInt(), anyInt());
        verify(repository).total(anyLong(), org.mockito.ArgumentMatchers.eq(AHORA));
        // Una pagina grande no se pasa del tipo int.
        service.listar(7L, "2147483647", "100");
        verify(repository).listar(7L, AHORA, Integer.MAX_VALUE, 100);
    }

    @Test
    void conUnaListaVaciaDevuelveItemsVaciosYTotalCero() {
        when(repository.listar(any(Long.class), any(), anyInt(), anyInt())).thenReturn(List.of());

        var respuesta = service.listar(7L, "3", "10");

        assertEquals(List.of(), respuesta.items());
        assertEquals(0L, respuesta.total());
        assertEquals(3, respuesta.page());
        assertEquals(10, respuesta.size());
    }
}
