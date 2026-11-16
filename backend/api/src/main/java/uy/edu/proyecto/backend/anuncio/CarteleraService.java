package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.HashSet;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;
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
