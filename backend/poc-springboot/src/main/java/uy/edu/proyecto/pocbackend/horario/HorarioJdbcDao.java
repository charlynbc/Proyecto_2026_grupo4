package uy.edu.proyecto.pocbackend.horario;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.OffsetDateTime;
import java.util.ArrayList;
import java.util.List;

/**
 * Acceso JDBC a database/poc-sql/backend/08_horarios_disponibles.sql
 * (horarios futuros de un profesional que todavia no tienen reserva activa).
 */
public class HorarioJdbcDao {

    private static final String SQL = """
            SELECT h.id, h.profesional_id, h.inicio, h.fin
            FROM "POC".horario h
            WHERE h.profesional_id = ?
            AND h.inicio >= ?
            AND h.inicio < ?
            AND h.inicio > CURRENT_TIMESTAMP
            AND NOT EXISTS (
                SELECT 1 FROM "POC".reserva r
                WHERE r.horario_id = h.id AND r.estado = 'ACTIVA'
            )
            ORDER BY h.inicio, h.id
            """;

    private final DataSource dataSource;

    public HorarioJdbcDao(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public List<Horario> disponibles(long profesionalId, OffsetDateTime desde, OffsetDateTime hasta) throws SQLException {
        List<Horario> resultado = new ArrayList<>();
        try (Connection conexion = dataSource.getConnection();
             PreparedStatement statement = conexion.prepareStatement(SQL)) {

            statement.setLong(1, profesionalId);
            statement.setTimestamp(2, Timestamp.from(desde.toInstant()));
            statement.setTimestamp(3, Timestamp.from(hasta.toInstant()));

            try (ResultSet rs = statement.executeQuery()) {
                while (rs.next()) {
                    resultado.add(new Horario(
                            rs.getLong("id"),
                            rs.getLong("profesional_id"),
                            rs.getTimestamp("inicio").toInstant().atOffset(desde.getOffset()),
                            rs.getTimestamp("fin").toInstant().atOffset(desde.getOffset())
                    ));
                }
            }
        }
        return resultado;
    }
}
