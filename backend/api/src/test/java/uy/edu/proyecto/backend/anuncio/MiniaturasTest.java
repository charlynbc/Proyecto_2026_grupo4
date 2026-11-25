package uy.edu.proyecto.backend.anuncio;

import java.awt.Color;
import java.awt.image.BufferedImage;
import java.awt.image.DataBuffer;
import java.awt.image.Raster;
import java.awt.image.WritableRaster;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.nio.charset.StandardCharsets;
import java.util.Optional;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.stream.MemoryCacheImageOutputStream;
import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Generador de miniaturas: ancho maximo 640, sin agrandar, JPEG, orientacion EXIF corregida y alfa aplanado sobre
 * blanco. Los tamanos y colores esperados estan escritos a mano.
 */
class MiniaturasTest {
    private static final int ROJO = 0xFF0000;
    private static final int VERDE = 0x00FF00;
    private static final int AZUL = 0x0000FF;
    private static final int AMARILLO = 0xFFFF00;
    private static final int BLANCO = 0xFFFFFF;

    // --- tamanos ---

    @Test
    void unaImagenDe3000x2000QuedaEn640x427() throws Exception {
        var miniatura = generar(png(solida(3000, 2000, Color.GRAY)));

        assertEquals(640, leer(miniatura).getWidth());
        assertEquals(427, leer(miniatura).getHeight());
    }

    @Test
    void unaImagenDe6000x6000QuedaEn640x640() throws Exception {
        var miniatura = generar(png(grisSolida(6000, 6000)));

        assertEquals(640, leer(miniatura).getWidth());
        assertEquals(640, leer(miniatura).getHeight());
    }

    @Test
    void unaImagenChicaNoSeAgranda() throws Exception {
        var miniatura = generar(png(solida(400, 300, Color.GRAY)));

        assertEquals(400, leer(miniatura).getWidth());
        assertEquals(300, leer(miniatura).getHeight());
    }

    @Test
    void unaImagenDeExactamente640DeAnchoQuedaIgual() throws Exception {
        var miniatura = generar(png(solida(640, 480, Color.GRAY)));

        assertEquals(640, leer(miniatura).getWidth());
        assertEquals(480, leer(miniatura).getHeight());
    }

    @Test
    void unaImagenDe1x1QuedaEn1x1() throws Exception {
        var miniatura = generar(png(solida(1, 1, Color.GRAY)));

        assertEquals(1, leer(miniatura).getWidth());
        assertEquals(1, leer(miniatura).getHeight());
    }

    @Test
    void unaImagenMuyAltaConservaLaProporcionConAlMenosUnPixel() throws Exception {
        // 2000 x 10 baja a 640 x 3,2: se redondea a 3.
        var miniatura = generar(png(solida(2000, 10, Color.GRAY)));

        assertEquals(640, leer(miniatura).getWidth());
        assertEquals(3, leer(miniatura).getHeight());
    }

    @Test
    void laSalidaEsUnJpeg() throws Exception {
        var miniatura = generar(png(solida(1000, 500, Color.GRAY)));

        assertEquals((byte) 0xFF, miniatura[0]);
        assertEquals((byte) 0xD8, miniatura[1]);
        try (var entrada = ImageIO.createImageInputStream(new ByteArrayInputStream(miniatura))) {
            assertEquals("JPEG", ImageIO.getImageReaders(entrada).next().getFormatName().toUpperCase());
        }
    }

    // --- alfa ---

    @Test
    void unPngConAlfaSeAplanaSobreFondoBlanco() throws Exception {
        var origen = new BufferedImage(100, 100, BufferedImage.TYPE_INT_ARGB);
        for (int y = 0; y < 100; y++) {
            for (int x = 0; x < 100; x++) {
                // Mitad izquierda transparente, mitad derecha azul opaco.
                origen.setRGB(x, y, x < 50 ? 0x00000000 : 0xFF0000FF);
            }
        }

        var miniatura = leer(generar(png(origen)));

        assertCerca(BLANCO, miniatura.getRGB(25, 50));
        assertCerca(AZUL, miniatura.getRGB(75, 50));
    }

    // --- orientacion EXIF ---

    @Test
    void sinExifLaImagenQuedaComoEstaConSusCuadrantes() throws Exception {
        var miniatura = leer(generar(jpeg(cuadrantes(300, 200))));

        assertEquals(300, miniatura.getWidth());
        assertEquals(200, miniatura.getHeight());
        assertCuadrantes(miniatura, ROJO, VERDE, AZUL, AMARILLO);
    }

    @Test
    void laOrientacionEsperadaParaCadaValorDeExif() throws Exception {
        // Origen 300 x 200 con arriba-izquierda rojo, arriba-derecha verde, abajo-izquierda azul y abajo-derecha
        // amarillo. Cada fila es lo que debe verse tras corregir: ancho, alto y colores en el orden
        // arriba-izquierda, arriba-derecha, abajo-izquierda, abajo-derecha.
        int[][] esperado = {
            {1, 300, 200, ROJO, VERDE, AZUL, AMARILLO},
            {2, 300, 200, VERDE, ROJO, AMARILLO, AZUL},
            {3, 300, 200, AMARILLO, AZUL, VERDE, ROJO},
            {4, 300, 200, AZUL, AMARILLO, ROJO, VERDE},
            {5, 200, 300, ROJO, AZUL, VERDE, AMARILLO},
            {6, 200, 300, AZUL, ROJO, AMARILLO, VERDE},
            {7, 200, 300, AMARILLO, VERDE, AZUL, ROJO},
            {8, 200, 300, VERDE, AMARILLO, ROJO, AZUL},
        };
        for (int[] fila : esperado) {
            var miniatura = leer(generar(conExifGrande(jpeg(cuadrantes(300, 200)), fila[0])));

            assertEquals(fila[1], miniatura.getWidth(), "ancho con orientacion " + fila[0]);
            assertEquals(fila[2], miniatura.getHeight(), "alto con orientacion " + fila[0]);
            assertCuadrantes(miniatura, fila[3], fila[4], fila[5], fila[6]);
        }
    }

    @Test
    void laOrientacionEnOrdenDeBytesPequenoTambienSeLee() throws Exception {
        // Mismo origen con rotacion 6 pero con el encabezado "II" (little endian).
        var miniatura = leer(generar(conExifPequeno(jpeg(cuadrantes(300, 200)), 6)));

        assertEquals(200, miniatura.getWidth());
        assertEquals(300, miniatura.getHeight());
        assertCuadrantes(miniatura, AZUL, ROJO, AMARILLO, VERDE);
    }

    @Test
    void laRotacionDeUnaImagenGrandeUsaElAnchoYaRotadoParaEscalar() throws Exception {
        // Origen 3000 x 2000 con orientacion 6: se ve de 2000 x 3000 y baja a 640 x 960.
        var miniatura = leer(generar(conExifGrande(jpeg(cuadrantes(3000, 2000)), 6)));

        assertEquals(640, miniatura.getWidth());
        assertEquals(960, miniatura.getHeight());
        assertCuadrantes(miniatura, AZUL, ROJO, AMARILLO, VERDE);
    }

    @Test
    void unValorDeOrientacionFueraDeRangoSeIgnora() throws Exception {
        var miniatura = leer(generar(conExifGrande(jpeg(cuadrantes(300, 200)), 9)));

        assertEquals(300, miniatura.getWidth());
        assertEquals(200, miniatura.getHeight());
        assertCuadrantes(miniatura, ROJO, VERDE, AZUL, AMARILLO);
    }

    // --- imagenes que no se pueden procesar ---

    @Test
    void bytesQueNoSonUnaImagenDevuelvenVacioSinLanzar() {
        assertEquals(Optional.empty(), Miniaturas.generar("esto no es una imagen".getBytes(StandardCharsets.UTF_8)));
        assertEquals(Optional.empty(), Miniaturas.generar(new byte[0]));
    }

    @Test
    void unEncabezadoPngConBasuraDevuelveVacioSinLanzar() {
        byte[] basura = {(byte) 0x89, 'P', 'N', 'G', 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3, 4, 5, 6, 7, 8};

        assertEquals(Optional.empty(), Miniaturas.generar(basura));
    }

    @Test
    void unJpegCmykDevuelveVacioSinLanzar() throws Exception {
        assertEquals(Optional.empty(), Miniaturas.generar(jpegCmyk(40, 30)));
    }

    // --- referencia derivada ---

    @Test
    void laReferenciaDeUnPngSeDerivaConPrefijoMiniYExtensionJpg() {
        assertEquals("mini/123e4567-e89b-12d3-a456-426614174000.jpg",
                Miniaturas.referencia("123e4567-e89b-12d3-a456-426614174000.png"));
    }

    @Test
    void laReferenciaDeUnJpgSeDerivaConPrefijoMiniYExtensionJpg() {
        assertEquals("mini/123e4567-e89b-12d3-a456-426614174000.jpg",
                Miniaturas.referencia("123e4567-e89b-12d3-a456-426614174000.jpg"));
    }

    // --- ayudas de la prueba (no usan el codigo que se prueba) ---

    private static byte[] generar(byte[] origen) {
        Optional<byte[]> miniatura = Miniaturas.generar(origen);
        assertTrue(miniatura.isPresent(), "se esperaba una miniatura");
        return miniatura.get();
    }

    private static BufferedImage leer(byte[] bytes) throws Exception {
        var imagen = ImageIO.read(new ByteArrayInputStream(bytes));
        assertNotNull(imagen, "la miniatura no se puede leer");
        return imagen;
    }

    private static BufferedImage solida(int ancho, int alto, Color color) {
        var imagen = new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB);
        var g = imagen.createGraphics();
        g.setColor(color);
        g.fillRect(0, 0, ancho, alto);
        g.dispose();
        return imagen;
    }

    private static BufferedImage grisSolida(int ancho, int alto) {
        var imagen = new BufferedImage(ancho, alto, BufferedImage.TYPE_BYTE_GRAY);
        var g = imagen.createGraphics();
        g.setColor(Color.GRAY);
        g.fillRect(0, 0, ancho, alto);
        g.dispose();
        return imagen;
    }

    /** Arriba-izquierda rojo, arriba-derecha verde, abajo-izquierda azul, abajo-derecha amarillo. */
    private static BufferedImage cuadrantes(int ancho, int alto) {
        var imagen = new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB);
        var g = imagen.createGraphics();
        g.setColor(new Color(ROJO));
        g.fillRect(0, 0, ancho / 2, alto / 2);
        g.setColor(new Color(VERDE));
        g.fillRect(ancho / 2, 0, ancho - ancho / 2, alto / 2);
        g.setColor(new Color(AZUL));
        g.fillRect(0, alto / 2, ancho / 2, alto - alto / 2);
        g.setColor(new Color(AMARILLO));
        g.fillRect(ancho / 2, alto / 2, ancho - ancho / 2, alto - alto / 2);
        g.dispose();
        return imagen;
    }

    private static byte[] png(BufferedImage imagen) throws Exception {
        var salida = new ByteArrayOutputStream();
        ImageIO.write(imagen, "png", salida);
        return salida.toByteArray();
    }

    private static byte[] jpeg(BufferedImage imagen) throws Exception {
        var salida = new ByteArrayOutputStream();
        ImageIO.write(imagen, "jpg", salida);
        return salida.toByteArray();
    }

    /** Un JPEG de cuatro bandas, que ImageIO lee como CMYK. */
    private static byte[] jpegCmyk(int ancho, int alto) throws Exception {
        WritableRaster raster = Raster.createInterleavedRaster(DataBuffer.TYPE_BYTE, ancho, alto, 4, null);
        var escritor = ImageIO.getImageWritersByFormatName("jpeg").next();
        var salida = new ByteArrayOutputStream();
        try (var flujo = new MemoryCacheImageOutputStream(salida)) {
            escritor.setOutput(flujo);
            escritor.write(null, new IIOImage(raster, null, null), null);
        } finally {
            escritor.dispose();
        }
        return salida.toByteArray();
    }

    /** Inserta tras el SOI un segmento APP1 Exif con solo la etiqueta 0x0112, en orden de bytes grande ("MM"). */
    private static byte[] conExifGrande(byte[] jpeg, int orientacion) {
        byte[] segmento = {
            (byte) 0xFF, (byte) 0xE1, 0x00, 0x22,
            'E', 'x', 'i', 'f', 0x00, 0x00,
            'M', 'M', 0x00, 0x2A, 0x00, 0x00, 0x00, 0x08,
            0x00, 0x01,
            0x01, 0x12, 0x00, 0x03, 0x00, 0x00, 0x00, 0x01, 0x00, (byte) orientacion, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        };
        return insertarTrasSoi(jpeg, segmento);
    }

    /** Igual que {@link #conExifGrande} pero en orden de bytes pequeno ("II"). */
    private static byte[] conExifPequeno(byte[] jpeg, int orientacion) {
        byte[] segmento = {
            (byte) 0xFF, (byte) 0xE1, 0x00, 0x22,
            'E', 'x', 'i', 'f', 0x00, 0x00,
            'I', 'I', 0x2A, 0x00, 0x08, 0x00, 0x00, 0x00,
            0x01, 0x00,
            0x12, 0x01, 0x03, 0x00, 0x01, 0x00, 0x00, 0x00, (byte) orientacion, 0x00, 0x00, 0x00,
            0x00, 0x00, 0x00, 0x00,
        };
        return insertarTrasSoi(jpeg, segmento);
    }

    private static byte[] insertarTrasSoi(byte[] jpeg, byte[] segmento) {
        assertEquals((byte) 0xFF, jpeg[0]);
        assertEquals((byte) 0xD8, jpeg[1]);
        var salida = new ByteArrayOutputStream();
        salida.write(jpeg, 0, 2);
        salida.write(segmento, 0, segmento.length);
        salida.write(jpeg, 2, jpeg.length - 2);
        return salida.toByteArray();
    }

    /** Comprueba el color en el centro de cada cuadrante, lejos de los bordes donde JPEG mezcla. */
    private static void assertCuadrantes(BufferedImage imagen, int arribaIzq, int arribaDer, int abajoIzq,
                                         int abajoDer) {
        int ancho = imagen.getWidth();
        int alto = imagen.getHeight();
        assertCerca(arribaIzq, imagen.getRGB(ancho / 4, alto / 4));
        assertCerca(arribaDer, imagen.getRGB(3 * ancho / 4, alto / 4));
        assertCerca(abajoIzq, imagen.getRGB(ancho / 4, 3 * alto / 4));
        assertCerca(abajoDer, imagen.getRGB(3 * ancho / 4, 3 * alto / 4));
    }

    private static void assertCerca(int esperado, int real) {
        for (int desplazamiento : new int[] {16, 8, 0}) {
            int e = (esperado >> desplazamiento) & 0xFF;
            int r = (real >> desplazamiento) & 0xFF;
            assertTrue(Math.abs(e - r) <= 60, String.format("color esperado %06X y real %06X", esperado, real & 0xFFFFFF));
        }
    }
}
