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
 * RF-30: carga masiva de especialidades contra PostgreSQL real.
 * La siembra base ya incluye "Medicina General" y "Cardiologia".
 */
class CargaMasivaEspecialidadesIT extends BaseIntegracionIT {

    private static final String PREVISUALIZAR =
            "/api/especialidades/importaciones/previsualizar";
    private static final String CONFIRMAR =
            "/api/especialidades/importaciones/confirmar";

    private int totalEspecialidades() {
        return jdbc.queryForObject("SELECT count(*) FROM especialidad", Integer.class);
    }

    @Test
    void previsualizaSinInsertarNada() {
        int antes = totalEspecialidades();

        Respuesta r = postMultipart(PREVISUALIZAR, tokenEmpleado(ciAdmin),
                "especialidades.csv",
                "nombre,requiere_pase\nNeurologia,si\nTraumatologia,no\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(2, r.json().path("total").asInt());
        assertEquals(2, r.json().path("validas").asInt());
        assertEquals(0, r.json().path("invalidas").asInt());
        assertEquals(antes, totalEspecialidades(),
                "La previsualizacion no debe modificar la base");
    }

    @Test
    void confirmarImportaLasFilasValidasYRechazaLasInvalidas() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "especialidades.csv",
                "nombre,requiere_pase\n"
                        + "Neurologia,si\n"
                        + "Traumatologia,quizas\n"
                        + "Pediatria,no\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(3, r.json().path("total").asInt());
        assertEquals(2, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());
        assertEquals(3, r.json().path("errores").get(0).path("numero").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("si o no"));

        assertEquals(Boolean.TRUE, jdbc.queryForObject(
                "SELECT requiere_pase FROM especialidad WHERE nombre = 'Neurologia'",
                Boolean.class));
        assertEquals(Boolean.FALSE, jdbc.queryForObject(
                "SELECT requiere_pase FROM especialidad WHERE nombre = 'Pediatria'",
                Boolean.class));
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM especialidad WHERE nombre = 'Traumatologia'",
                Integer.class));
    }

    @Test
    void duplicadoDentroDelArchivoConservaLaPrimeraAparicion() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "especialidades.csv",
                "nombre,requiere_pase\nNeurologia,si\nNEUROLOGIA,no\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("fila 2"));

        assertEquals(Boolean.TRUE, jdbc.queryForObject(
                "SELECT requiere_pase FROM especialidad"
                        + " WHERE lower(nombre) = 'neurologia'",
                Boolean.class),
                "Se conserva la primera aparicion (requiere_pase = si)");
    }

    @Test
    void existenteEnBaseSeRechazaSinActualizarla() {
        Respuesta preview = postMultipart(PREVISUALIZAR, tokenEmpleado(ciAdmin),
                "especialidades.csv",
                "nombre,requiere_pase\nmedicina general,si\n");

        assertEquals(200, preview.estado(), preview.cuerpo());
        assertEquals(0, preview.json().path("validas").asInt());
        assertEquals(1, preview.json().path("invalidas").asInt());
        assertTrue(preview.json().path("errores").get(0).path("error").asString()
                .contains("ya existe"));

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "especialidades.csv",
                "nombre,requiere_pase\nmedicina general,si\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());

        assertEquals(Boolean.FALSE, jdbc.queryForObject(
                "SELECT requiere_pase FROM especialidad"
                        + " WHERE lower(nombre) = 'medicina general'",
                Boolean.class),
                "El registro existente no se actualiza");
    }

    @Test
    void archivoVacioOCabecerasIncorrectasDevuelven400() {
        Respuesta vacia = postMultipart(PREVISUALIZAR, tokenEmpleado(ciAdmin),
                "especialidades.csv", "");
        assertEquals(400, vacia.estado());
        assertEquals("CSV_INVALIDO", vacia.codigo());

        Respuesta cabeceras = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "especialidades.csv", "name,pase\nNeurologia,si\n");
        assertEquals(400, cabeceras.estado());
        assertEquals("CSV_INVALIDO", cabeceras.codigo());
    }

    @Test
    void separadorPuntoYComaYCamposEntrecomillados() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "especialidades.csv",
                "nombre;requiere_pase\n\"Odontologia, integral\";si\n");

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt());
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM especialidad"
                        + " WHERE nombre = 'Odontologia, integral'",
                Integer.class));
    }

    @Test
    void soloAdministradorAccedeALosEndpoints() {
        String csv = "nombre,requiere_pase\nNeurologia,si\n";

        assertEquals(401, postMultipart(PREVISUALIZAR, null, "a.csv", csv).estado());
        assertEquals(401, postMultipart(CONFIRMAR, null, "a.csv", csv).estado());
        assertEquals(403, postMultipart(PREVISUALIZAR,
                tokenSocio(ciSocio1), "a.csv", csv).estado());
        assertEquals(403, postMultipart(CONFIRMAR,
                tokenEmpleado(ciFuncionario), "a.csv", csv).estado());
    }

    @Test
    void importacionesConcurrentesNoDuplicanEspecialidades() throws Exception {
        String csv = "nombre,requiere_pase\nOftalmologia,si\n";
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
                "SELECT count(*) FROM especialidad"
                        + " WHERE lower(nombre) = 'oftalmologia'",
                Integer.class));
    }

    @Test
    void regresionRf29AltaIndividualDetectaLoImportado() {
        postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "especialidades.csv", "nombre,requiere_pase\nNeurologia,si\n");

        Respuesta alta = post("/api/especialidades", tokenEmpleado(ciAdmin),
                "{\"nombre\":\"NEUROLOGIA\",\"requierePase\":false}");

        assertEquals(409, alta.estado(), alta.cuerpo());
        assertEquals("ESPECIALIDAD_DUPLICADA", alta.codigo());
    }
}
