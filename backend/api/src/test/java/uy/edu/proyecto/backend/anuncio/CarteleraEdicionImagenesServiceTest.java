package uy.edu.proyecto.backend.anuncio;

import java.awt.image.BufferedImage;
import java.io.ByteArrayOutputStream;
import java.util.Base64;
import java.util.LinkedHashMap;
import java.util.List;
import java.util.Map;
import javax.imageio.ImageIO;
import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.mockito.InOrder;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.web.multipart.MultipartFile;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyInt;
import static org.mockito.ArgumentMatchers.anyList;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/**
 * PUT /api/admin/anuncios/{id}, tramo de imagenes: la lista final en orden, con ids existentes y archivos
 * nuevos, validada antes de tocar Storage y aplicada de una sola vez.
 */
class CarteleraEdicionImagenesServiceTest {
    private static final byte[] PNG = Base64.getDecoder().decode(
            "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/l5sAAAAASUVORK5CYII=");

    private final CarteleraRepository repo = mock(CarteleraRepository.class);
    private final AnuncioService anuncios = mock(AnuncioService.class);
    private final AlmacenImagenes almacen = mock(AlmacenImagenes.class);
    private final CarteleraService service = new CarteleraService(repo, anuncios, almacen);

    @BeforeEach
    void tresImagenesDeLaNovedad() {
        when(repo.existe(42)).thenReturn(true);
        when(repo.imagenes(42)).thenReturn(List.of(
                new CarteleraRepository.ImagenPropia(12, "a.png"),
                new CarteleraRepository.ImagenPropia(13, "b.png"),
                new CarteleraRepository.ImagenPropia(14, "c.png")));
    }

    private static AnuncioDTO.ImagenEdicion id(long id) {
        return new AnuncioDTO.ImagenEdicion(id, null);
    }

    private static AnuncioDTO.ImagenEdicion archivo(String nombre) {
        return new AnuncioDTO.ImagenEdicion(null, nombre);
    }

    private static AnuncioDTO.Edicion edicion(String texto, AnuncioDTO.ImagenEdicion... imagenes) {
        return new AnuncioDTO.Edicion("Título", null, texto, List.of(imagenes));
    }

    private static MockMultipartFile png(String nombre) {
        return new MockMultipartFile(nombre, nombre + ".png", "image/png", PNG);
    }

    private static byte[] imagen(String formato, int ancho, int alto) throws Exception {
        var salida = new ByteArrayOutputStream();
        ImageIO.write(new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB), formato, salida);
        return salida.toByteArray();
    }

    private static Map<String, MultipartFile> archivos(MultipartFile... partes) {
        var mapa = new LinkedHashMap<String, MultipartFile>();
        for (var parte : partes) mapa.put(parte.getName(), parte);
        return mapa;
    }

    private ApiException rechaza(AnuncioDTO.Edicion datos, Map<String, MultipartFile> archivos) {
        return assertThrows(ApiException.class, () -> service.editar(42, datos, archivos));
    }

    private void sinCambios() {
        verify(repo, never()).actualizarTexto(anyLong(), anyString(), any(), any());
        verify(repo, never()).agregarImagen(anyLong(), anyString(), anyInt());
        verify(repo, never()).actualizarOrden(anyLong(), anyInt());
        verify(repo, never()).quitarImagenes(anyLong(), anyList());
        verify(repo, never()).encolarReferencias(anyLong(), anyList());
    }

    // --- semantica de la lista ---

    @Test
    void sinImagenesEnDatosNoSeTocanLasImagenes() {
        service.editar(42, new AnuncioDTO.Edicion("Título", null, "Texto", null), Map.of());

        verify(repo).actualizarTexto(42, "Título", null, "Texto");
        verify(repo, never()).imagenes(anyLong());
        verify(repo, never()).agregarImagen(anyLong(), anyString(), anyInt());
        verify(repo, never()).actualizarOrden(anyLong(), anyInt());
        verify(repo, never()).quitarImagenes(anyLong(), anyList());
        verifyNoInteractions(almacen);
    }

    @Test
    void conArchivosPeroSinImagenesEnDatosEs400() {
        var error = rechaza(new AnuncioDTO.Edicion("Título", null, "Texto", null), archivos(png("nueva1")));

        assertEquals("VALIDACION", error.getCode());
        assertEquals("Se enviaron archivos pero datos no indica imágenes", error.getMessage());
        verifyNoInteractions(almacen);
    }

    @Test
    void unaListaVaciaEliminaTodasLasImagenesSiQuedaTexto() {
        service.editar(42, edicion("Texto"), Map.of());

        verify(repo).actualizarTexto(42, "Título", null, "Texto");
        InOrder orden = inOrder(repo);
        orden.verify(repo).encolarReferencias(42, List.of(12L, 13L, 14L));
        orden.verify(repo).quitarImagenes(42, List.of(12L, 13L, 14L));
        verify(repo, never()).agregarImagen(anyLong(), anyString(), anyInt());
        verifyNoInteractions(almacen);
    }

    @Test
    void unaListaVaciaSinTextoEs400YNoCambiaNada() {
        for (String texto : new String[] {null, "  "}) {
            var error = rechaza(edicion(texto), Map.of());
            assertEquals("VALIDACION", error.getCode());
            assertEquals("La novedad debe tener texto o al menos una imagen", error.getMessage());
        }
        sinCambios();
    }

    @Test
    void sinTextoPeroConUnaImagenFinalSeGuarda() {
        service.editar(42, edicion(null, id(12)), Map.of());

        verify(repo).actualizarTexto(42, "Título", null, null);
        verify(repo).actualizarOrden(12, 0);
    }

    @Test
    void agregaUnaImagenNuevaAlFinal() {
        service.editar(42, edicion("Texto", id(12), id(13), id(14), archivo("nueva1")), archivos(png("nueva1")));

        ArgumentCaptor<String> referencia = ArgumentCaptor.forClass(String.class);
        verify(almacen).guardar(referencia.capture(), eq(PNG), eq("image/png"));
        assertTrue(referencia.getValue().endsWith(".png"));
        verify(repo).agregarImagen(42, referencia.getValue(), 3);
        verify(repo).actualizarOrden(12, 0);
        verify(repo).actualizarOrden(13, 1);
        verify(repo).actualizarOrden(14, 2);
        verify(repo, never()).quitarImagenes(anyLong(), anyList());
        verify(repo, never()).encolarReferencias(anyLong(), anyList());
    }

    @Test
    void quitaUnaImagenYLaEncolaParaBorrarAntesDeEliminarSuFila() {
        service.editar(42, edicion("Texto", id(12), id(14)), Map.of());

        InOrder orden = inOrder(repo);
        orden.verify(repo).encolarReferencias(42, List.of(13L));
        orden.verify(repo).quitarImagenes(42, List.of(13L));
        verify(repo).actualizarOrden(12, 0);
        verify(repo).actualizarOrden(14, 1);
        verifyNoInteractions(almacen);
    }

    @Test
    void reordenarCambiaLaPortadaYGuardaOrden012() {
        service.editar(42, edicion("Texto", id(14), id(12), id(13)), Map.of());

        verify(repo).actualizarOrden(14, 0);
        verify(repo).actualizarOrden(12, 1);
        verify(repo).actualizarOrden(13, 2);
        verify(repo, never()).quitarImagenes(anyLong(), anyList());
        verify(repo, never()).agregarImagen(anyLong(), anyString(), anyInt());
    }

    @Test
    void mezclaExistentesYNuevasEnElOrdenDeLaLista() {
        service.editar(42, edicion("Texto", id(12), archivo("nueva1"), id(14)), archivos(png("nueva1")));

        ArgumentCaptor<String> referencia = ArgumentCaptor.forClass(String.class);
        verify(almacen).guardar(referencia.capture(), any(), eq("image/png"));
        verify(repo).actualizarOrden(12, 0);
        verify(repo).agregarImagen(42, referencia.getValue(), 1);
        verify(repo).actualizarOrden(14, 2);
        verify(repo).encolarReferencias(42, List.of(13L));
        verify(repo).quitarImagenes(42, List.of(13L));
    }

    @Test
    void aceptaCincoEntreExistentesYNuevasPeroNoSeis() {
        when(repo.imagenes(42)).thenReturn(List.of(
                new CarteleraRepository.ImagenPropia(12, "a.png"),
                new CarteleraRepository.ImagenPropia(13, "b.png"),
                new CarteleraRepository.ImagenPropia(14, "c.png")));
        service.editar(42, edicion("Texto", id(12), id(13), id(14), archivo("n1"), archivo("n2")),
                archivos(png("n1"), png("n2")));
        verify(repo).agregarImagen(eq(42L), anyString(), eq(3));
        verify(repo).agregarImagen(eq(42L), anyString(), eq(4));

        var error = rechaza(edicion("Texto", id(12), id(13), id(14), archivo("n1"), archivo("n2"), archivo("n3")),
                archivos(png("n1"), png("n2"), png("n3")));
        assertEquals("VALIDACION", error.getCode());
        assertEquals("La novedad admite hasta 5 imágenes", error.getMessage());
        verify(almacen, times(2)).guardar(anyString(), any(), eq("image/png"));
    }

    // --- validaciones antes de tocar Storage ---

    @Test
    void losIdsDuplicadosSon400() {
        var error = rechaza(edicion("Texto", id(12), id(13), id(12)), Map.of());

        assertEquals("VALIDACION", error.getCode());
        assertEquals("La imagen 12 figura más de una vez", error.getMessage());
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void losNombresDeArchivoDuplicadosSon400() {
        var error = rechaza(edicion("Texto", archivo("nueva1"), archivo("nueva1")), archivos(png("nueva1")));

        assertEquals("VALIDACION", error.getCode());
        assertEquals("El archivo nueva1 figura más de una vez", error.getMessage());
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void unArchivoReferidoQueNoLlegoEs400() {
        var error = rechaza(edicion("Texto", id(12), archivo("nueva1")), Map.of());

        assertEquals("VALIDACION", error.getCode());
        assertEquals("El archivo nueva1 no llegó en el pedido", error.getMessage());
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void unaParteDeArchivoQueNoFiguraEnLaListaEs400() {
        var error = rechaza(edicion("Texto", id(12)), archivos(png("sobra")));

        assertEquals("VALIDACION", error.getCode());
        assertEquals("El archivo sobra se envió pero no figura en imagenes", error.getMessage());
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void unaImagenDeOtraNovedadEs400() {
        var error = rechaza(edicion("Texto", id(12), id(99)), Map.of());

        assertEquals("VALIDACION", error.getCode());
        assertEquals("La imagen 99 no pertenece a esta novedad", error.getMessage());
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void unaImagenAjenaJuntoConUnaNuevaNoSubeNadaAStorage() {
        var error = rechaza(edicion("Texto", id(99), archivo("nueva1")), archivos(png("nueva1")));

        assertEquals("La imagen 99 no pertenece a esta novedad", error.getMessage());
        verifyNoInteractions(almacen);
        verify(repo, never()).bloquearCambios();
        sinCambios();
    }

    @Test
    void cadaEntradaIndicaUnIdOUnArchivoPeroNoAmbosNiNinguno() {
        for (var invalida : List.of(new AnuncioDTO.ImagenEdicion(12L, "nueva1"), new AnuncioDTO.ImagenEdicion(null, null),
                new AnuncioDTO.ImagenEdicion(null, "  "))) {
            var error = rechaza(edicion("Texto", invalida), archivos(png("nueva1")));
            assertEquals("VALIDACION", error.getCode());
            assertEquals("Cada imagen debe indicar solo un id o solo un archivo", error.getMessage());
        }
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void unaListaConUnaEntradaNulaEs400() {
        var lista = new java.util.ArrayList<AnuncioDTO.ImagenEdicion>();
        lista.add(null);

        var error = rechaza(new AnuncioDTO.Edicion("Título", null, "Texto", lista), Map.of());

        assertEquals("Cada imagen debe indicar solo un id o solo un archivo", error.getMessage());
    }

    @Test
    void unaNovedadInexistenteEs404SinSubirNada() {
        when(repo.existe(42)).thenReturn(false);

        var error = rechaza(edicion("Texto", archivo("nueva1")), archivos(png("nueva1")));

        assertEquals("NO_ENCONTRADO", error.getCode());
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void rechazaUnArchivoQueNoEsJpegNiPngAntesDeSubir() {
        var gif = new MockMultipartFile("nueva1", "a.gif", "image/gif", PNG);

        var error = rechaza(edicion("Texto", archivo("nueva1")), archivos(gif));

        assertEquals("VALIDACION", error.getCode());
        assertEquals("Solo se admiten imágenes JPEG o PNG", error.getMessage());
        verifyNoInteractions(almacen);
        sinCambios();
    }

    @Test
    void rechazaUnArchivoQueDeclaraPngPeroNoLoEs() {
        var falso = new MockMultipartFile("nueva1", "a.png", "image/png", "texto".getBytes());

        var error = rechaza(edicion("Texto", archivo("nueva1")), archivos(falso));

        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(almacen);
    }

    @Test
    void rechazaUnArchivoDeMasDeCincoMegabytes() {
        var grande = new MockMultipartFile("nueva1", "a.png", "image/png", new byte[5 * 1024 * 1024 + 1]);

        var error = rechaza(edicion("Texto", archivo("nueva1")), archivos(grande));

        assertEquals("IMAGEN_INVALIDA", error.getCode());
        assertEquals(400, error.getStatus().value());
        assertEquals("Cada imagen admite hasta 5 MB", error.getMessage());
        verifyNoInteractions(almacen);
    }

    @Test
    void rechazaMasDeSeisMilPixelesPeroAceptaSeisMilYJpeg() throws Exception {
        var ancha = new MockMultipartFile("nueva1", "a.png", "image/png", imagen("png", 6001, 1));
        var error = rechaza(edicion("Texto", archivo("nueva1")), archivos(ancha));
        assertEquals("VALIDACION", error.getCode());
        assertEquals("La imagen supera las dimensiones permitidas", error.getMessage());
        var alta = new MockMultipartFile("nueva1", "a.png", "image/png", imagen("png", 1, 6001));
        assertEquals("La imagen supera las dimensiones permitidas",
                rechaza(edicion("Texto", archivo("nueva1")), archivos(alta)).getMessage());
        verifyNoInteractions(almacen);

        var limite = new MockMultipartFile("nueva1", "a.png", "image/png", imagen("png", 6000, 1));
        var jpeg = new MockMultipartFile("nueva2", "b.jpg", "image/jpeg", imagen("jpg", 2, 2));
        service.editar(42, edicion("Texto", archivo("nueva1"), archivo("nueva2")), archivos(limite, jpeg));
        verify(almacen).guardar(anyString(), any(), eq("image/png"));
        verify(almacen).guardar(argThatEndsWith(".jpg"), any(), eq("image/jpeg"));
    }

    private static String argThatEndsWith(String sufijo) {
        // Solo los originales: la miniatura (mini/...) tambien es un .jpg pero no es lo que se prueba aca.
        return org.mockito.ArgumentMatchers.argThat(
                valor -> valor != null && valor.endsWith(sufijo) && !valor.startsWith("mini/"));
    }

    // --- Storage y candado ---

    @Test
    void lasNuevasSeSubenAntesDeTomarElCandado() {
        service.editar(42, edicion("Texto", id(12), archivo("nueva1")), archivos(png("nueva1")));

        InOrder orden = inOrder(almacen, repo);
        orden.verify(almacen).guardar(anyString(), any(), eq("image/png"));
        orden.verify(repo).bloquearCambios();
        orden.verify(repo).actualizarTexto(eq(42L), anyString(), any(), any());
    }

    @Test
    void siFallaLaSegundaSubidaDevuelve503BorraLaPrimeraYNoCambiaNada() {
        // La primera sale bien y la segunda falla.
        org.mockito.Mockito.doNothing().doThrow(new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                        "ALMACENAMIENTO_NO_DISPONIBLE", "No se pudo acceder a las imágenes"))
                .when(almacen).guardar(anyString(), any(), eq("image/png"));

        var error = rechaza(edicion("Texto", archivo("n1"), archivo("n2")), archivos(png("n1"), png("n2")));

        assertEquals(503, error.getStatus().value());
        assertEquals("ALMACENAMIENTO_NO_DISPONIBLE", error.getCode());
        ArgumentCaptor<String> subida = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(2)).guardar(subida.capture(), any(), eq("image/png"));
        verify(almacen).borrar(subida.getAllValues().getFirst());
        verify(repo, never()).bloquearCambios();
        sinCambios();
    }

    @Test
    void siLaNovedadDesapareceDuranteLaSubidaEs404YSeBorranLasSubidas() {
        // La primera comprobacion (antes de subir) la ve; la del candado, ya no.
        when(repo.existe(42)).thenReturn(true, false);

        var error = rechaza(edicion("Texto", archivo("n1"), archivo("n2")), archivos(png("n1"), png("n2")));

        assertEquals("NO_ENCONTRADO", error.getCode());
        assertEquals(404, error.getStatus().value());
        ArgumentCaptor<String> subida = ArgumentCaptor.forClass(String.class);
        verify(almacen, times(2)).guardar(subida.capture(), any(), eq("image/png"));
        verify(almacen).borrar(subida.getAllValues().get(0));
        verify(almacen).borrar(subida.getAllValues().get(1));
        sinCambios();
    }

    @Test
    void siUnaImagenSeQuitoMientrasTantoEs400YSeBorranLasSubidas() {
        // Antes de subir la lista es valida; bajo el candado la 13 ya no es de la novedad.
        when(repo.imagenes(42)).thenReturn(
                List.of(new CarteleraRepository.ImagenPropia(12, "a.png"),
                        new CarteleraRepository.ImagenPropia(13, "b.png")),
                List.of(new CarteleraRepository.ImagenPropia(12, "a.png")));

        var error = rechaza(edicion("Texto", id(12), id(13), archivo("n1")), archivos(png("n1")));

        assertEquals("VALIDACION", error.getCode());
        assertEquals("La imagen 13 no pertenece a esta novedad", error.getMessage());
        ArgumentCaptor<String> subida = ArgumentCaptor.forClass(String.class);
        verify(almacen).guardar(subida.capture(), any(), eq("image/png"));
        verify(almacen).borrar(subida.getValue());
        sinCambios();
    }

    @Test
    void siFallaLaBaseDespuesDeSubirSeBorranLasSubidas() {
        doThrow(new IllegalStateException("db")).when(repo).agregarImagen(anyLong(), anyString(), anyInt());

        assertThrows(IllegalStateException.class,
                () -> service.editar(42, edicion("Texto", archivo("n1")), archivos(png("n1"))));

        ArgumentCaptor<String> subida = ArgumentCaptor.forClass(String.class);
        verify(almacen).guardar(subida.capture(), any(), eq("image/png"));
        verify(almacen).borrar(subida.getValue());
    }

    @Test
    void siElBorradoDeLasSubidasFallaIgualSeInformaElErrorOriginal() {
        doThrow(new IllegalStateException("db")).when(repo).agregarImagen(anyLong(), anyString(), anyInt());
        doThrow(new IllegalStateException("storage")).when(almacen).borrar(anyString());

        var error = assertThrows(IllegalStateException.class,
                () -> service.editar(42, edicion("Texto", archivo("n1")), archivos(png("n1"))));

        assertEquals("db", error.getMessage());
    }

    @Test
    void sinNuevasNoSeUsaStorage() {
        service.editar(42, edicion("Texto", id(14), id(12)), Map.of());

        verifyNoInteractions(almacen);
    }
}
