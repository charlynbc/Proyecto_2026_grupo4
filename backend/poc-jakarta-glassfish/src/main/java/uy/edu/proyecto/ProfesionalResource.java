package uy.edu.proyecto;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.util.List;

/**
 * GET /api/profesionales.
 *
 * DATOS MOCK: no hay conexion PostgreSQL configurada mediante variables de
 * entorno todavia. La consulta de referencia es
 * database/poc-sql/backend/03_profesional_listar.sql.
 */
@Path("/profesionales")
public class ProfesionalResource {

    private static final List<Profesional> MOCK = List.of(
            new Profesional(1L, "Ana Beltrán"),
            new Profesional(2L, "Pablo Suárez"),
            new Profesional(3L, "Valentina Ríos"),
            new Profesional(4L, "Ignacio Ferreira")
    );

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Profesional> listar() {
        return MOCK;
    }
}
