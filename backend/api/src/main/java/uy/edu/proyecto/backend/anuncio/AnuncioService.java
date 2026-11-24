package uy.edu.proyecto.backend.anuncio;

import java.util.ArrayList;
import java.util.List;
import java.util.UUID;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionSynchronization;
import org.springframework.transaction.support.TransactionSynchronizationManager;
import org.springframework.web.multipart.MultipartFile;
import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class AnuncioService {
        private final AnuncioRepository repository;
    private final AlmacenImagenes almacen;

    public AnuncioService(AnuncioRepository repository, AlmacenImagenes almacen) {
        this.repository = repository;
        this.almacen = almacen;
    }

    @Transactional
    public AnuncioDTO.Detalle publicar(long administradorId, AnuncioDTO.Datos datos,
                                      List<MultipartFile> imagenes) {
        validarTituloYResumen(datos == null ? null : datos.titulo(), datos == null ? null : datos.resumen());
        if (datos.vigenteHasta() == null || !datos.vigenteHasta().isAfter(
                datos.vigenteDesde() == null ? java.time.OffsetDateTime.now() : datos.vigenteDesde())) {
            throw validacion("La fecha de fin es obligatoria y debe ser posterior al inicio");
        }
        var normalizados = new AnuncioDTO.Datos(datos.titulo().trim(),
                datos.resumen() == null || datos.resumen().isBlank() ? null : datos.resumen().trim(),
                datos.texto() == null || datos.texto().isBlank() ? null : datos.texto().trim(),
                datos.vigenteDesde(), datos.vigenteHasta());
        if (imagenes == null || imagenes.isEmpty()) {
            if (normalizados.texto() == null) {
                throw validacion("El anuncio debe incluir texto o al menos una imagen");
            }
            return detalleInterno(repository.crear(administradorId, normalizados), false);
        }
        if (imagenes.size() > 5) {
            throw validacion("El anuncio admite hasta 5 imágenes");
        }
        List<ValidadorImagen.Contenido> contenidos = imagenes.stream().map(ValidadorImagen::validar).toList();
        // Los originales van a la base; subidas suma las miniaturas para limpiar todo si algo falla.
        List<String> cargadas = new ArrayList<>();
        List<String> subidas = new ArrayList<>();
        boolean limpiezaRegistrada = false;
        try {
            for (ValidadorImagen.Contenido contenido : contenidos) {
                String referencia = UUID.randomUUID() + contenido.extension();
                cargadas.add(referencia);
                subidas.add(referencia);
                almacen.guardar(referencia, contenido.bytes(), contenido.tipo());
                Miniaturas.subir(almacen, referencia, contenido.bytes(), subidas);
            }
            TransactionSynchronizationManager.registerSynchronization(new TransactionSynchronization() {
                @Override public void afterCompletion(int estado) {
                    if (estado != STATUS_COMMITTED) limpiar(subidas);
                }
            });
            limpiezaRegistrada = true;
            long id = repository.crear(administradorId, normalizados);
            for (int i = 0; i < cargadas.size(); i++) repository.agregarImagen(id, cargadas.get(i), i);
            return detalleInterno(id, false);
        } catch (RuntimeException error) {
            if (!limpiezaRegistrada) limpiar(subidas);
            throw error;
        }
    }

    /**
     * Valida y normaliza el texto de una novedad con las mismas reglas de titulo y resumen que al publicar:
     * recorta los espacios y un resumen o texto en blanco queda nulo.
     */
    public static AnuncioDTO.Edicion normalizarTexto(AnuncioDTO.Edicion datos) {
        validarTituloYResumen(datos == null ? null : datos.titulo(), datos == null ? null : datos.resumen());
        return new AnuncioDTO.Edicion(datos.titulo().trim(), blancoANulo(datos.resumen()), blancoANulo(datos.texto()));
    }

    private static void validarTituloYResumen(String titulo, String resumen) {
        if (titulo == null || titulo.isBlank() || titulo.trim().length() > 160) {
            throw validacion("El título es obligatorio y admite hasta 160 caracteres");
        }
        if (resumen != null && resumen.length() > 300) {
            throw validacion("El resumen admite hasta 300 caracteres");
        }
    }

    private static String blancoANulo(String valor) {
        return valor == null || valor.isBlank() ? null : valor.trim();
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
        return detalleInterno(id, true);
    }

    /** El detalle de cualquier anuncio, vigente o no. Solo para la administracion. */
    @Transactional(readOnly = true)
    public AnuncioDTO.Detalle detalleCualquiera(long id) {
        return detalleInterno(id, false);
    }

    private AnuncioDTO.Detalle detalleInterno(long id, boolean vigente) {
        if (id <= 0) throw noEncontrado();
        var fila = vigente ? repository.buscar(id) : repository.buscarCualquiera(id);
        if (fila == null) throw noEncontrado();
        return new AnuncioDTO.Detalle(fila.id(), fila.titulo(), fila.resumen(),
                fila.texto(), fila.publicadoEn(), repository.imagenes(id).stream()
                        .map(this::imagen).toList());
    }

    private AnuncioDTO.Imagen imagen(AnuncioRepository.ImagenFila fila) {
        // Si falla la firma del original es el error de siempre; la de la miniatura nunca rompe la respuesta.
        String url = almacen.enlaceTemporal(fila.referencia());
        return new AnuncioDTO.Imagen(fila.id(), fila.orden(), url,
                Miniaturas.enlace(almacen, fila.referencia()));
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
