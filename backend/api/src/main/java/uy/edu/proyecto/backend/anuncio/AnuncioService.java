package uy.edu.proyecto.backend.anuncio;

import java.io.IOException;
import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import javax.imageio.ImageIO;
import javax.imageio.ImageReader;
import javax.imageio.stream.ImageInputStream;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;
import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class AnuncioService {
    private static final long MAX_BYTES = 5L * 1024L * 1024L;
    private final AnuncioRepository repository;
    private final AlmacenImagenes almacen;

    public AnuncioService(AnuncioRepository repository, AlmacenImagenes almacen) {
        this.repository = repository;
        this.almacen = almacen;
    }

    @Transactional
    public AnuncioDTO.Detalle publicar(long administradorId, AnuncioDTO.Datos datos,
                                      List<MultipartFile> imagenes) {
        if (datos == null || datos.titulo() == null || datos.titulo().isBlank()
                || datos.titulo().trim().length() > 160) {
            throw validacion("El título es obligatorio y admite hasta 160 caracteres");
        }
        if (datos.resumen() != null && datos.resumen().length() > 300) {
            throw validacion("El resumen admite hasta 300 caracteres");
        }
        if (imagenes == null || imagenes.isEmpty() || imagenes.size() > 5) {
            throw validacion("El anuncio requiere entre 1 y 5 imágenes");
        }
        List<Contenido> contenidos = imagenes.stream().map(this::validarImagen).toList();
        var normalizados = new AnuncioDTO.Datos(datos.titulo().trim(),
                datos.resumen() == null || datos.resumen().isBlank() ? null : datos.resumen().trim(),
                datos.texto() == null || datos.texto().isBlank() ? null : datos.texto().trim());
        List<String> cargadas = new ArrayList<>();
        boolean limpiezaRegistrada = false;
        try {
            for (Contenido contenido : contenidos) {
                String referencia = UUID.randomUUID() + contenido.extension();
                cargadas.add(referencia);
                almacen.guardar(referencia, contenido.bytes(), contenido.tipo());
            }
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCompletion(int estado) {
                    if (estado != STATUS_COMMITTED) limpiar(cargadas);
                }
            });
            limpiezaRegistrada = true;
            long id = repository.crear(administradorId, normalizados);
            for (int i = 0; i < cargadas.size(); i++) repository.agregarImagen(id, cargadas.get(i), i);
            return detalle(id);
        } catch (RuntimeException error) {
            if (!limpiezaRegistrada) limpiar(cargadas);
            throw error;
        }
    }

    @Transactional(readOnly = true)
    public AnuncioDTO.Pagina listar(int page, int size) {
        if (page < 0 || size < 1 || size > 100 || (long) page * size > Integer.MAX_VALUE) {
            throw validacion("page debe ser mayor o igual a 0 y size debe estar entre 1 y 100");
        }
        var items = repository.listar(page, size).stream().map(fila -> {
            var imagenes = repository.imagenes(fila.id());
            AnuncioDTO.Imagen portada = imagenes.isEmpty() ? null : imagen(imagenes.getFirst());
            return new AnuncioDTO.Tarjeta(fila.id(), fila.titulo(), fila.resumen(),
                    fila.publicadoEn(), portada);
        }).toList();
        return new AnuncioDTO.Pagina(items, page, size, repository.total());
    }

    @Transactional(readOnly = true)
    public AnuncioDTO.Detalle detalle(long id) {
        if (id <= 0) throw noEncontrado();
        var fila = repository.buscar(id);
        if (fila == null) throw noEncontrado();
        return new AnuncioDTO.Detalle(fila.id(), fila.titulo(), fila.resumen(),
                fila.texto(), fila.publicadoEn(), repository.imagenes(id).stream()
                        .map(this::imagen).toList());
    }

    private AnuncioDTO.Imagen imagen(AnuncioRepository.ImagenFila fila) {
        return new AnuncioDTO.Imagen(fila.id(), fila.orden(), almacen.enlaceTemporal(fila.referencia()));
    }

    private record Contenido(byte[] bytes, String tipo, String extension) { }

    private Contenido validarImagen(MultipartFile archivo) {
        if (archivo == null || archivo.isEmpty() || archivo.getSize() > MAX_BYTES) {
            throw validacion("Cada imagen debe tener contenido y ocupar como máximo 5 MB");
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
                    if (lector.getWidth(0) > 6000 || lector.getHeight(0) > 6000) {
                        throw validacion("La imagen supera las dimensiones permitidas");
                    }
                } finally { lector.dispose(); }
            }
            return new Contenido(bytes, tipo, "image/png".equals(tipo) ? ".png" : ".jpg");
        } catch (IOException error) {
            throw validacion("No se pudo leer la imagen");
        }
    }

    private void limpiar(List<String> referencias) {
        for (String referencia : referencias) {
            try { almacen.borrar(referencia); } catch (RuntimeException ignored) { /* Mejor esfuerzo. */ }
        }
    }

    private static ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }

    private static ApiException noEncontrado() {
        return new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO", "Anuncio no encontrado");
    }
}
