package uy.edu.proyecto.backend.anuncio;

import java.util.LinkedHashMap;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;
import org.springframework.web.multipart.MultipartFile;
import org.springframework.web.multipart.MultipartRequest;
import uy.edu.proyecto.backend.exception.ApiException;

@RestController
public class CarteleraController {
    private final CarteleraService service;
    public CarteleraController(CarteleraService service) { this.service=service; }
    @GetMapping("/api/anuncios/carrusel")
    public List<AnuncioDTO.Detalle> visibles() { return service.visibles(); }
    @GetMapping("/api/admin/anuncios")
    public List<AnuncioDTO.Administracion> listar() { return service.listar(); }
    @GetMapping("/api/admin/anuncios/{id}")
    public AnuncioDTO.DetalleAdministracion detalle(@PathVariable long id) { return service.detalle(id); }
    @GetMapping("/api/admin/carrusel")
    public AnuncioDTO.Carrusel configuracion() { return service.configuracion(); }
    @PutMapping("/api/admin/carrusel")
    public AnuncioDTO.Carrusel guardar(@RequestBody AnuncioDTO.Carrusel datos) { return service.guardar(datos); }
    @PutMapping("/api/admin/anuncios/{id}/vigencia")
    public ResponseEntity<Void> vigencia(@PathVariable long id,@RequestBody AnuncioDTO.Vigencia v) {
        service.vigencia(id,v); return ResponseEntity.noContent().build();
    }
    @PutMapping(value = "/api/admin/anuncios/{id}", consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<Void> editar(@PathVariable long id, @RequestPart("datos") AnuncioDTO.Edicion datos,
                                       MultipartRequest peticion) {
        var archivos = new LinkedHashMap<String, MultipartFile>();
        peticion.getMultiFileMap().forEach((nombre, partes) -> {
            if (nombre.equals("datos")) return;
            if (partes.size() > 1)
                throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", "Hay dos archivos con el mismo nombre: " + nombre);
            archivos.put(nombre, partes.getFirst());
        });
        service.editar(id, datos, archivos);
        return ResponseEntity.noContent().build();
    }
    @DeleteMapping("/api/admin/anuncios/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable long id) { service.eliminar(id); return ResponseEntity.accepted().build(); }
}
