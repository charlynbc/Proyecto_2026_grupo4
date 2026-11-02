package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;
import java.util.concurrent.CountDownLatch;
import java.util.concurrent.TimeUnit;

import org.junit.jupiter.api.Test;

/**
 * RF-32: carga masiva de usuarios contra PostgreSQL real.
 * La siembra base incluye admin, 2 funcionarios, un medico (con Medicina
 * General), 4 socios activos y un socio pendiente; especialidades
 * "Medicina General" y "Cardiologia".
 */
class CargaMasivaUsuariosIT extends BaseIntegracionIT {

    private static final String PREVISUALIZAR =
            "/api/usuarios/importaciones/previsualizar";
    private static final String CONFIRMAR =
            "/api/usuarios/importaciones/confirmar";
    private static final String ENCABEZADO =
            "ci,nombre,apellido,fecha_nacimiento,correo,telefono_1,"
                    + "telefono_2,direccion,rol,especialidades\n";

    private String fila(String ci, String nombre, String apellido,
            String fecha, String correo, String rol, String especialidades) {
        return ci + "," + nombre + "," + apellido + "," + fecha + ","
                + correo + ",099111222,,," + rol + "," + especialidades + "\n";
    }

    @Test
    void altaMasivaDeSocioQuedaPendienteSinCorreo() {
        String ciNuevo = ci(5000001);

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciNuevo, "Rosa", "Melia", "1991-04-12",
                        "rosa@ejemplo.invalid", "SOCIO", ""));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt());
        assertEquals(0, r.json().path("rechazadas").asInt());

        var cuenta = jdbc.queryForMap(
                "SELECT rol, habilitada, primer_ingreso_completado,"
                        + " contrasena_hash FROM cuenta WHERE ci = ?",
                ciNuevo);
        assertEquals("SOCIO", cuenta.get("rol"));
        assertEquals(true, cuenta.get("habilitada"));
        assertEquals(false, cuenta.get("primer_ingreso_completado"),
                "La cuenta no se activa automaticamente");
        assertNull(cuenta.get("contrasena_hash"));

        assertEquals(0, capturaEnlaces.cantidad(),
                "El alta masiva no envia correos de primer ingreso");
        assertEquals(0, capturaEnlaces.cantidadRecuperaciones());
        assertEquals(0, capturaEnlaces.cantidadCambiosCorreo());
    }

    @Test
    void altaMasivaDeMedicoConVariasEspecialidades() {
        String ciNuevo = ci(5000002);

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciNuevo, "Marta", "Rosa", "1978-03-15",
                        "marta@ejemplo.invalid", "MEDICO",
                        "Medicina General|cardiologia"));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt(), r.cuerpo());

        Long idCuenta = jdbc.queryForObject(
                "SELECT id_cuenta FROM cuenta WHERE ci = ?", Long.class, ciNuevo);
        List<String> especialidades = jdbc.queryForList(
                "SELECT e.nombre FROM medico_especialidad me"
                        + " JOIN especialidad e ON e.id_especialidad = me.id_especialidad"
                        + " WHERE me.id_medico = ? ORDER BY e.nombre",
                String.class, idCuenta);
        assertEquals(List.of("Cardiologia", "Medicina General"), especialidades,
                "Las especialidades se resuelven por nombre sin distinguir mayusculas");
    }

    @Test
    void altaMasivaDeFuncionario() {
        String ciNuevo = ci(5000003);

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciNuevo, "Fabio", "Nuevo", "1993-09-09",
                        "fabio@ejemplo.invalid", "FUNCIONARIO", ""));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt());
        assertEquals("FUNCIONARIO", jdbc.queryForObject(
                "SELECT rol FROM cuenta WHERE ci = ?", String.class, ciNuevo));
    }

    @Test
    void ciInvalidaSeRechaza() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila("12345670", "Rosa", "Melia", "1991-04-12",
                        "rosa@ejemplo.invalid", "SOCIO", ""));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());
        assertEquals("La CI no es valida",
                r.json().path("errores").get(0).path("error").asString());
        assertEquals(0, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = '12345670'",
                Integer.class));
    }

    @Test
    void cuentaDeSocioDuplicadaSeRechaza() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciSocio1, "Sofia", "Socia", "1985-05-05",
                        "otra@ejemplo.invalid", "SOCIO", ""));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("importadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("cuenta de socio"));
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = ? AND rol = 'SOCIO'",
                Integer.class, ciSocio1));
    }

    @Test
    void personaExistenteConDatosCoincidentesAdmiteSegundoRol() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciSocio1, "Sofia", "Socia", "1985-05-05",
                        "sofia.empleada@ejemplo.invalid", "FUNCIONARIO", ""));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt(), r.cuerpo());
        assertEquals(2, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = ?",
                Integer.class, ciSocio1));
    }

    @Test
    void personaExistenteConDatosDiscordantesSeRechaza() {
        Respuesta preview = postMultipart(PREVISUALIZAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciSocio1, "Sofia", "OtroApellido",
                        "1985-05-05", "x@ejemplo.invalid", "FUNCIONARIO", ""));
        assertEquals(1, preview.json().path("invalidas").asInt());
        assertTrue(preview.json().path("errores").get(0).path("error").asString()
                .contains("otros datos personales"));

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciSocio1, "Sofia", "OtroApellido",
                        "1985-05-05", "x@ejemplo.invalid", "FUNCIONARIO", ""));

        assertEquals(0, r.json().path("importadas").asInt());
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = ?",
                Integer.class, ciSocio1),
                "No se crea la cuenta ni se modifican los datos existentes");
        assertEquals("Socia", jdbc.queryForObject(
                "SELECT apellido FROM persona WHERE ci = ?",
                String.class, ciSocio1));
    }

    @Test
    void medicoConEspecialidadInexistenteSeRechaza() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ci(5000004), "Marta", "Rosa", "1978-03-15",
                        "marta@ejemplo.invalid", "MEDICO", "Astrologia"));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("importadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("Especialidad desconocida"));
    }

    @Test
    void columnasObligatoriasFaltantesYRolInvalidoSeRechazan() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO
                        + fila(ci(5000005), "", "Rosa", "1978-03-15",
                                "a@ejemplo.invalid", "SOCIO", "")
                        + fila(ci(5000006), "Ana", "Rosa", "1978-03-15",
                                "b@ejemplo.invalid", "GERENTE", ""));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("importadas").asInt());
        assertEquals(2, r.json().path("rechazadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("obligatorio"));
        assertTrue(r.json().path("errores").get(1).path("error").asString()
                .contains("rol"));
    }

    @Test
    void empleadoHabilitadoImpideOtraCuentaDeEmpleado() {
        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciFuncionario, "Fabio", "Funcionario",
                        "1985-05-05", "fabio2@ejemplo.invalid", "MEDICO",
                        "Medicina General"));

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(0, r.json().path("importadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("cuenta de empleado habilitada"));
    }

    @Test
    void filaRepetidaEnElArchivoSeRechazaConservandoLaPrimera() {
        String ciNuevo = ci(5000007);
        String fila = fila(ciNuevo, "Rosa", "Melia", "1991-04-12",
                "rosa@ejemplo.invalid", "SOCIO", "");

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv", ENCABEZADO + fila + fila);

        assertEquals(200, r.estado(), r.cuerpo());
        assertEquals(1, r.json().path("importadas").asInt());
        assertEquals(1, r.json().path("rechazadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("fila 2"));
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = ?",
                Integer.class, ciNuevo));
    }

    @Test
    void soloAdministradorAccedeALosEndpoints() {
        String csv = ENCABEZADO + fila(ci(5000008), "Rosa", "Melia",
                "1991-04-12", "rosa@ejemplo.invalid", "SOCIO", "");

        assertEquals(401, postMultipart(PREVISUALIZAR, null, "a.csv", csv).estado());
        assertEquals(401, postMultipart(CONFIRMAR, null, "a.csv", csv).estado());
        assertEquals(403, postMultipart(PREVISUALIZAR,
                tokenSocio(ciSocio1), "a.csv", csv).estado());
        assertEquals(403, postMultipart(CONFIRMAR,
                tokenEmpleado(ciMedico), "a.csv", csv).estado());
    }

    @Test
    void importacionesConcurrentesNoDuplicanCuentas() throws Exception {
        String ciNuevo = ci(5000009);
        String csv = ENCABEZADO + fila(ciNuevo, "Rosa", "Melia", "1991-04-12",
                "rosa@ejemplo.invalid", "SOCIO", "");
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
                "Solo una importacion crea la cuenta; las demas la rechazan");
        assertEquals(1, jdbc.queryForObject(
                "SELECT count(*) FROM cuenta WHERE ci = ?",
                Integer.class, ciNuevo));
    }

    @Test
    void regresionRf31AltaIndividualSigueFuncionando() {
        String ciNuevo = ci(5000010);

        Respuesta alta = post("/api/usuarios", tokenEmpleado(ciAdmin), """
                {"ci":"%s","nombre":"Rosa","apellido":"Melia",
                 "fechaNacimiento":"1991-04-12","correo":"rosa@ejemplo.invalid",
                 "telefono1":"099111222","rol":"SOCIO"}
                """.formatted(ciNuevo));
        assertEquals(201, alta.estado(), alta.cuerpo());

        Respuesta r = postMultipart(CONFIRMAR, tokenEmpleado(ciAdmin),
                "usuarios.csv",
                ENCABEZADO + fila(ciNuevo, "Rosa", "Melia", "1991-04-12",
                        "rosa@ejemplo.invalid", "SOCIO", ""));

        assertEquals(0, r.json().path("importadas").asInt());
        assertTrue(r.json().path("errores").get(0).path("error").asString()
                .contains("cuenta de socio"));
    }
}
