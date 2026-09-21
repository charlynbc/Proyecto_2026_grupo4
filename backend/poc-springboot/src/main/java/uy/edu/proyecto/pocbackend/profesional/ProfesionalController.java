package uy.edu.proyecto.pocbackend.profesional;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;
import uy.edu.proyecto.pocbackend.comparacionjdbcjpa.ProfesionalJdbcDao;

import javax.sql.DataSource;
import java.sql.SQLException;
import java.util.List;

/**
 * GET /profesionales.
 *
 * Si hay un DataSource real disponible (perfil "postgres", ver
 * application-postgres.properties), consulta la base real via
 * ProfesionalJdbcDao con el mismo SQL de
 * database/poc-sql/backend/03_profesional_listar.sql. Si no hay DataSource
 * (perfil por defecto, sin credenciales configuradas), devuelve una lista
 * fija en memoria (mock), señalada como tal.
 */
@RestController
public class ProfesionalController {

    private static final List<Profesional> MOCK = List.of(
            new Profesional(1L, "Ana Beltrán"),
            new Profesional(2L, "Pablo Suárez"),
            new Profesional(3L, "Valentina Ríos"),
            new Profesional(4L, "Ignacio Ferreira")
    );

    private final DataSource dataSource;

    @Autowired
    public ProfesionalController(java.util.Optional<DataSource> dataSource) {
        this.dataSource = dataSource.orElse(null);
    }

    @GetMapping("/profesionales")
    public List<Profesional> listar() throws SQLException {
        if (dataSource == null) {
            return MOCK;
        }

        ProfesionalJdbcDao dao = new ProfesionalJdbcDao(dataSource);
        return dao.listar().stream()
                .map(p -> new Profesional(p.id(), p.nombre()))
                .toList();
    }
}

