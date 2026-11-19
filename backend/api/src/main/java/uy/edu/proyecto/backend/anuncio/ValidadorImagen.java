package uy.edu.proyecto.backend.anuncio;

import java.io.IOException;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import org.springframework.http.HttpStatus;
import org.springframework.web.multipart.MultipartFile;
import uy.edu.proyecto.backend.exception.ApiException;

/** Reglas de las imagenes de una novedad, las mismas al publicar y al editar. */
final class ValidadorImagen {
    static final long MAX_BYTES = 5L * 1024L * 1024L;
    static final int MAX_LADO = 6000;
    static final int MAX_IMAGENES = 5;

    record Contenido(byte[] bytes, String tipo, String extension) { }

    private ValidadorImagen() { }

    static Contenido validar(MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty()) {
            throw validacion("Cada imagen debe tener contenido");
        }
        if (archivo.getSize() > MAX_BYTES) {
            throw new ApiException(HttpStatus.BAD_REQUEST, ErroresImagen.CODIGO, ErroresImagen.TAMANO);
        }
        String tipo = archivo.getContentType();
        if (!"image/jpeg".equals(tipo) && !"image/png".equals(tipo)) {
            throw validacion("Solo se admiten imágenes JPEG o PNG");
        }
        try {
            byte[] bytes = archivo.getBytes();
            try (ImageInputStream entrada = ImageIO.createImageInputStream(new java.io.ByteArrayInputStream(bytes))) {
                if (entrada == null) throw validacion("La imagen no es válida");
                var lectores = ImageIO.getImageReaders(entrada);
                if (!lectores.hasNext()) throw validacion("La imagen no es válida");
                ImageReader lector = lectores.next();
                try {
                    lector.setInput(entrada);
                    String formato = lector.getFormatName();
                    if (!("image/jpeg".equals(tipo) && "JPEG".equalsIgnoreCase(formato))
                            && !("image/png".equals(tipo) && "PNG".equalsIgnoreCase(formato))) {
                        throw validacion("El contenido de la imagen no coincide con su formato");
                    }
                    if (lector.getWidth(0) > MAX_LADO || lector.getHeight(0) > MAX_LADO) {
                        throw validacion("La imagen supera las dimensiones permitidas");
                    }
                } finally { lector.dispose(); }
            }
            return new Contenido(bytes, tipo, "image/png".equals(tipo) ? ".png" : ".jpg");
        } catch (IOException error) {
            throw validacion("No se pudo leer la imagen");
        }
    }

    private static ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
