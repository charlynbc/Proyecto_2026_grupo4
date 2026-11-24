package uy.edu.proyecto.backend.aviso;

import java.util.List;

import uy.edu.proyecto.backend.agenda.ConsultaDTO;

/**
 * Respuesta de GET /api/avisos-llegada/consultas-hoy: las consultas agendadas de
 * hoy del socio y su llegada de hoy, o null si todavia no se registro.
 */
public record ConsultasDeHoyDTO(List<ConsultaDTO> items, LlegadaDeHoyDTO llegada) {
}
