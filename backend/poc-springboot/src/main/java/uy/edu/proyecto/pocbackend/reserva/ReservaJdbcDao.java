package uy.edu.proyecto.pocbackend.reserva;

import javax.sql.DataSource;
import java.sql.Connection;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.SQLException;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.ArrayList;
import java.util.List;
import java.util.Optional;

/**
 * Acceso JDBC a las operaciones de reserva del POC de base de datos:
 * database/poc-sql/backend/09_reserva_alta.sql,
 * database/poc-sql/backend/10_reserva_cancelar.sql y
 * database/poc-sql/backend/11_reservas_usuario.sql.
 *
 * A diferencia de 09_reserva_alta.sql (que solo valida que el horario sea
 * futuro), acá se agrega un NOT EXISTS para no dejar reservar dos veces un
 * mismo horario: si ya hay una reserva ACTIVA, el INSERT no devuelve filas y
 * el controller responde 409 Conflict.
 */
public class ReservaJdbcDao {

    private static final String SQL_CREAR = """
            INSERT INTO "POC".reserva (usuario_id, horario_id)
            SELECT ?, h.id
            FROM "POC".horario h
            WHERE h.id = ?
            AND h.inicio > CURRENT_TIMESTAMP
            AND NOT EXISTS (
                SELECT 1 FROM "POC".reserva r
                WHERE r.horario_id = h.id AND r.estado = 'ACTIVA'
            )
            RETURNING id, usuario_id, horario_id, estado, fecha_creacion
            """;

    private static final String SQL_CANCELAR = """
            UPDATE "POC".reserva
            SET estado = 'CANCELADA', fecha_cancelacion = CURRENT_TIMESTAMP
            WHERE id = ?
            AND usuario_id = ?
            AND estado = 'ACTIVA'
            RETURNING id, usuario_id, horario_id, estado, fecha_creacion
            """;

    private static final String SQL_LISTAR_POR_USUARIO = """
            SELECT r.id, r.usuario_id, r.horario_id, r.estado, r.fecha_creacion
            FROM "POC".reserva r
            WHERE r.usuario_id = ?
            ORDER BY r.fecha_creacion DESC, r.id DESC
            """;

    private final DataSource dataSource;

    public ReservaJdbcDao(DataSource dataSource) {
        this.dataSource = dataSource;
    }

    public Optional<Reserva> crear(long usuarioId, long horarioId) throws SQLException {
        try (Connection conexion = dataSource.getConnection();
             PreparedStatement statement = conexion.prepareStatement(SQL_CREAR)) {
            statement.setLong(1, usuarioId);
            statement.setLong(2, horarioId);
            try (ResultSet rs = statement.executeQuery()) {
                return rs.next() ? Optional.of(mapear(rs)) : Optional.empty();
            }
        }
    }

    public Optional<Reserva> cancelar(long reservaId, long usuarioId) throws SQLException {
        try (Connection conexion = dataSource.getConnection();
             PreparedStatement statement = conexion.prepareStatement(SQL_CANCELAR)) {
            statement.setLong(1, reservaId);
            statement.setLong(2, usuarioId);
            try (ResultSet rs = statement.executeQuery()) {
                return rs.next() ? Optional.of(mapear(rs)) : Optional.empty();
            }
        }
    }

    public List<Reserva> listarPorUsuario(long usuarioId) throws SQLException {
        List<Reserva> resultado = new ArrayList<>();
        try (Connection conexion = dataSource.getConnection();
             PreparedStatement statement = conexion.prepareStatement(SQL_LISTAR_POR_USUARIO)) {
            statement.setLong(1, usuarioId);
            try (ResultSet rs = statement.executeQuery()) {
                while (rs.next()) {
                    resultado.add(mapear(rs));
                }
            }
        }
        return resultado;
    }

    private Reserva mapear(ResultSet rs) throws SQLException {
        return new Reserva(
                rs.getLong("id"),
                rs.getLong("usuario_id"),
                rs.getLong("horario_id"),
                rs.getString("estado"),
                OffsetDateTime.ofInstant(rs.getTimestamp("fecha_creacion").toInstant(), ZoneOffset.UTC)
        );
    }
}
