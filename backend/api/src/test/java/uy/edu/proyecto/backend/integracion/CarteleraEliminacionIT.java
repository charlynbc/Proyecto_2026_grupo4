package uy.edu.proyecto.backend.integracion;

import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import uy.edu.proyecto.backend.anuncio.AlmacenImagenes;

import static org.junit.jupiter.api.Assertions.assertEquals;

/** DELETE /api/admin/anuncios/{id}: la cola de borrado de archivos, por HTTP y PostgreSQL real. */
class CarteleraEliminacionIT extends BaseIntegracionIT {
    @MockitoBean
    AlmacenImagenes almacen;

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
