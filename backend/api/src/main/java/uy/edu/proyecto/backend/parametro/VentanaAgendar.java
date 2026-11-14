package uy.edu.proyecto.backend.parametro;

import java.time.OffsetDateTime;

/**
 * Ventana en la que un numero se puede agendar, expresada en instantes. Ambos
 * extremos son validos: un numero que empieza exactamente en el minimo o en el
 * maximo se puede agendar.
 */
public record VentanaAgendar(OffsetDateTime minimoInicio, OffsetDateTime maximoInicio) {

    public boolean contiene(OffsetDateTime inicio) {
        return !inicio.isBefore(minimoInicio) && !inicio.isAfter(maximoInicio);
    }
}
