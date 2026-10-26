package uy.edu.proyecto.backend.estadistica;

import java.math.BigDecimal;

import uy.edu.proyecto.backend.especialidad.Especialidad;

/**
 * Utilizacion de un turno semanal en el periodo (contrato-v1 #35). Sin datos de pacientes.
 * porcentajeUtilizacion es null cuando no hubo numeros ofrecidos; utilizacion lo expresa como texto.
 */
public record EstadisticaTurnoDTO(
        long turnoSemanalId,
        Persona medico,
        Especialidad especialidad,
        Consultorio consultorio,
        int diaSemana,
        long fechasActivas,
        long numerosOfrecidos,
        long numerosOcupados,
        BigDecimal porcentajeUtilizacion,
        String utilizacion
) {

    public record Persona(long id, String nombre, String apellido) {
    }

    public record Consultorio(long id, String nombre, String ubicacion) {
    }
}
