package uy.edu.proyecto.backend.anuncio;

import java.awt.RenderingHints;
import java.awt.color.ColorSpace;
import java.awt.geom.AffineTransform;
import java.awt.image.BufferedImage;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import java.io.IOException;
import java.util.Collection;
import java.util.Optional;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.ImageWriteParam;
import javax.imageio.ImageWriter;
import javax.imageio.stream.MemoryCacheImageInputStream;
import javax.imageio.stream.MemoryCacheImageOutputStream;
import org.slf4j.Logger;
import org.slf4j.LoggerFactory;

/**
 * Miniatura de la imagen de una novedad: JPEG de hasta {@value #ANCHO_MAXIMO} px de ancho, sin agrandar, con la
 * orientacion EXIF corregida y el alfa aplanado sobre blanco.
 *
 * <p>Se decodifica con submuestreo y con flujos en memoria, de modo que una imagen de 6000 x 6000 no se carga entera
 * ni usa archivos temporales.</p>
 */
final class Miniaturas {
    static final int ANCHO_MAXIMO = 640;
    static final float CALIDAD = 0.8f;
    static final String PREFIJO = "mini/";
    private static final Logger LOG = LoggerFactory.getLogger(Miniaturas.class);

    private Miniaturas() { }

    /** La referencia de la miniatura de un original: {@code mini/<uuid>.jpg}, siempre JPEG. */
    static String referencia(String referenciaOriginal) {
        int punto = referenciaOriginal.lastIndexOf('.');
        String base = punto < 0 ? referenciaOriginal : referenciaOriginal.substring(0, punto);
        return PREFIJO + base + ".jpg";
    }

    /**
     * Genera y sube la miniatura de un original que ya esta en Storage. Anota la referencia en {@code subidas}
     * antes de subirla, para que la limpieza por un fallo posterior la incluya. Si no se puede generar o subir, el
     * original queda sin miniatura y no se lanza nada.
     */
    static void subir(AlmacenImagenes almacen, String referenciaOriginal, byte[] original, Collection<String> subidas) {
        Optional<byte[]> miniatura = generar(original);
        if (miniatura.isEmpty()) return;
        String referencia = referencia(referenciaOriginal);
        subidas.add(referencia);
        try {
            almacen.guardar(referencia, miniatura.get(), "image/jpeg");
        } catch (RuntimeException error) {
            LOG.warn("No se pudo subir la miniatura de una imagen ({})", error.getClass().getSimpleName());
        }
    }

    /** Borra la miniatura de un original, de mejor esfuerzo: si falla se registra y no se lanza nada. */
    static void borrar(AlmacenImagenes almacen, String referenciaOriginal) {
        try {
            almacen.borrar(referencia(referenciaOriginal));
        } catch (RuntimeException error) {
            LOG.warn("No se pudo borrar la miniatura de una imagen ({})", error.getClass().getSimpleName());
        }
    }

    /** La miniatura JPEG del original, o vacio si la imagen no se puede procesar. Nunca lanza. */
    static Optional<byte[]> generar(byte[] original) {
        try {
            return Optional.ofNullable(construir(original));
        } catch (IOException | RuntimeException error) {
            LOG.warn("No se pudo generar la miniatura de una imagen ({})", error.getClass().getSimpleName());
            return Optional.empty();
        }
    }

    private static byte[] construir(byte[] original) throws IOException {
        try (var entrada = new MemoryCacheImageInputStream(new ByteArrayInputStream(original))) {
            var lectores = ImageIO.getImageReaders(entrada);
            if (!lectores.hasNext()) return null;
            ImageReader lector = lectores.next();
            try {
                lector.setInput(entrada, true, true);
                int ancho = lector.getWidth(0);
                int alto = lector.getHeight(0);
                if (ancho < 1 || alto < 1) return null;
                int orientacion = "JPEG".equalsIgnoreCase(lector.getFormatName()) ? orientacion(original) : 1;
                boolean girada = orientacion >= 5;
                int anchoVisible = girada ? alto : ancho;
                int altoVisible = girada ? ancho : alto;
                int anchoFinal = Math.min(ANCHO_MAXIMO, anchoVisible);
                int altoFinal = Math.max(1, (int) Math.round(altoVisible * (double) anchoFinal / anchoVisible));

                // Se deja al menos el doble del ancho final para que el reescalado promedie los pixeles.
                int salto = Math.max(1, anchoVisible / (2 * ANCHO_MAXIMO));
                var parametros = lector.getDefaultReadParam();
                parametros.setSourceSubsampling(salto, salto, 0, 0);
                BufferedImage leida = lector.read(0, parametros);
                if (esCmyk(leida)) return null;

                BufferedImage reducida = escalar(leida, girada ? altoFinal : anchoFinal,
                        girada ? anchoFinal : altoFinal);
                return codificar(orientar(reducida, orientacion));
            } finally {
                lector.dispose();
            }
        }
    }

    private static boolean esCmyk(BufferedImage imagen) {
        return imagen.getColorModel().getColorSpace().getType() == ColorSpace.TYPE_CMYK
                || imagen.getColorModel().getNumColorComponents() == 4;
    }

    /** Pasa a RGB sobre fondo blanco y baja al tamano pedido, de a mitades para que se promedien los pixeles. */
    private static BufferedImage escalar(BufferedImage origen, int ancho, int alto) {
        BufferedImage actual = origen;
        while (actual.getWidth() >= 2 * ancho && actual.getHeight() >= 2 * alto) {
            actual = redibujar(actual, actual.getWidth() / 2, actual.getHeight() / 2);
        }
        if (actual.getWidth() != ancho || actual.getHeight() != alto || actual.getType() != BufferedImage.TYPE_INT_RGB) {
            actual = redibujar(actual, ancho, alto);
        }
        return actual;
    }

    private static BufferedImage redibujar(BufferedImage origen, int ancho, int alto) {
        var destino = new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB);
        var g = destino.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_BILINEAR);
            g.setColor(java.awt.Color.WHITE);
            g.fillRect(0, 0, ancho, alto);
            g.drawImage(origen, 0, 0, ancho, alto, null);
        } finally {
            g.dispose();
        }
        return destino;
    }

    /** Aplica la orientacion EXIF de 1 a 8; cualquier otro valor deja la imagen igual. */
    private static BufferedImage orientar(BufferedImage imagen, int orientacion) {
        if (orientacion < 2 || orientacion > 8) return imagen;
        int w = imagen.getWidth();
        int h = imagen.getHeight();
        AffineTransform transformacion = switch (orientacion) {
            case 2 -> new AffineTransform(-1, 0, 0, 1, w, 0);
            case 3 -> new AffineTransform(-1, 0, 0, -1, w, h);
            case 4 -> new AffineTransform(1, 0, 0, -1, 0, h);
            case 5 -> new AffineTransform(0, 1, 1, 0, 0, 0);
            case 6 -> new AffineTransform(0, 1, -1, 0, h, 0);
            case 7 -> new AffineTransform(0, -1, -1, 0, h, w);
            default -> new AffineTransform(0, -1, 1, 0, 0, w);
        };
        boolean girada = orientacion >= 5;
        var destino = new BufferedImage(girada ? h : w, girada ? w : h, BufferedImage.TYPE_INT_RGB);
        var g = destino.createGraphics();
        try {
            g.setRenderingHint(RenderingHints.KEY_INTERPOLATION, RenderingHints.VALUE_INTERPOLATION_NEAREST_NEIGHBOR);
            g.drawImage(imagen, transformacion, null);
        } finally {
            g.dispose();
        }
        return destino;
    }

    private static byte[] codificar(BufferedImage imagen) throws IOException {
        ImageWriter escritor = ImageIO.getImageWritersByFormatName("jpeg").next();
        var salida = new ByteArrayOutputStream();
        try (var flujo = new MemoryCacheImageOutputStream(salida)) {
            ImageWriteParam parametros = escritor.getDefaultWriteParam();
            parametros.setCompressionMode(ImageWriteParam.MODE_EXPLICIT);
            parametros.setCompressionQuality(CALIDAD);
            escritor.setOutput(flujo);
            escritor.write(null, new IIOImage(imagen, null, null), parametros);
        } finally {
            escritor.dispose();
        }
        return salida.toByteArray();
    }

    /**
     * La orientacion EXIF (etiqueta 0x0112) del segmento APP1 de un JPEG, de 1 a 8. Devuelve 1 si no hay etiqueta,
     * si el valor esta fuera de rango o si el segmento esta mal formado.
     */
    static int orientacion(byte[] jpeg) {
        if (jpeg.length < 4 || (jpeg[0] & 0xFF) != 0xFF || (jpeg[1] & 0xFF) != 0xD8) return 1;
        int posicion = 2;
        while (posicion + 4 <= jpeg.length) {
            if ((jpeg[posicion] & 0xFF) != 0xFF) return 1;
            int marcador = jpeg[posicion + 1] & 0xFF;
            if (marcador == 0xFF) {
                posicion++;
                continue;
            }
            if (marcador == 0x01 || (marcador >= 0xD0 && marcador <= 0xD8)) {
                posicion += 2;
                continue;
            }
            if (marcador == 0xDA || marcador == 0xD9) return 1;
            int largo = ((jpeg[posicion + 2] & 0xFF) << 8) | (jpeg[posicion + 3] & 0xFF);
            if (largo < 2) return 1;
            if (marcador == 0xE1) {
                int fin = Math.min(jpeg.length, posicion + 2 + largo);
                int valor = leerOrientacion(jpeg, posicion + 4, fin);
                if (valor != 0) return valor;
            }
            posicion += 2 + largo;
        }
        return 1;
    }

    /** Lee la etiqueta en el segmento Exif entre {@code inicio} y {@code fin}; 0 si ese segmento no la trae. */
    private static int leerOrientacion(byte[] datos, int inicio, int fin) {
        if (inicio + 14 > fin) return 0;
        String cabecera = new String(datos, inicio, 6, java.nio.charset.StandardCharsets.ISO_8859_1);
        if (!"Exif\0\0".equals(cabecera)) return 0;
        int tiff = inicio + 6;
        boolean grande;
        if (datos[tiff] == 'M' && datos[tiff + 1] == 'M') grande = true;
        else if (datos[tiff] == 'I' && datos[tiff + 1] == 'I') grande = false;
        else return 0;
        if (entero16(datos, tiff + 2, grande) != 42) return 0;
        long desplazamiento = entero32(datos, tiff + 4, grande);
        long directorio = tiff + desplazamiento;
        if (directorio < tiff || directorio + 2 > fin) return 0;
        int cantidad = entero16(datos, (int) directorio, grande);
        for (int i = 0; i < cantidad; i++) {
            long entrada = directorio + 2 + 12L * i;
            if (entrada + 12 > fin) return 0;
            if (entero16(datos, (int) entrada, grande) == 0x0112) {
                int valor = entero16(datos, (int) entrada + 8, grande);
                return valor >= 1 && valor <= 8 ? valor : 1;
            }
        }
        return 0;
    }

    private static int entero16(byte[] datos, int posicion, boolean grande) {
        int a = datos[posicion] & 0xFF;
        int b = datos[posicion + 1] & 0xFF;
        return grande ? (a << 8) | b : (b << 8) | a;
    }

    private static long entero32(byte[] datos, int posicion, boolean grande) {
        long alto = entero16(datos, grande ? posicion : posicion + 2, grande);
        long bajo = entero16(datos, grande ? posicion + 2 : posicion, grande);
        return (alto << 16) | bajo;
    }
}
