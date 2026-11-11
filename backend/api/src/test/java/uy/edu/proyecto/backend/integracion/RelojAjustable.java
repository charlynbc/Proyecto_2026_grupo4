package uy.edu.proyecto.backend.integracion;

import java.time.Clock;
import java.time.Instant;
import java.time.LocalDateTime;
import java.time.ZoneId;

/**
 * Reloj de los IT. Da la hora real salvo que un test la fije con {@link #fijar}.
 * BaseIntegracionIT lo usa en lugar del reloj de la aplicación (ClockConfig) y
 * vuelve a la hora real después de cada test, así que los demás IT no cambian.
 */
final class RelojAjustable extends Clock {

    private final ZoneId zona;
    private volatile Instant fijo;

    RelojAjustable(ZoneId zona) {
        this.zona = zona;
    }

    /** Detiene el reloj en esa fecha y hora de la zona del reloj. */
    void fijar(LocalDateTime enLaZona) {
        fijo = enLaZona.atZone(zona).toInstant();
    }

    void usarHoraReal() {
        fijo = null;
    }

    @Override
    public ZoneId getZone() {
        return zona;
    }

    @Override
    public Clock withZone(ZoneId otraZona) {
        Instant detenido = fijo;
        return detenido == null ? Clock.system(otraZona) : Clock.fixed(detenido, otraZona);
    }

    @Override
    public Instant instant() {
        Instant detenido = fijo;
        return detenido == null ? Instant.now() : detenido;
    }
}
