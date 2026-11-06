package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.Base64;
import java.util.List;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class AnuncioServiceTest {
    private static final byte[] PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l5sAAAAASUVORK5CYII=");
    private final AnuncioRepository repository = mock(AnuncioRepository.class);
    private final AlmacenImagenes almacen = mock(AlmacenImagenes.class);
    private final AnuncioService service = new AnuncioService(repository, almacen);

    @AfterEach
    void cerrarSincronizacion() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    @Test
    void exigeTituloYContenidoAntesDeGuardar() {
        var sinContenido = assertThrows(ApiException.class,
                () -> service.publicar(7, new AnuncioDTO.Datos("Vacunación", "Resumen", " \t "), List.of()));
        assertEquals("VALIDACION", sinContenido.getCode());

        var sinTitulo = assertThrows(ApiException.class,
                () -> service.publicar(7, new AnuncioDTO.Datos("  ", null, null), List.of(png())));
        assertEquals("VALIDACION", sinTitulo.getCode());
        verifyNoInteractions(repository, almacen);
    }

    @Test
    void rechazaArchivoQueNoEsImagenAunqueDeclarePng() {
        var falso = new MockMultipartFile("imagenes", "falso.png", "image/png",
                "no es una imagen".getBytes(java.nio.charset.StandardCharsets.UTF_8));

        var error = assertThrows(ApiException.class, () -> service.publicar(7,
                new AnuncioDTO.Datos("Vacunación", null, null), List.of(falso)));

        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository, almacen);
    }

    @Test
    void publicaConPortadaYDetalleEnOrden() {
        TransactionSynchronizationManager.initSynchronization();
        when(repository.crear(eq(7L), any())).thenReturn(42L);
        when(repository.buscar(42L)).thenReturn(new AnuncioRepository.Fila(
                42, "Vacunación", null, "Texto", OffsetDateTime.parse("2026-11-03T12:00:00Z")));
        when(repository.imagenes(42L)).thenAnswer(invocacion -> List.of(
                new AnuncioRepository.ImagenFila(1, 0, "primera.png"),
                new AnuncioRepository.ImagenFila(2, 1, "segunda.png")));
        when(almacen.enlaceTemporal("primera.png")).thenReturn("https://example.test/primera");
        when(almacen.enlaceTemporal("segunda.png")).thenReturn("https://example.test/segunda");

        var detalle = service.publicar(7,
                new AnuncioDTO.Datos(" Vacunación ", null, "Texto"), List.of(png(), png()));

        assertEquals(42, detalle.id());
        assertEquals(2, detalle.imagenes().size());
        assertEquals(0, detalle.imagenes().getFirst().orden());
        assertEquals("https://example.test/primera", detalle.imagenes().getFirst().url());
        verify(repository).crear(7L, new AnuncioDTO.Datos("Vacunación", null, "Texto"));
        verify(repository).agregarImagen(eq(42L), any(), eq(0));
        verify(repository).agregarImagen(eq(42L), any(), eq(1));
    }

    @Test
    void fallaSiStorageFallaSinPersistirAnuncio() {
        TransactionSynchronizationManager.initSynchronization();
        doThrow(new IllegalStateException("storage")).when(almacen).guardar(any(), any(), eq("image/png"));

        assertThrows(IllegalStateException.class, () -> service.publicar(7,
                new AnuncioDTO.Datos("Vacunación", null, null), List.of(png())));

        verifyNoInteractions(repository);
        verify(almacen).borrar(any());
    }

    @Test
    void borraImagenesSiLaBaseRevierte() {
        TransactionSynchronizationManager.initSynchronization();
        when(repository.crear(eq(7L), any())).thenThrow(new IllegalStateException("db"));

        assertThrows(IllegalStateException.class, () -> service.publicar(7,
                new AnuncioDTO.Datos("Vacunación", null, null), List.of(png())));

        completar(TransactionSynchronization.STATUS_ROLLED_BACK);
        verify(almacen).borrar(any());
    }

    @Test
    void listaPaginadaConPrimeraImagenComoPortada() {
        when(repository.listar(0, 5)).thenReturn(List.of(new AnuncioRepository.Fila(
                42, "Vacunación", "Resumen", null, OffsetDateTime.parse("2026-11-03T12:00:00Z"))));
        when(repository.imagenes(42)).thenReturn(List.of(new AnuncioRepository.ImagenFila(1, 0, "portada.png")));
        when(almacen.enlaceTemporal("portada.png")).thenReturn("https://example.test/portada");
        when(repository.total()).thenReturn(1L);

        var pagina = service.listar(0, 5);

        assertEquals(1, pagina.total());
        assertEquals(5, pagina.size());
        assertEquals("https://example.test/portada", pagina.items().getFirst().imagenPortada().url());
        assertTrue(pagina.items().getFirst().titulo().contains("Vacunación"));
    }

    private static MockMultipartFile png() {
        return new MockMultipartFile("imagenes", "imagen.png", "image/png", PNG);
    }

    private static void completar(int estado) {
        TransactionSynchronizationManager.getSynchronizations().forEach(s -> s.afterCompletion(estado));
    }
}
