package uy.edu.proyecto.pocbackend.comparacionjdbcjpa;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.util.ArrayList;
import java.util.List;

/**
 * Opcion A: acceso JDBC puro con PreparedStatement.
 *
 * Reutiliza tal cual la consulta de database/poc-sql/backend/03_profesional_listar.sql.
 *
 * La usa ProfesionalController cuando hay un DataSource real disponible
 * (perfil "postgres"). Sin ese perfil, ProfesionalController no la instancia
 * y devuelve datos mock en su lugar.
 */
public class ProfesionalJdbcDao {

    private static final String SQL = """
            SELECT id, nombre
            FROM "POC".profesional
            ORDER BY nombre, id
            """;

    private final DataSource dataSource;

    public ProfesionalJdbcDao(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public List<ProfesionalJdbc> listar() throws SQLException {
        List<ProfesionalJdbc> resultado = new ArrayList<>();
        try (Connection conexion = dataSource.getConnection();
             PreparedStatement statement = conexion.prepareStatement(SQL);
             ResultSet rs = statement.executeQuery()) {

            while (rs.next()) {
                resultado.add(new ProfesionalJdbc(rs.getLong("id"), rs.getString("nombre")));
            }
        }
        return resultado;
    }

    public record ProfesionalJdbc(long id, String nombre) {
    }
}
