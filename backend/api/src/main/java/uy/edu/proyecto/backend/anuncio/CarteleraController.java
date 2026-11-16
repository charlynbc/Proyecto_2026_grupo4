package uy.edu.proyecto.backend.anuncio;

import java.util.List;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.*;

@RestController
public class CarteleraController {
    private final CarteleraService service;
    public CarteleraController(CarteleraService service) { this.service=service; }
    @GetMapping("/api/anuncios/carrusel")
    public List<AnuncioDTO.Detalle> visibles() { return service.visibles(); }
    @GetMapping("/api/admin/anuncios")
    public List<AnuncioDTO.Administracion> listar() { return service.listar(); }
    @GetMapping("/api/admin/carrusel")
    public AnuncioDTO.Carrusel configuracion() { return service.configuracion(); }
    @PutMapping("/api/admin/carrusel")
    public AnuncioDTO.Carrusel guardar(@RequestBody AnuncioDTO.Carrusel datos) { return service.guardar(datos); }
    @PutMapping("/api/admin/anuncios/{id}/vigencia")
    public ResponseEntity<Void> vigencia(@PathVariable long id,@RequestBody AnuncioDTO.Vigencia v) {
        service.vigencia(id,v); return ResponseEntity.noContent().build();
    }
    @DeleteMapping("/api/admin/anuncios/{id}")
    public ResponseEntity<Void> eliminar(@PathVariable long id) { service.eliminar(id); return ResponseEntity.accepted().build(); }
}
