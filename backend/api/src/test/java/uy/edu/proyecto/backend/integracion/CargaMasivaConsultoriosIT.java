package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;

/**
 * RF-34: carga masiva de consultorios contra PostgreSQL real.
 * La siembra base ya incluye "Consultorio 1" (Planta baja).
 */
class CargaMasivaConsultoriosIT extends BaseIntegracionIT {

    private static final String PREVISUALIZAR =
            "/api/consultorios/importaciones/previsualizar";
    private static final String CONFIRMAR =
            "/api/consultorios/importaciones/confirmar";

    private int totalConsultorios() {
        return jdbc.queryForObject("SELECT count(*) FROM consultorio", Integer.class);
    }

    @Test
    void previsualizaSinInsertarNada() {
        int antes = totalConsultorios();

        Respuesta r = postMultipart(PREVISUALIZAR, tokenEmpleado(ciAdmin),
                "consultorios.csv",
                "nombre,ubicacion\nConsultorio 2,Piso 2\nConsultorio 3,Piso 3\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(2, r.json().path("total").asInt());
        assertEquals(2, r.json().path("validas").asInt());
        assertEquals(0, r.json().path("invalidas").asInt());
        assertEquals(antes, totalConsultorios(),
                "La previsualizacion no debe modificar la base");
    }

    @Test
    void confirmarImportaLasFilasValidasYRechazaLasInvalidas() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "consultorios.csv",
                "nombre,ubicacion\n"
                        + "Consultorio 2,Piso 2\n"
                        + "Consultorio 3,\n"
                        + "Consultorio 4,Piso 4\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(3, r.json().path("total").asInt());
        assertEquals(2, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());
        assertEquals(3, r.json().path("errores").get(0).path("numero").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("ubicación"));

        assertEquals("Piso 2", jdbc.queryForObject(
                "SELECT ubicacion FROM consultorio WHERE nombre = 'Consultorio 2'",
                String.class));
        assertEquals("Piso 4", jdbc.queryForObject(
                "SELECT ubicacion FROM consultorio WHERE nombre = 'Consultorio 4'",
                String.class));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM consultorio WHERE nombre = 'Consultorio 3'",
                Integer.class));
    }

    @Test
    void duplicadoDentroDelArchivoConservaLaPrimeraAparicion() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "consultorios.csv",
                "nombre,ubicacion\nConsultorio 2,Piso 2\nCONSULTORIO 2,Piso 9\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("fila 2"));

        assertEquals("Piso 2", jdbc.queryForObject(
                "SELECT ubicacion FROM consultorio"
                        + " WHERE lower(nombre) = 'consultorio 2'",
                String.class),
                "Se conserva la primera aparicion (Piso 2)");
    }

    @Test
    void existenteEnBaseSeRechazaSinActualizarla() {
        Respuesta preview = postMultipart(PREVISUALIZAR, tokenEmpleado(ciAdmin),
                "consultorios.csv",
                "nombre,ubicacion\nconsultorio 1,Piso 9\n");

        assertEquals(200, preview.estado(), preview.cuerpo());
        assertEquals(0, preview.json().path("validas").asInt());
        assertEquals(1, preview.json().path("invalidas").asInt());
        assertTrue(preview.json().path("errores").get(0).path("error").asString()
                .contains("ya existe"));

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "consultorios.csv",
                "nombre,ubicacion\nconsultorio 1,Piso 9\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());

        assertEquals("Planta baja", jdbc.queryForObject(
                "SELECT ubicacion FROM consultorio"
                        + " WHERE lower(nombre) = 'consultorio 1'",
                String.class),
                "El registro existente no se actualiza");
    }

    @Test
    void archivoVacioOCabecerasIncorrectasDevuelven400() {
        Respuesta vacia = postMultipart(PREVISUALIZAR, tokenEmpleado(ciAdmin),
                "consultorios.csv", "");
        assertEquals(400, vacia.estado());
        assertEquals("CSV_INVALIDO", vacia.codigo());

        Respuesta cabeceras = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "consultorios.csv", "name,place\nConsultorio 2,Piso 2\n");
        assertEquals(400, cabeceras.estado());
        assertEquals("CSV_INVALIDO", cabeceras.codigo());
    }

    @Test
    void separadorPuntoYComaYCamposEntrecomillados() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "consultorios.csv",
                "nombre;ubicacion\n\"Consultorio 5, ala sur\";Piso 5\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt());
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM consultorio"
                        + " WHERE nombre = 'Consultorio 5, ala sur'",
                Integer.class));
    }

    @Test
    void soloAdministradorAccedeALosEndpoints() {
        String csv = "nombre,ubicacion\nConsultorio 2,Piso 2\n";

        assertEquals(401, postMultipart(PREVISUALIZAR, null, "a.csv", csv).estado());
        assertEquals(401, postMultipart(CONFIRMAR, null, "a.csv", csv).estado());
        assertEquals(403, postMultipart(PREVISUALIZAR,
                tokenSocio(ciSocio1), "a.csv", csv).estado());
        assertEquals(403, postMultipart(CONFIRMAR,
                tokenEmpleado(ciFuncionario), "a.csv", csv).estado());
    }

    @Test
    void importacionesConcurrentesNoDuplicanConsultorios() throws Exception {
        String csv = "nombre,ubicacion\nConsultorio 8,Piso 8\n";
        int hilos = 4;
        CountDownLatch barrera = new CountDownLatch(1);
        List<Respuesta> respuestas = new CopyOnWriteArrayList<>();

        List<Thread> threads = new ArrayList<>();
        for (int i = 0; i < hilos; i++) {
            Thread hilo = new Thread(() -> {
                try {
                    barrera.await(10, TimeUnit.SECONDS);
                    respuestas.add(postMultipart(CONFIRMAR,
                            tokenEmpleado(ciAdmin), "a.csv", csv));
                } catch (InterruptedException e) {
                    Thread.currentThread().interrupt();
                }
            });
            threads.add(hilo);
            hilo.start();
        }
        barrera.countDown();
        for (Thread hilo : threads) {
            hilo.join(30000);
        }

        assertEquals(hilos, respuestas.size());
        int importadas = respuestas.stream()
                .mapToInt(r -> {
                    assertEquals(200, r.estado(), r.cuerpo());
                    return r.json().path("importadas").asInt();
                })
                .sum();
        assertEquals(1, importadas,
                "Solo una importacion inserta; las demas rechazan por duplicado");
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM consultorio"
                        + " WHERE lower(nombre) = 'consultorio 8'",
                Integer.class));
    }

    @Test
    void regresionRf33AltaIndividualDetectaLoImportado() {
        postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "consultorios.csv", "nombre,ubicacion\nConsultorio 2,Piso 2\n");

        Respuesta alta = post("/api/consultorios", tokenEmpleado(ciAdmin),
                "{\"nombre\":\"Consultorio 2\",\"ubicacion\":\"Otra\"}");

        assertEquals(409, alta.estado(), alta.cuerpo());
        assertEquals("CONSULTORIO_DUPLICADO", alta.codigo());
    }
}
