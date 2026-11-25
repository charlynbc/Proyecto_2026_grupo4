package uy.edu.proyecto.backend.anuncio;

import java.awt.Color;
import java.awt.image.BufferedImage;
import java.awt.image.DataBuffer;
import java.awt.image.Raster;
import java.io.ByteArrayInputStream;
import java.io.ByteArrayOutputStream;
import javax.imageio.IIOImage;
import javax.imageio.ImageIO;
import javax.imageio.stream.MemoryCacheImageOutputStream;

/** Imagenes reales y chicas armadas con ImageIO para las pruebas de las miniaturas. */
final class ImagenesDePrueba {
    private ImagenesDePrueba() { }

    static byte[] png(int ancho, int alto) {
        return escribir(ancho, alto, "png");
    }

    static byte[] jpeg(int ancho, int alto) {
        return escribir(ancho, alto, "jpg");
    }

    /** Un JPEG de cuatro bandas: pasa la validacion de la novedad pero no se puede reducir a miniatura. */
    static byte[] jpegCmyk(int ancho, int alto) {
        try {
            var raster = Raster.createInterleavedRaster(DataBuffer.TYPE_BYTE, ancho, alto, 4, null);
            var escritor = ImageIO.getImageWritersByFormatName("jpeg").next();
            var salida = new ByteArrayOutputStream();
            try (var flujo = new MemoryCacheImageOutputStream(salida)) {
                escritor.setOutput(flujo);
                escritor.write(null, new IIOImage(raster, null, null), null);
            } finally {
                escritor.dispose();
            }
            return salida.toByteArray();
        } catch (java.io.IOException error) {
            throw new IllegalStateException(error);
        }
    }

    static java.awt.Dimension dimensiones(byte[] imagen) {
        try {
            var leida = ImageIO.read(new ByteArrayInputStream(imagen));
            return new java.awt.Dimension(leida.getWidth(), leida.getHeight());
        } catch (java.io.IOException error) {
            throw new IllegalStateException(error);
        }
    }

    private static byte[] escribir(int ancho, int alto, String formato) {
        try {
            var imagen = new BufferedImage(ancho, alto, BufferedImage.TYPE_INT_RGB);
            var g = imagen.createGraphics();
            g.setColor(Color.ORANGE);
            g.fillRect(0, 0, ancho, alto);
            g.dispose();
            var salida = new ByteArrayOutputStream();
            ImageIO.write(imagen, formato, salida);
            return salida.toByteArray();
        } catch (java.io.IOException error) {
            throw new IllegalStateException(error);
        }
    }
}
