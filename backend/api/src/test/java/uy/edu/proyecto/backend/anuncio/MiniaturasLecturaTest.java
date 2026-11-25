package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
import tools.jackson.databind.ObjectMapper;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

/**
 * Lectura de novedades: cada imagen trae url (el original firmado, como siempre) y urlMiniatura (la firma de
 * mini/uuid.jpg). Si la miniatura no se puede firmar, urlMiniatura es null y el endpoint responde igual.
 * Los ids de novedad (42) e imagen (7, 8) son distintos a proposito.
 */
class MiniaturasLecturaTest {
    private static final OffsetDateTime PUBLICADO = OffsetDateTime.parse("2026-11-03T12:00:00Z");
    private static final AnuncioRepository.Fila FILA =
            new AnuncioRepository.Fila(42, "Vacunación", "Resumen", "Texto", PUBLICADO);

    private final AnuncioRepository repository = mock(AnuncioRepository.class);
    private final AlmacenImagenes almacen = mock(AlmacenImagenes.class);
    private final AnuncioService anuncios = new AnuncioService(repository, almacen);
    private final CarteleraRepository repo = mock(CarteleraRepository.class);
    private final CarteleraService cartelera = new CarteleraService(repo, anuncios, almacen);

    private static ApiException sinAlmacenamiento() {
        return new ApiException(HttpStatus.SERVICE_UNAVAILABLE,
                "ALMACENAMIENTO_NO_DISPONIBLE", "No se pudo acceder a las imágenes");
    }

    private void conDosImagenes() {
        when(repository.imagenes(42L)).thenReturn(List.of(
                new AnuncioRepository.ImagenFila(7, 0, "primera.png"),
                new AnuncioRepository.ImagenFila(8, 1, "segunda.jpg")));
        when(almacen.enlaceTemporal("primera.png")).thenReturn("https://example.test/original-1");
        when(almacen.enlaceTemporal("segunda.jpg")).thenReturn("https://example.test/original-2");
        when(almacen.enlaceTemporal("mini/primera.jpg")).thenReturn("https://example.test/mini-1");
        when(almacen.enlaceTemporal("mini/segunda.jpg")).thenReturn("https://example.test/mini-2");
    }

    // --- GET /api/anuncios ---

    @Test
    void laPortadaDelListadoTraeElOriginalYLaMiniaturaFirmados() {
        when(repository.listar(0, 20)).thenReturn(List.of(FILA));
        when(repository.total()).thenReturn(1L);
        conDosImagenes();

        var portada = anuncios.listar(0, 20).items().getFirst().imagenPortada();

        assertEquals(7, portada.id());
        assertEquals("https://example.test/original-1", portada.url());
        assertEquals("https://example.test/mini-1", portada.urlMiniatura());
    }

    @Test
    void siFallaLaFirmaDeLaMiniaturaElListadoResponde200ConUrlMiniaturaNula() {
        when(repository.listar(0, 20)).thenReturn(List.of(FILA));
        when(repository.total()).thenReturn(1L);
        conDosImagenes();
        when(almacen.enlaceTemporal("mini/primera.jpg")).thenThrow(sinAlmacenamiento());

        var portada = anuncios.listar(0, 20).items().getFirst().imagenPortada();

        assertEquals("https://example.test/original-1", portada.url());
        assertNull(portada.urlMiniatura());
    }

    @Test
    void siLaFirmaDeLaMiniaturaFallaPorCualquierOtroMotivoTambienQuedaNula() {
        when(repository.listar(0, 20)).thenReturn(List.of(FILA));
        when(repository.total()).thenReturn(1L);
        conDosImagenes();
        when(almacen.enlaceTemporal("mini/primera.jpg")).thenThrow(new IllegalStateException("inesperado"));

        var portada = anuncios.listar(0, 20).items().getFirst().imagenPortada();

        assertEquals("https://example.test/original-1", portada.url());
        assertNull(portada.urlMiniatura());
    }

    @Test
    void siFallaLaFirmaDelOriginalElListadoSigueDandoElErrorDeHoy() {
        when(repository.listar(0, 20)).thenReturn(List.of(FILA));
        conDosImagenes();
        when(almacen.enlaceTemporal("primera.png")).thenThrow(sinAlmacenamiento());

        var error = assertThrows(ApiException.class, () -> anuncios.listar(0, 20));

        assertEquals(HttpStatus.SERVICE_UNAVAILABLE, error.getStatus());
        assertEquals("ALMACENAMIENTO_NO_DISPONIBLE", error.getCode());
    }

    @Test
    void unaNovedadSinImagenesSigueConPortadaNula() {
        when(repository.listar(0, 20)).thenReturn(List.of(FILA));
        when(repository.imagenes(42L)).thenReturn(List.of());

        assertNull(anuncios.listar(0, 20).items().getFirst().imagenPortada());
    }

    // --- GET /api/anuncios/{id} ---

    @Test
    void elDetalleTraeLaMiniaturaDeCadaImagen() {
        when(repository.buscar(42L)).thenReturn(FILA);
        conDosImagenes();

        var imagenes = anuncios.detalle(42).imagenes();

        assertEquals(2, imagenes.size());
        assertEquals("https://example.test/original-1", imagenes.get(0).url());
        assertEquals("https://example.test/mini-1", imagenes.get(0).urlMiniatura());
        assertEquals("https://example.test/original-2", imagenes.get(1).url());
        assertEquals("https://example.test/mini-2", imagenes.get(1).urlMiniatura());
    }

    @Test
    void enElDetalleUnaMiniaturaQueNoSeFirmaQuedaNulaSinAfectarALasDemas() {
        when(repository.buscar(42L)).thenReturn(FILA);
        conDosImagenes();
        when(almacen.enlaceTemporal("mini/segunda.jpg")).thenThrow(sinAlmacenamiento());

        var imagenes = anuncios.detalle(42).imagenes();

        assertEquals("https://example.test/mini-1", imagenes.get(0).urlMiniatura());
        assertEquals("https://example.test/original-2", imagenes.get(1).url());
        assertNull(imagenes.get(1).urlMiniatura());
    }

    @Test
    void siFallaLaFirmaDeUnOriginalElDetalleSigueDandoElErrorDeHoy() {
        when(repository.buscar(42L)).thenReturn(FILA);
        conDosImagenes();
        when(almacen.enlaceTemporal("segunda.jpg")).thenThrow(sinAlmacenamiento());

        var error = assertThrows(ApiException.class, () -> anuncios.detalle(42));

        assertEquals("ALMACENAMIENTO_NO_DISPONIBLE", error.getCode());
    }

    // --- carrusel y detalle de administracion, que reutilizan Imagen ---

    @Test
    void elCarruselTraeLaMiniaturaDeSusImagenes() {
        when(repo.visibles()).thenReturn(List.of(42L));
        when(repository.buscar(42L)).thenReturn(FILA);
        conDosImagenes();

        var imagenes = cartelera.visibles().getFirst().imagenes();

        assertEquals("https://example.test/mini-1", imagenes.get(0).urlMiniatura());
        assertEquals("https://example.test/mini-2", imagenes.get(1).urlMiniatura());
    }

    @Test
    void elCarruselResponde200ConUrlMiniaturaNulaSiNoSeFirma() {
        when(repo.visibles()).thenReturn(List.of(42L));
        when(repository.buscar(42L)).thenReturn(FILA);
        conDosImagenes();
        when(almacen.enlaceTemporal("mini/primera.jpg")).thenThrow(sinAlmacenamiento());

        var imagenes = cartelera.visibles().getFirst().imagenes();

        assertNull(imagenes.get(0).urlMiniatura());
        assertEquals("https://example.test/original-1", imagenes.get(0).url());
        assertEquals("https://example.test/mini-2", imagenes.get(1).urlMiniatura());
    }

    @Test
    void elDetalleDeAdministracionTraeLaMiniatura() {
        when(repo.administracion(42L)).thenReturn(
                new AnuncioDTO.Administracion(42, "Vacunación", PUBLICADO, null, null, "VIGENTE", 3));
        when(repository.buscarCualquiera(42L)).thenReturn(FILA);
        conDosImagenes();

        var imagenes = cartelera.detalle(42).imagenes();

        assertEquals("https://example.test/original-1", imagenes.get(0).url());
        assertEquals("https://example.test/mini-1", imagenes.get(0).urlMiniatura());
        assertEquals("https://example.test/mini-2", imagenes.get(1).urlMiniatura());
    }

    @Test
    void elDetalleDeAdministracionResponde200ConUrlMiniaturaNulaSiNoSeFirma() {
        when(repo.administracion(42L)).thenReturn(
                new AnuncioDTO.Administracion(42, "Vacunación", PUBLICADO, null, null, "VIGENTE", 3));
        when(repository.buscarCualquiera(42L)).thenReturn(FILA);
        conDosImagenes();
        when(almacen.enlaceTemporal("mini/primera.jpg")).thenThrow(new IllegalStateException("inesperado"));

        var imagenes = cartelera.detalle(42).imagenes();

        assertNull(imagenes.get(0).urlMiniatura());
        assertEquals("https://example.test/original-1", imagenes.get(0).url());
    }

    // --- JSON ---

    @Test
    void urlMiniaturaSiempreFiguraEnElJsonAunqueSeaNula() {
        var json = new ObjectMapper().writeValueAsString(new AnuncioDTO.Imagen(7, 0, "https://example.test/o", null));

        assertTrue(json.contains("\"urlMiniatura\":null"), json);
        assertTrue(json.contains("\"url\":\"https://example.test/o\""), json);
    }

    @Test
    void urlMiniaturaFiguraEnElJsonConSuValor() {
        var json = new ObjectMapper().writeValueAsString(
                new AnuncioDTO.Imagen(7, 0, "https://example.test/o", "https://example.test/m"));

        assertTrue(json.contains("\"urlMiniatura\":\"https://example.test/m\""), json);
    }
}
