package uy.edu.proyecto.backend.integracion;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.mockito.InOrder;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import uy.edu.proyecto.backend.anuncio.AlmacenImagenes;
import uy.edu.proyecto.backend.anuncio.CarteleraService;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.inOrder;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.verify;

/**
 * DELETE /api/admin/anuncios/{id}: la cola de borrado de archivos, por HTTP y PostgreSQL real. El limpiador de
 * fondo queda para dentro de una hora: los tests lo llaman a mano y asi no compite con ellos.
 */
@TestPropertySource(properties = "app.anuncios.limpieza-intervalo-ms=3600000")
class CarteleraEliminacionIT extends BaseIntegracionIT {
    @MockitoBean
    AlmacenImagenes almacen;

    @Autowired
    CarteleraService cartelera;

    private long novedadConImagenes(String... referencias) {
        long id = jdbc.queryForObject("""
                INSERT INTO anuncio (id_administrador, titulo, texto, vigente_hasta)
                VALUES (?, 'Titulo', 'Texto', '2099-01-01T00:00:00Z'::timestamptz) RETURNING id_anuncio
                """, Long.class, idAdmin);
        for (int i = 0; i < referencias.length; i++) {
            jdbc.update("INSERT INTO imagen_anuncio (id_anuncio, referencia_archivo, orden) VALUES (?, ?, ?)",
                    id, referencias[i], i);
        }
        return id;
    }

    @Test
    void eliminarEncolaLasReferenciasYBorraLasFilas() {
        long id = novedadConImagenes("a.png", "b.png");

        Respuesta r = enviar("DELETE", "/api/admin/anuncios/" + id, tokenEmpleado(ciAdmin), null, null);

        assertEquals(202, r.estado(), r.cuerpo());
        assertEquals(0, contar("anuncio"));
        assertEquals(0, contar("imagen_anuncio"));
        assertEquals(List.of("a.png", "b.png"), jdbc.queryForList(
                "SELECT referencia_archivo FROM anuncio_archivo_pendiente_borrado ORDER BY referencia_archivo",
                String.class));
    }

    private static final String ORIGINAL = "123e4567-e89b-12d3-a456-426614174000.png";
    private static final String MINIATURA = "mini/123e4567-e89b-12d3-a456-426614174000.jpg";

    private void eliminarNovedadConUnaImagen() {
        desplazarIdsDeAnuncios();
        long id = novedadConImagenes(ORIGINAL);
        assertEquals(41, id);
        Respuesta r = enviar("DELETE", "/api/admin/anuncios/" + id, tokenEmpleado(ciAdmin), null, null);
        assertEquals(202, r.estado(), r.cuerpo());
        assertEquals(List.of(ORIGINAL), jdbc.queryForList(
                "SELECT referencia_archivo FROM anuncio_archivo_pendiente_borrado", String.class));
    }

    @Test
    void laColaBorraElOriginalYDespuesLaMiniatura() {
        eliminarNovedadConUnaImagen();

        cartelera.limpiarPendiente();

        InOrder orden = inOrder(almacen);
        orden.verify(almacen).borrar(ORIGINAL);
        orden.verify(almacen).borrar(MINIATURA);
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void siFallaElBorradoDeLaMiniaturaElPendienteSeResuelveIgualYNoSeReintenta() {
        eliminarNovedadConUnaImagen();
        doThrow(new IllegalStateException("storage")).when(almacen).borrar(MINIATURA);

        cartelera.limpiarPendiente();

        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
        verify(almacen, times(1)).borrar(MINIATURA);
    }

    @Test
    void siFallaElBorradoDelOriginalElPendienteQuedaConUnIntentoYNoSeTocaLaMiniatura() {
        eliminarNovedadConUnaImagen();
        doThrow(new IllegalStateException("storage")).when(almacen).borrar(ORIGINAL);

        cartelera.limpiarPendiente();

        assertEquals(List.of(1), jdbc.queryForList(
                "SELECT intentos FROM anuncio_archivo_pendiente_borrado", Integer.class));
        verify(almacen, never()).borrar(MINIATURA);
    }

    @Test
    void eliminarUnaNovedadInexistenteEs404SinEncolarNada() {
        Respuesta r = enviar("DELETE", "/api/admin/anuncios/999999", tokenEmpleado(ciAdmin), null, null);

        assertEquals(404, r.estado(), r.cuerpo());
        assertEquals(0, contar("anuncio_archivo_pendiente_borrado"));
    }

    @Test
    void unaReferenciaYaEncoladaNoDuplicaLaFila() {
        long id = novedadConImagenes("a.png");
        jdbc.update("INSERT INTO anuncio_archivo_pendiente_borrado (referencia_archivo) VALUES ('a.png')");

        Respuesta r = enviar("DELETE", "/api/admin/anuncios/" + id, tokenEmpleado(ciAdmin), null, null);

        assertEquals(202, r.estado(), r.cuerpo());
        assertEquals(1, contar("anuncio_archivo_pendiente_borrado"));
    }
}
