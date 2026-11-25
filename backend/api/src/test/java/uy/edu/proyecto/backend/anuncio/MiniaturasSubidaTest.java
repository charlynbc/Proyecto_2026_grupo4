package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;

import static org.junit.jupiter.api.Assertions.assertArrayEquals;
import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doNothing;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * Al publicar y al editar se sube el original y, justo despues, su miniatura mini/uuid.jpg. Si la miniatura no se
 * puede generar o subir, la operacion sigue con solo el original. Si algo falla, se limpian las dos. En la cola de
 * borrado primero se borra el original y despues, de mejor esfuerzo, la miniatura.
 */
class MiniaturasSubidaTest {
    private static final OffsetDateTime FIN = OffsetDateTime.parse("2099-01-01T00:00:00Z");
    private static final String ORIGINAL_EN_COLA = "123e4567-e89b-12d3-a456-426614174000.png";
    private static final String MINIATURA_EN_COLA = "mini/123e4567-e89b-12d3-a456-426614174000.jpg";

    private final AnuncioRepository repository = mock(AnuncioRepository.class);
    private final AlmacenImagenes almacen = mock(AlmacenImagenes.class);
    private final AnuncioService anuncios = new AnuncioService(repository, almacen);
    private final CarteleraRepository repo = mock(CarteleraRepository.class);
    private final CarteleraService cartelera = new CarteleraService(repo, mock(AnuncioService.class), almacen);

    @AfterEach
    void cerrarSincronizacion() {
        if (TransactionSynchronizationManager.isSynchronizationActive()) {
            TransactionSynchronizationManager.clearSynchronization();
        }
    }

    private void publicacionPosible() {
        TransactionSynchronizationManager.initSynchronization();
        when(repository.crear(eq(7L), any())).thenReturn(42L);
        when(repository.buscarCualquiera(42L)).thenReturn(new AnuncioRepository.Fila(
                42, "Vacunación", null, "Texto", OffsetDateTime.parse("2026-11-03T12:00:00Z")));
        when(repository.imagenes(42L)).thenReturn(List.of());
    }

    private void publicar(MultipartFile... imagenes) {
        anuncios.publicar(7, new AnuncioDTO.Datos("Vacunación", null, "Texto", null, FIN), List.of(imagenes));
    }

    private static MockMultipartFile png(byte[] bytes) {
        return new MockMultipartFile("imagenes", "a.png", "image/png", bytes);
    }

    private static MockMultipartFile jpeg(byte[] bytes) {
        return new MockMultipartFile("imagenes", "b.jpg", "image/jpeg", bytes);
    }

    private static String sinExtension(String referencia) {
        return referencia.substring(0, referencia.lastIndexOf('.'));
    }

    private static void completar(int estado) {
        TransactionSynchronizationManager.getSynchronizations().forEach(s -> s.afterCompletion(estado));
    }

    // --- publicar ---

    @Test
    void publicarSubeCadaOriginalYDespuesSuMiniaturaJpegDe640() {
        publicacionPosible();
        byte[] a = ImagenesDePrueba.png(1000, 500);
        byte[] b = ImagenesDePrueba.jpeg(800, 400);

        publicar(png(a), jpeg(b));

        var referencias = ArgumentCaptor.forClass(String.class);
        var contenidos = ArgumentCaptor.forClass(byte[].class);
        var tipos = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(4)).guardar(referencias.capture(), contenidos.capture(), tipos.capture());
        var ref = referencias.getAllValues();
        var bytes = contenidos.getAllValues();
        var tipo = tipos.getAllValues();

        assertTrue(ref.get(0).endsWith(".png"));
        assertArrayEquals(a, bytes.get(0));
        assertEquals("image/png", tipo.get(0));
        assertEquals("mini/" + sinExtension(ref.get(0)) + ".jpg", ref.get(1));
        assertEquals("image/jpeg", tipo.get(1));
        assertEquals(640, ImagenesDePrueba.dimensiones(bytes.get(1)).width);
        assertEquals(320, ImagenesDePrueba.dimensiones(bytes.get(1)).height);

        assertTrue(ref.get(2).endsWith(".jpg"));
        assertArrayEquals(b, bytes.get(2));
        assertEquals("image/jpeg", tipo.get(2));
        assertEquals("mini/" + sinExtension(ref.get(2)) + ".jpg", ref.get(3));
        assertEquals("image/jpeg", tipo.get(3));
        assertEquals(640, ImagenesDePrueba.dimensiones(bytes.get(3)).width);
        assertEquals(320, ImagenesDePrueba.dimensiones(bytes.get(3)).height);

        // En la base solo figuran los originales; la miniatura se deriva del nombre.
        verify(repository).agregarImagen(42L, ref.get(0), 0);
        verify(repository).agregarImagen(42L, ref.get(2), 1);
        verify(repository, times(2)).agregarImagen(eq(42L), anyString(), anyInt());
        verify(almacen, never()).borrar(anyString());
    }

    @Test
    void siLaMiniaturaNoSePuedeGenerarSeSubeSoloElOriginalYTerminaBien() {
        publicacionPosible();
        byte[] cmyk = ImagenesDePrueba.jpegCmyk(40, 30);

        assertDoesNotThrow(() -> publicar(jpeg(cmyk)));

        var referencia = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(1)).guardar(referencia.capture(), eq(cmyk), eq("image/jpeg"));
        verify(repository).agregarImagen(42L, referencia.getValue(), 0);
        verify(almacen, never()).borrar(anyString());
    }

    @Test
    void siFallaLaSubidaDeLaMiniaturaLaPublicacionTerminaBienConElOriginal() {
        publicacionPosible();
        byte[] a = ImagenesDePrueba.png(1000, 500);
        // El original (image/png) sube bien; la miniatura (image/jpeg) falla.
        doThrow(new IllegalStateException("storage")).when(almacen).guardar(anyString(), any(), eq("image/jpeg"));

        assertDoesNotThrow(() -> publicar(png(a)));

        var referencia = ArgumentCaptor.forClass(String.class);
        verify(almacen).guardar(referencia.capture(), eq(a), eq("image/png"));
        verify(repository).agregarImagen(42L, referencia.getValue(), 0);
    }

    @Test
    void siLaBaseRevierteSeBorranLosOriginalesYLasMiniaturas() {
        publicacionPosible();
        when(repository.crear(eq(7L), any())).thenThrow(new IllegalStateException("db"));

        assertThrows(IllegalStateException.class,
                () -> publicar(png(ImagenesDePrueba.png(1000, 500)), jpeg(ImagenesDePrueba.jpeg(800, 400))));

        completar(TransactionSynchronization.STATUS_ROLLED_BACK);
        var referencias = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(4)).guardar(referencias.capture(), any(), anyString());
        var subidas = referencias.getAllValues();
        verify(almacen).borrar(subidas.get(0));
        verify(almacen).borrar(subidas.get(1));
        verify(almacen).borrar(subidas.get(2));
        verify(almacen).borrar(subidas.get(3));
        assertTrue(subidas.get(1).startsWith("mini/"));
        assertTrue(subidas.get(3).startsWith("mini/"));
    }

    @Test
    void siFallaUnOriginalSeBorranLosAnterioresConSuMiniaturaYNoSeBuscaLaMiniaturaDelQueFallo() {
        TransactionSynchronizationManager.initSynchronization();
        doNothing().doThrow(new IllegalStateException("storage"))
                .when(almacen).guardar(anyString(), any(), eq("image/png"));

        assertThrows(IllegalStateException.class,
                () -> publicar(png(ImagenesDePrueba.png(1000, 500)), png(ImagenesDePrueba.png(900, 450))));

        var referencias = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(3)).guardar(referencias.capture(), any(), anyString());
        var subidas = referencias.getAllValues();
        // Orden de subida: original 1, miniatura 1, original 2 (el que fallo).
        verify(almacen).borrar(subidas.get(0));
        verify(almacen).borrar(subidas.get(1));
        verify(almacen).borrar(subidas.get(2));
        verify(almacen, never()).borrar("mini/" + sinExtension(subidas.get(2)) + ".jpg");
    }

    // --- editar ---

    private void novedadConUnaImagen() {
        when(repo.existe(42)).thenReturn(true);
        when(repo.imagenes(42)).thenReturn(List.of(new CarteleraRepository.ImagenPropia(12, "a.png")));
    }

    private void editarConNueva(byte[] contenido, String tipo, String nombre) {
        var datos = new AnuncioDTO.Edicion("Título", null, "Texto", List.of(
                new AnuncioDTO.ImagenEdicion(12L, null), new AnuncioDTO.ImagenEdicion(null, "nueva1")));
        cartelera.editar(42, datos, Map.of("nueva1", new MockMultipartFile("nueva1", nombre, tipo, contenido)));
    }

    @Test
    void editarSubeElOriginalYSuMiniatura() {
        novedadConUnaImagen();
        byte[] original = ImagenesDePrueba.png(1280, 720);

        editarConNueva(original, "image/png", "a.png");

        var referencias = ArgumentCaptor.forClass(String.class);
        var contenidos = ArgumentCaptor.forClass(byte[].class);
        var tipos = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(2)).guardar(referencias.capture(), contenidos.capture(), tipos.capture());
        var ref = referencias.getAllValues();
        assertTrue(ref.get(0).endsWith(".png"));
        assertArrayEquals(original, contenidos.getAllValues().get(0));
        assertEquals("image/png", tipos.getAllValues().get(0));
        assertEquals("mini/" + sinExtension(ref.get(0)) + ".jpg", ref.get(1));
        assertEquals("image/jpeg", tipos.getAllValues().get(1));
        assertEquals(640, ImagenesDePrueba.dimensiones(contenidos.getAllValues().get(1)).width);
        assertEquals(360, ImagenesDePrueba.dimensiones(contenidos.getAllValues().get(1)).height);
        verify(repo).agregarImagen(42, ref.get(0), 1);
        verify(repo, times(1)).agregarImagen(anyLong(), anyString(), anyInt());
        verify(almacen, never()).borrar(anyString());
    }

    @Test
    void siLaMiniaturaNoSePuedeGenerarEditarSubeSoloElOriginalYTerminaBien() {
        novedadConUnaImagen();
        byte[] cmyk = ImagenesDePrueba.jpegCmyk(40, 30);

        assertDoesNotThrow(() -> editarConNueva(cmyk, "image/jpeg", "b.jpg"));

        var referencia = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(1)).guardar(referencia.capture(), eq(cmyk), eq("image/jpeg"));
        verify(repo).agregarImagen(42, referencia.getValue(), 1);
    }

    @Test
    void siFallaLaBaseAlEditarSeBorraElOriginalYLaMiniatura() {
        novedadConUnaImagen();
        doThrow(new IllegalStateException("db")).when(repo).agregarImagen(anyLong(), anyString(), anyInt());

        assertThrows(IllegalStateException.class,
                () -> editarConNueva(ImagenesDePrueba.png(1280, 720), "image/png", "a.png"));

        var referencias = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(2)).guardar(referencias.capture(), any(), anyString());
        var subidas = referencias.getAllValues();
        InOrder orden = inOrder(almacen);
        orden.verify(almacen).borrar(subidas.get(0));
        orden.verify(almacen).borrar("mini/" + sinExtension(subidas.get(0)) + ".jpg");
    }

    // --- cola de borrado ---

    @Test
    void laColaBorraElOriginalYDespuesIntentaLaMiniatura() {
        when(repo.tomarPendiente()).thenReturn(new CarteleraRepository.Pendiente(4, ORIGINAL_EN_COLA));

        cartelera.limpiarPendiente();

        InOrder orden = inOrder(almacen, repo);
        orden.verify(almacen).borrar(ORIGINAL_EN_COLA);
        orden.verify(almacen).borrar(MINIATURA_EN_COLA);
        orden.verify(repo).completado(4);
        verify(repo, never()).fallido(anyLong());
    }

    @Test
    void siFallaElBorradoDeLaMiniaturaElPendienteIgualQuedaResuelto() {
        when(repo.tomarPendiente()).thenReturn(new CarteleraRepository.Pendiente(4, ORIGINAL_EN_COLA));
        doThrow(new IllegalStateException("storage")).when(almacen).borrar(MINIATURA_EN_COLA);

        assertDoesNotThrow(() -> cartelera.limpiarPendiente());

        verify(repo).completado(4);
        verify(repo, never()).fallido(anyLong());
        // Sin reintentos: una sola vez.
        verify(almacen, times(1)).borrar(MINIATURA_EN_COLA);
    }

    @Test
    void siFallaElBorradoDelOriginalNoSeTocaLaMiniaturaYElPendienteQuedaParaReintentar() {
        when(repo.tomarPendiente()).thenReturn(new CarteleraRepository.Pendiente(4, ORIGINAL_EN_COLA));
        doThrow(new IllegalStateException("storage")).when(almacen).borrar(ORIGINAL_EN_COLA);

        cartelera.limpiarPendiente();

        verify(repo).fallido(4);
        verify(repo, never()).completado(anyLong());
        verify(almacen, never()).borrar(MINIATURA_EN_COLA);
    }
}
