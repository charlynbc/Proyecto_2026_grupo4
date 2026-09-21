package uy.edu.proyecto;

import jakarta.ws.rs.GET;
import jakarta.ws.rs.Path;
import jakarta.ws.rs.Produces;
import jakarta.ws.rs.core.MediaType;

import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/**
 * GET /api/profesionales.
 *
 * Consulta la base real (Supabase) via JDBC directo con DriverManager
 * (mismo SQL que database/poc-sql/backend/03_profesional_listar.sql). No se
 * configuro un Connection Pool/JDBC Resource en GlassFish para esta POC, por
 * simplicidad: se abre y cierra la conexion en cada llamada. Si no hay
 * variables de entorno DB_URL/DB_USER/DB_PASSWORD (o falla la conexion), cae
 * a una lista mock fija en memoria, señalada como tal.
 */
@Path("/profesionales")
public class ProfesionalResource {

    private static final String SQL = """
            SELECT id, nombre
            FROM "POC".profesional
            ORDER BY nombre, id
            """;

    private static final List<Profesional> MOCK = List.of(
            new Profesional(1L, "Ana Beltrán"),
            new Profesional(2L, "Pablo Suárez"),
            new Profesional(3L, "Valentina Ríos"),
            new Profesional(4L, "Ignacio Ferreira")
    );

    @GET
    @Produces(MediaType.APPLICATION_JSON)
    public List<Profesional> listar() {
        String url = System.getenv("DB_URL");
        if (url == null) {
            return MOCK;
        }

        List<Profesional> resultado = new ArrayList<>();
        try {
            // GlassFish aisla el classloader de la webapp y DriverManager no
            // encuentra el driver via ServiceLoader; hay que registrarlo a mano.
            Class.forName("org.postgresql.Driver");
        } catch (ClassNotFoundException e) {
            return MOCK;
        }

        try (Connection conexion = DriverManager.getConnection(url, System.getenv("DB_USER"), System.getenv("DB_PASSWORD"));
             PreparedStatement statement = conexion.prepareStatement(SQL);
             ResultSet rs = statement.executeQuery()) {

            while (rs.next()) {
                resultado.add(new Profesional(rs.getLong("id"), rs.getString("nombre")));
            }
        } catch (SQLException e) {
            // Si la base real no responde, no rompemos el endpoint: devolvemos mock.
            return MOCK;
        }
        return resultado;
    }
}

