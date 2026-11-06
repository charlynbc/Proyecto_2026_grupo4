package uy.edu.proyecto.backend.anuncio;

import java.net.URI;
import java.util.List;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RequestPart;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

@RestController
@RequestMapping("/api/anuncios")
public class AnuncioController {
    private final AnuncioService service;
    public AnuncioController(AnuncioService service) { this.service = service; }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    public ResponseEntity<AnuncioDTO.Detalle> publicar(
            @RequestPart("datos") AnuncioDTO.Datos datos,
            @RequestPart(value = "imagenes", required = false) List<MultipartFile> imagenes,
            @AuthenticationPrincipal Jwt jwt) {
        var anuncio = service.publicar(Long.parseLong(jwt.getSubject()), datos, imagenes);
        return ResponseEntity.created(URI.create("/api/anuncios/" + anuncio.id()))
                .body(anuncio);
    }

    @GetMapping
    public AnuncioDTO.Pagina listar(@RequestParam(defaultValue = "0") int page,
                                    @RequestParam(defaultValue = "20") int size) {
        return service.listar(page, size);
    }

    @GetMapping("/{id}")
    public AnuncioDTO.Detalle detalle(@PathVariable long id) {
        return service.detalle(id);
    }
}
