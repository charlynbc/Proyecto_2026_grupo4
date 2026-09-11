package uy.edu.proyecto.pocbackend.comparacionjdbcjpa;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

import java.util.List;
import java.util.Optional;

/**
 * GET /profesionales-jpa.
 *
 * Endpoint aparte solo para la comparacion JDBC vs JPA (fase 4 de la POC):
 * usa ProfesionalJpaRepository en vez de ProfesionalJdbcDao. Si no hay
 * DataSource/JPA activo (perfil por defecto), devuelve lista vacia en vez de
 * romper, porque el repository no existe como bean.
 */
@RestController
public class ProfesionalJpaController {

    private final ProfesionalJpaRepository repository;

    @Autowired
    public ProfesionalJpaController(Optional<ProfesionalJpaRepository> repository) {
        this.repository = repository.orElse(null);
    }

    @GetMapping("/profesionales-jpa")
    public List<ProfesionalEntity> listar() {
        if (repository == null) {
            return List.of();
        }
        return repository.findAllByOrderByNombreAsc();
    }
}
