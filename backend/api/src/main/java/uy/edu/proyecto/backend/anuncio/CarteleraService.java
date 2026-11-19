package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.Collection;
import java.util.HashSet;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Map;
import java.util.UUID;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.PlatformTransactionManager;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.TransactionTemplate;
import org.springframework.web.multipart.MultipartFile;
import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class CarteleraService {
    private final CarteleraRepository repo;
    private final AnuncioService anuncios;
    private final AlmacenImagenes almacen;
    public CarteleraService(CarteleraRepository repo, AnuncioService anuncios, AlmacenImagenes almacen) {
        this.repo=repo; this.anuncios=anuncios; this.almacen=almacen;
    }
    @Transactional(readOnly=true)
    public List<AnuncioDTO.Administracion> listar() { return repo.listar(); }
    @Transactional(readOnly=true)
    public AnuncioDTO.DetalleAdministracion detalle(long id) {
        var fila=repo.administracion(id);
        if (fila==null) throw error(HttpStatus.NOT_FOUND,"NO_ENCONTRADO","Anuncio no encontrado");
        var d=anuncios.detalleCualquiera(id);
        return new AnuncioDTO.DetalleAdministracion(d.id(),d.titulo(),d.resumen(),d.texto(),d.publicadoEn(),
                fila.vigenteDesde(),fila.vigenteHasta(),fila.estado(),fila.posicion(),d.imagenes());
    }
    @Transactional(readOnly=true)
    public AnuncioDTO.Carrusel configuracion() { return new AnuncioDTO.Carrusel(repo.posiciones()); }
    @Transactional(readOnly=true)
    public List<AnuncioDTO.Detalle> visibles() { return repo.visibles().stream().map(anuncios::detalle).toList(); }

    @Transactional
    public AnuncioDTO.Carrusel guardar(AnuncioDTO.Carrusel datos) {
        if (datos == null || datos.posiciones() == null || datos.posiciones().size() > 5) throw error(HttpStatus.BAD_REQUEST,"VALIDACION","Selección inválida");
        repo.bloquearCambios();
        var posiciones=new HashSet<Integer>(); var ids=new HashSet<Long>();
        for (var p:datos.posiciones()) {
            if (p == null || p.posicion()<1 || p.posicion()>5 || p.anuncioId()<=0 || !posiciones.add(p.posicion()) || !ids.add(p.anuncioId()))
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","Posición o anuncio repetido o inválido");
            if (!repo.existe(p.anuncioId())) throw error(HttpStatus.NOT_FOUND,"NO_ENCONTRADO","Anuncio no encontrado");
        }
        repo.reemplazar(datos.posiciones());
        return new AnuncioDTO.Carrusel(repo.posiciones());
    }
    private PlatformTransactionManager transacciones;

    /** Lo usa la edicion, que sube archivos fuera de la transaccion. Sin gestor (solo en pruebas unitarias) corre directo. */
    @Autowired
    void setTransacciones(PlatformTransactionManager transacciones) { this.transacciones = transacciones; }

    private void enTransaccion(Runnable accion) {
        if (transacciones == null) accion.run();
        else new TransactionTemplate(transacciones).executeWithoutResult(estado -> accion.run());
    }

    /**
     * Edita titulo, resumen y texto de una novedad y, si {@code datos} trae la lista {@code imagenes}, tambien sus
     * imagenes. No toca la vigencia ni la posicion en el carrusel.
     *
     * <p>Primero se valida todo, luego se suben las imagenes nuevas a Storage sin candado, y recien despues, en una
     * transaccion que toma el mismo candado que eliminar, se vuelve a comprobar y se aplica el cambio completo. Si
     * algo falla despues de subir, las subidas se borran y no cambia nada. Si dos ediciones coinciden, gana la ultima
     * en guardar.</p>
     */
    public void editar(long id, AnuncioDTO.Edicion datos, Map<String, MultipartFile> archivos) {
        var texto = AnuncioService.normalizarTexto(datos);
        var partes = archivos == null ? Map.<String, MultipartFile>of() : archivos;
        var lista = datos.imagenes();
        if (lista == null) {
            if (!partes.isEmpty())
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","Se enviaron archivos pero datos no indica imágenes");
            if (id <= 0) throw noEncontrado();
            enTransaccion(() -> aplicarEdicion(id, texto, null, Map.of()));
            return;
        }
        var nuevas = validarLista(lista, partes);
        if (id <= 0 || !repo.existe(id)) throw noEncontrado();
        comprobarResultado(texto, lista, repo.imagenes(id));

        var referencias = new LinkedHashMap<String, String>();
        try {
            for (var nueva : nuevas.entrySet()) {
                String referencia = UUID.randomUUID() + nueva.getValue().extension();
                referencias.put(nueva.getKey(), referencia);
                almacen.guardar(referencia, nueva.getValue().bytes(), nueva.getValue().tipo());
            }
            enTransaccion(() -> aplicarEdicion(id, texto, lista, referencias));
        } catch (RuntimeException falla) {
            limpiar(referencias.values());
            throw falla;
        }
    }

    /** Valida la forma de la lista y las imagenes nuevas. Devuelve el contenido de cada nueva, en el orden de la lista. */
    private Map<String, ValidadorImagen.Contenido> validarLista(List<AnuncioDTO.ImagenEdicion> lista,
                                                                  Map<String, MultipartFile> partes) {
        if (lista.size() > ValidadorImagen.MAX_IMAGENES)
            throw error(HttpStatus.BAD_REQUEST,"VALIDACION","La novedad admite hasta 5 imágenes");
        var ids = new HashSet<Long>();
        var nombres = new LinkedHashSet<String>();
        for (var item : lista) {
            boolean conId = item != null && item.id() != null;
            boolean conArchivo = item != null && item.archivo() != null && !item.archivo().isBlank();
            if (conId == conArchivo)
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","Cada imagen debe indicar solo un id o solo un archivo");
            if (conId && !ids.add(item.id()))
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","La imagen " + item.id() + " figura más de una vez");
            if (conArchivo && !nombres.add(item.archivo()))
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","El archivo " + item.archivo() + " figura más de una vez");
        }
        for (String nombre : nombres)
            if (!partes.containsKey(nombre))
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","El archivo " + nombre + " no llegó en el pedido");
        for (String nombre : partes.keySet())
            if (!nombres.contains(nombre))
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","El archivo " + nombre + " se envió pero no figura en imagenes");
        var contenidos = new LinkedHashMap<String, ValidadorImagen.Contenido>();
        for (String nombre : nombres) contenidos.put(nombre, ValidadorImagen.validar(partes.get(nombre)));
        return contenidos;
    }

    /** Los ids existentes deben ser de la novedad y no puede quedar sin texto y sin imagenes. */
    private void comprobarResultado(AnuncioDTO.Edicion texto, List<AnuncioDTO.ImagenEdicion> lista,
                                    List<CarteleraRepository.ImagenPropia> propias) {
        var propiasIds = new HashSet<Long>();
        for (var propia : propias) propiasIds.add(propia.id());
        for (var item : lista)
            if (item.id() != null && !propiasIds.contains(item.id()))
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","La imagen " + item.id() + " no pertenece a esta novedad");
        if (texto.texto() == null && lista.isEmpty())
            throw error(HttpStatus.BAD_REQUEST,"VALIDACION","La novedad debe tener texto o al menos una imagen");
    }

    /** La parte que va en la base: con el candado tomado, vuelve a comprobar y aplica texto, imagenes y orden. */
    private void aplicarEdicion(long id, AnuncioDTO.Edicion texto, List<AnuncioDTO.ImagenEdicion> lista,
                                Map<String, String> referencias) {
        repo.bloquearCambios();
        if (!repo.existe(id)) throw noEncontrado();
        if (lista == null) {
            if (texto.texto() == null && repo.cantidadImagenes(id) == 0)
                throw error(HttpStatus.BAD_REQUEST,"VALIDACION","La novedad debe tener texto o al menos una imagen");
            repo.actualizarTexto(id, texto.titulo(), texto.resumen(), texto.texto());
            return;
        }
        var propias = repo.imagenes(id);
        comprobarResultado(texto, lista, propias);
        repo.actualizarTexto(id, texto.titulo(), texto.resumen(), texto.texto());
        var conservadas = new HashSet<Long>();
        for (var item : lista) if (item.id() != null) conservadas.add(item.id());
        var quitadas = new ArrayList<Long>();
        for (var propia : propias) if (!conservadas.contains(propia.id())) quitadas.add(propia.id());
        if (!quitadas.isEmpty()) {
            repo.encolarReferencias(id, quitadas);
            repo.quitarImagenes(id, quitadas);
        }
        for (int posicion = 0; posicion < lista.size(); posicion++) {
            var item = lista.get(posicion);
            if (item.id() != null) repo.actualizarOrden(item.id(), posicion);
            else repo.agregarImagen(id, referencias.get(item.archivo()), posicion);
        }
    }

    private void limpiar(Collection<String> referencias) {
        for (String referencia : referencias) {
            try { almacen.borrar(referencia); } catch (RuntimeException ignorada) { /* Mejor esfuerzo. */ }
        }
    }

    private static ApiException noEncontrado() {
        return new ApiException(HttpStatus.NOT_FOUND,"NO_ENCONTRADO","Anuncio no encontrado");
    }
    @Transactional
    public void vigencia(long id, AnuncioDTO.Vigencia v) {
        if (v==null || v.vigenteHasta()==null)
            throw error(HttpStatus.BAD_REQUEST,"VALIDACION","El fin es obligatorio y debe ser posterior al inicio");
        OffsetDateTime publicado=repo.publicadoEn(id);
        if (publicado==null) throw error(HttpStatus.NOT_FOUND,"NO_ENCONTRADO","Anuncio no encontrado");
        if (!v.vigenteHasta().isAfter(v.vigenteDesde()==null ? publicado : v.vigenteDesde()))
            throw error(HttpStatus.BAD_REQUEST,"VALIDACION","El fin debe ser posterior al inicio");
        if (repo.vigencia(id,v)==0) throw error(HttpStatus.NOT_FOUND,"NO_ENCONTRADO","Anuncio no encontrado");
    }
    @Transactional
    public void eliminar(long id) {
        repo.bloquearCambios();
        if (!repo.eliminar(id)) throw error(HttpStatus.NOT_FOUND,"NO_ENCONTRADO","Anuncio no encontrado");
    }
    @Scheduled(fixedDelayString="${app.anuncios.limpieza-intervalo-ms:30000}")
    @Transactional
    public void limpiarPendiente() {
        var pendiente=repo.tomarPendiente();
        if (pendiente==null) return;
        try { almacen.borrar(pendiente.referencia()); repo.completado(pendiente.id()); }
        catch (RuntimeException ex) { repo.fallido(pendiente.id()); }
    }
    private static ApiException error(HttpStatus status,String codigo,String mensaje) { return new ApiException(status,codigo,mensaje); }
}
