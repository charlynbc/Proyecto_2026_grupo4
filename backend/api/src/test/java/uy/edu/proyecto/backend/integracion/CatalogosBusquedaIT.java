package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;

import java.util.ArrayList;
import java.util.List;

import org.junit.jupiter.api.Test;

/** Busqueda por texto de consultorios y especialidades: sin distinguir tildes ni mayusculas. */
class CatalogosBusquedaIT extends BaseIntegracionIT {

    private List<String> nombres(String ruta) {
        Respuesta r = get(ruta, tokenEmpleado(ciAdmin));
        assertEquals(200, r.estado(), r.cuerpo());
        List<String> nombres = new ArrayList<>();
        r.json().path("items").forEach(i -> nombres.add(i.path("nombre").asString()));
        return nombres;
    }

    @Test
    void consultoriosBuscaPorNombreIgnorandoTildes() {
        jdbc.update("INSERT INTO consultorio (nombre, ubicacion) VALUES ('Sala Pérez', 'Piso 2')");

        assertEquals(List.of("Sala Pérez"), nombres("/api/consultorios?nombre=per"));
        assertEquals(List.of("Sala Pérez"), nombres("/api/consultorios?nombre=perez"));
        assertEquals(List.of("Sala Pérez"), nombres("/api/consultorios?nombre=p%C3%A9rez"));
        assertEquals(List.of("Sala Pérez"), nombres("/api/consultorios?nombre=P%C3%89REZ"));

        jdbc.update("UPDATE consultorio SET nombre = 'Sala Perez' WHERE nombre = 'Sala Pérez'");

        assertEquals(List.of("Sala Perez"), nombres("/api/consultorios?nombre=p%C3%A9rez"));
    }

    @Test
    void consultoriosBuscaPorUbicacionIgnorandoTildes() {
        jdbc.update("UPDATE consultorio SET ubicacion = 'Sótano' WHERE id_consultorio = ?",
                idConsultorio);

        assertEquals(List.of("Consultorio 1"), nombres("/api/consultorios?ubicacion=sotano"));
        assertEquals(List.of("Consultorio 1"), nombres("/api/consultorios?ubicacion=S%C3%93TANO"));
    }

    @Test
    void especialidadesBuscaPorNombreIgnorandoTildes() {
        jdbc.update("INSERT INTO especialidad (nombre, requiere_pase) VALUES ('Pérez Lab', false)");

        assertEquals(List.of("Pérez Lab"), nombres("/api/especialidades?nombre=per"));
        assertEquals(List.of("Pérez Lab"), nombres("/api/especialidades?nombre=perez"));
        assertEquals(List.of("Pérez Lab"), nombres("/api/especialidades?nombre=p%C3%A9rez"));

        jdbc.update("UPDATE especialidad SET nombre = 'Perez Lab' WHERE nombre = 'Pérez Lab'");

        assertEquals(List.of("Perez Lab"), nombres("/api/especialidades?nombre=P%C3%89REZ"));
        // Con tilde en la busqueda y sin tilde en el dato (Cardiologia)
        assertEquals(List.of("Cardiologia"), nombres("/api/especialidades?nombre=cardiolog%C3%ADa"));
    }
}
