package uy.edu.proyecto.backend.anuncio;

import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.mock.web.MockMultipartFile;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

/** PUT /api/admin/anuncios/{id}, tramo de texto: reglas del servicio con el repositorio simulado. */
class CarteleraEdicionServiceTest {
    private final CarteleraRepository repo = mock(CarteleraRepository.class);
    private final AnuncioService anuncios = mock(AnuncioService.class);
    private final AlmacenImagenes almacen = mock(AlmacenImagenes.class);
    private final CarteleraService service = new CarteleraService(repo, anuncios, almacen);

    private static final String MSG_TITULO = "El título es obligatorio y admite hasta 160 caracteres";
    private static final String MSG_RESUMEN = "El resumen admite hasta 300 caracteres";
    private static final String MSG_SIN_CONTENIDO = "La novedad debe tener texto o al menos una imagen";
    private static final String MSG_ARCHIVOS = "Se enviaron archivos pero datos no indica imágenes";

    private void existe() {
        when(repo.existe(42)).thenReturn(true);
    }

    private ApiException rechaza(AnuncioDTO.Edicion datos, Map<String, org.springframework.web.multipart.MultipartFile> archivos) {
        return assertThrows(ApiException.class, () -> service.editar(42, datos, archivos));
    }

    @Test
    void editaSoloElTextoYLoGuardaRecortado() {
        existe();
        when(repo.cantidadImagenes(42)).thenReturn(0);

        service.editar(42, new AnuncioDTO.Edicion(" Nuevo título ", " Resumen ", " Texto nuevo "), Map.of());

        InOrder orden = inOrder(repo);
        orden.verify(repo).bloquearCambios();
        orden.verify(repo).existe(42);
        orden.verify(repo).actualizarTexto(42, "Nuevo título", "Resumen", "Texto nuevo");
        verify(repo, never()).vigencia(anyLong(), any());
        verify(repo, never()).reemplazar(any());
        verify(repo, never()).eliminar(anyLong());
        verifyNoInteractions(almacen);
    }

    @Test
    void elTituloEsObligatorio() {
        for (String titulo : new String[] {null, "", "   "}) {
            var error = rechaza(new AnuncioDTO.Edicion(titulo, null, "Texto"), Map.of());
            assertEquals("VALIDACION", error.getCode());
            assertEquals(400, error.getStatus().value());
            assertEquals(MSG_TITULO, error.getMessage());
        }
        verifyNoInteractions(repo);
    }

    @Test
    void elTituloAdmiteHasta160Caracteres() {
        existe();
        service.editar(42, new AnuncioDTO.Edicion("a".repeat(160), null, "Texto"), Map.of());
        verify(repo).actualizarTexto(42, "a".repeat(160), null, "Texto");

        var error = rechaza(new AnuncioDTO.Edicion("a".repeat(161), null, "Texto"), Map.of());
        assertEquals("VALIDACION", error.getCode());
        assertEquals(MSG_TITULO, error.getMessage());
    }

    @Test
    void losEspaciosDeLosExtremosNoCuentanEnElLargoDelTitulo() {
        existe();
        service.editar(42, new AnuncioDTO.Edicion(" " + "a".repeat(160) + " ", null, "Texto"), Map.of());
        verify(repo).actualizarTexto(42, "a".repeat(160), null, "Texto");
    }

    @Test
    void elResumenAdmiteHasta300Caracteres() {
        existe();
        service.editar(42, new AnuncioDTO.Edicion("Título", "r".repeat(300), "Texto"), Map.of());
        verify(repo).actualizarTexto(42, "Título", "r".repeat(300), "Texto");

        var error = rechaza(new AnuncioDTO.Edicion("Título", "r".repeat(301), "Texto"), Map.of());
        assertEquals("VALIDACION", error.getCode());
        assertEquals(MSG_RESUMEN, error.getMessage());
    }

    @Test
    void unResumenEnBlancoSeGuardaComoNulo() {
        existe();
        service.editar(42, new AnuncioDTO.Edicion("Título", "   ", "Texto"), Map.of());
        verify(repo).actualizarTexto(42, "Título", null, "Texto");
    }

    @Test
    void sinDatosEsUnaValidacion() {
        var error = rechaza(null, Map.of());
        assertEquals("VALIDACION", error.getCode());
        assertEquals(MSG_TITULO, error.getMessage());
        verifyNoInteractions(repo);
    }

    @Test
    void unaNovedadInexistenteEs404ConElCandadoTomadoYSinCambios() {
        when(repo.existe(42)).thenReturn(false);

        var error = rechaza(new AnuncioDTO.Edicion("Título", null, "Texto"), Map.of());

        assertEquals("NO_ENCONTRADO", error.getCode());
        assertEquals(404, error.getStatus().value());
        InOrder orden = inOrder(repo);
        orden.verify(repo).bloquearCambios();
        orden.verify(repo).existe(42);
        verify(repo, never()).actualizarTexto(anyLong(), anyString(), any(), any());
    }

    @Test
    void unIdNoPositivoEs404SinTocarLaBase() {
        for (long id : new long[] {0, -5}) {
            var error = assertThrows(ApiException.class,
                    () -> service.editar(id, new AnuncioDTO.Edicion("Título", null, "Texto"), Map.of()));
            assertEquals("NO_ENCONTRADO", error.getCode());
        }
        verifyNoInteractions(repo);
    }

    @Test
    void sinTextoYSinImagenesNoSePuedeGuardar() {
        existe();
        when(repo.cantidadImagenes(42)).thenReturn(0);

        for (String texto : new String[] {null, "", " \t \n "}) {
            var error = rechaza(new AnuncioDTO.Edicion("Título", "Resumen", texto), Map.of());
            assertEquals("VALIDACION", error.getCode());
            assertEquals(MSG_SIN_CONTENIDO, error.getMessage());
        }
        verify(repo, never()).actualizarTexto(anyLong(), anyString(), any(), any());
    }

    @Test
    void sinTextoPeroConImagenesSeGuardaConTextoNulo() {
        existe();
        when(repo.cantidadImagenes(42)).thenReturn(2);

        service.editar(42, new AnuncioDTO.Edicion("Título", null, "  "), Map.of());

        verify(repo).actualizarTexto(42, "Título", null, null);
    }

    @Test
    void losArchivosSinImagenesEnDatosSonUnaValidacionClara() {
        var archivo = new MockMultipartFile("nueva1", "a.png", "image/png", new byte[] {1});

        var error = rechaza(new AnuncioDTO.Edicion("Título", null, "Texto"), Map.of("nueva1", archivo));

        assertEquals("VALIDACION", error.getCode());
        assertEquals(400, error.getStatus().value());
        assertEquals(MSG_ARCHIVOS, error.getMessage());
        verifyNoInteractions(repo, almacen);
    }

    @Test
    void sinMapaDeArchivosTambienEdita() {
        existe();
        service.editar(42, new AnuncioDTO.Edicion("Título", null, "Texto"), null);
        verify(repo).actualizarTexto(42, "Título", null, "Texto");
    }
}
