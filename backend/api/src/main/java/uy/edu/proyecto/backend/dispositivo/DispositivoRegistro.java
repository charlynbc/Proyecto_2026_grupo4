package uy.edu.proyecto.backend.dispositivo;

/** Resultado del registro: el dispositivo y si la fila se creó (201) o ya existía (200). */
public record DispositivoRegistro(DispositivoDTO dispositivo, boolean creado) {
}
