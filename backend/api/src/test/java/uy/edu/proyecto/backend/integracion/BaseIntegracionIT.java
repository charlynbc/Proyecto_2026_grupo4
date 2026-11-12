package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertTrue;

import java.io.IOException;
import java.net.URI;
import java.net.http.HttpClient;
import java.net.http.HttpRequest;
import java.net.http.HttpResponse;
import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.sql.Connection;
import java.sql.DriverManager;
import java.sql.PreparedStatement;
import java.sql.ResultSet;
import java.sql.Statement;
import java.time.Duration;
import java.time.LocalDate;
import java.time.ZoneId;
import java.util.ArrayList;
import java.util.List;
import java.util.concurrent.CopyOnWriteArrayList;

import org.junit.jupiter.api.AfterEach;
import org.junit.jupiter.api.BeforeEach;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.test.context.TestConfiguration;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Import;
import org.springframework.context.annotation.Primary;
import org.springframework.context.event.EventListener;
import org.springframework.core.io.FileSystemResource;
import org.springframework.jdbc.core.JdbcTemplate;
import org.springframework.jdbc.datasource.init.ScriptUtils;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.test.context.DynamicPropertyRegistry;
import org.springframework.test.context.DynamicPropertySource;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.ObjectMapper;
import tools.jackson.databind.json.JsonMapper;
import uy.edu.proyecto.backend.auth.CuentaActivaPrimerIngresoSolicitada;
import uy.edu.proyecto.backend.auth.CuentaPendienteRecuperacionSolicitada;
import uy.edu.proyecto.backend.auth.PrimerIngresoLinkSolicitado;
import uy.edu.proyecto.backend.auth.RecuperacionLinkSolicitado;
import uy.edu.proyecto.backend.usuario.CambioCorreoSolicitado;

/**
 * Base de las pruebas de integracion reales: servidor HTTP real, Spring Security,
 * JDBC y un PostgreSQL local o efimero. Nunca se conecta a una base compartida:
 * exige host local y un nombre de base terminado en _e2e o _test.
 */
@SpringBootTest(webEnvironment = SpringBootTest.WebEnvironment.RANDOM_PORT)
@Import(BaseIntegracionIT.ConfiguracionPrueba.class)
abstract class BaseIntegracionIT {

    static final String DB_URL = entorno(
            "E2E_DB_URL", "jdbc:postgresql://localhost:55432/proyecto_e2e");
    static final String DB_USER = entorno("E2E_DB_USER", "postgres");
    static final String DB_PASSWORD = entorno("E2E_DB_PASSWORD", "postgres");
    static final String CLAVE = "Clave-Segura-1";
    static final ZoneId ZONA = ZoneId.of("America/Montevideo");
    static final ObjectMapper JSON = JsonMapper.builder().build();

    private static final int[] PESOS = {2, 9, 8, 7, 6, 3, 4};
    private static boolean baseLista;
    private static String hashClave;

    final HttpClient http = HttpClient.newBuilder()
            .followRedirects(HttpClient.Redirect.NEVER)
            .connectTimeout(Duration.ofSeconds(10))
            .build();

    @Value("${local.server.port}")
    int puerto;

    @Autowired
    JdbcTemplate jdbc;

    @Autowired
    PasswordEncoder passwordEncoder;

    @Autowired
    CapturaEnlaces capturaEnlaces;

    @Autowired
    RelojAjustable reloj;

    long idAdmin;
    long idFuncionario;
    long idFuncionario2;
    long idMedico;
    long idSocio1;
    long idSocio2;
    long idSocio3;
    long idSocio4;
    long idSocioNuevo;
    long idEspecialidad;
    long idEspecialidadConPase;
    long idConsultorio;

    final String ciAdmin = ci(1000001);
    final String ciFuncionario = ci(1000002);
    final String ciFuncionario2 = ci(1000003);
    final String ciMedico = ci(1000004);
    final String ciSocio1 = ci(2000001);
    final String ciSocio2 = ci(2000002);
    final String ciSocio3 = ci(2000003);
    final String ciSocio4 = ci(2000004);
    final String ciSocioNuevo = ci(2000005);

    @TestConfiguration
    static class ConfiguracionPrueba {
        @Bean
        CapturaEnlaces capturaEnlaces() {
            return new CapturaEnlaces();
        }

        /**
         * Reemplaza al reloj de la aplicación en todos los IT. Da la hora real
         * salvo que un test la fije: los servicios que reciben un Clock pasan a
         * depender de la hora que elige el test, no de cuándo se corre.
         */
        @Bean
        @Primary
        RelojAjustable relojPrueba() {
            return new RelojAjustable(ZONA);
        }
    }

    /** Sustituye al correo: guarda los enlaces generados sin enviar nada. */
    static class CapturaEnlaces {
        private final List<PrimerIngresoLinkSolicitado> eventos = new CopyOnWriteArrayList<>();
        private final List<CuentaActivaPrimerIngresoSolicitada> avisosCuentaActiva =
                new CopyOnWriteArrayList<>();
        private final List<CambioCorreoSolicitado> cambiosCorreo =
                new CopyOnWriteArrayList<>();
        private final List<RecuperacionLinkSolicitado> recuperaciones =
                new CopyOnWriteArrayList<>();
        private final List<CuentaPendienteRecuperacionSolicitada>
                avisosCuentaPendiente = new CopyOnWriteArrayList<>();

        @EventListener
        void alSolicitar(PrimerIngresoLinkSolicitado evento) {
            eventos.add(evento);
        }

        @EventListener
        void alSolicitarRecuperacion(RecuperacionLinkSolicitado evento) {
            recuperaciones.add(evento);
        }

        @EventListener
        void alAvisarCuentaPendiente(
                CuentaPendienteRecuperacionSolicitada evento
        ) {
            avisosCuentaPendiente.add(evento);
        }

        @EventListener
        void alInformarCuentaActiva(CuentaActivaPrimerIngresoSolicitada evento) {
            avisosCuentaActiva.add(evento);
        }

        @EventListener
        void alSolicitarCambioCorreo(CambioCorreoSolicitado evento) {
            cambiosCorreo.add(evento);
        }

        PrimerIngresoLinkSolicitado ultimo() {
            return eventos.isEmpty() ? null : eventos.get(eventos.size() - 1);
        }

        CambioCorreoSolicitado ultimoCambioCorreo() {
            return cambiosCorreo.isEmpty()
                    ? null
                    : cambiosCorreo.get(cambiosCorreo.size() - 1);
        }

        int cantidadCambiosCorreo() {
            return cambiosCorreo.size();
        }

        RecuperacionLinkSolicitado ultimaRecuperacion() {
            return recuperaciones.isEmpty()
                    ? null
                    : recuperaciones.get(recuperaciones.size() - 1);
        }

        int cantidadRecuperaciones() {
            return recuperaciones.size();
        }

        int cantidadAvisosCuentaPendiente() {
            return avisosCuentaPendiente.size();
        }

        void limpiar() {
            eventos.clear();
            avisosCuentaActiva.clear();
            cambiosCorreo.clear();
            recuperaciones.clear();
            avisosCuentaPendiente.clear();
        }

        int cantidad() {
            return eventos.size();
        }

        CuentaActivaPrimerIngresoSolicitada ultimoAvisoCuentaActiva() {
            return avisosCuentaActiva.isEmpty()
                    ? null
                    : avisosCuentaActiva.get(avisosCuentaActiva.size() - 1);
        }

        int cantidadAvisosCuentaActiva() {
            return avisosCuentaActiva.size();
        }
    }

    @DynamicPropertySource
    static void propiedades(DynamicPropertyRegistry registry) throws Exception {
        prepararBase();
        registry.add("spring.datasource.url", () -> DB_URL);
        registry.add("spring.datasource.username", () -> DB_USER);
        registry.add("spring.datasource.password", () -> DB_PASSWORD);
        registry.add("app.jwt.secret-base64",
                () -> "MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=");
        registry.add("app.firebase.enabled", () -> "false");
        registry.add("app.mail.provider", () -> "none");
    }

    private static synchronized void prepararBase() throws Exception {
        if (baseLista) {
            return;
        }
        // Todas las condiciones se validan antes de abrir una conexion destructiva.
        String nombre = GuardaBaseE2E.validar(DB_URL, System.getenv(GuardaBaseE2E.VARIABLE_HABILITACION));
        String urlAdmin = DB_URL.substring(0, DB_URL.lastIndexOf('/') + 1) + "postgres";

        try (Connection admin = DriverManager.getConnection(urlAdmin, DB_USER, DB_PASSWORD)) {
            boolean existe;
            try (PreparedStatement consulta = admin.prepareStatement(
                    "SELECT 1 FROM pg_database WHERE datname = ?")) {
                consulta.setString(1, nombre);
                try (ResultSet resultado = consulta.executeQuery()) {
                    existe = resultado.next();
                }
            }
            if (!existe) {
                try (Statement crear = admin.createStatement()) {
                    crear.execute("CREATE DATABASE " + GuardaBaseE2E.identificador(nombre));
                    crear.execute("COMMENT ON DATABASE " + GuardaBaseE2E.identificador(nombre)
                            + " IS '" + GuardaBaseE2E.MARCA + "'");
                }
            }
        }

        try (Connection conexion = DriverManager.getConnection(DB_URL, DB_USER, DB_PASSWORD)) {
            exigirBaseDescartable(conexion, nombre);
            try (Statement sentencia = conexion.createStatement()) {
                sentencia.execute("DROP SCHEMA IF EXISTS public CASCADE");
                sentencia.execute("CREATE SCHEMA public");
            }
            Path esquema = Path.of(entorno("E2E_SCHEMA_PATH", "../../database/schema.sql"))
                    .toAbsolutePath().normalize();
            assertTrue(Files.isRegularFile(esquema), "No existe el esquema: " + esquema);
            ScriptUtils.executeSqlScript(conexion, new FileSystemResource(esquema));
        }
        baseLista = true;
    }

    /** Una base con tablas solo se reinicializa si fue marcada como descartable. */
    private static void exigirBaseDescartable(Connection conexion, String nombre) throws Exception {
        String marca = null;
        int tablas;
        try (PreparedStatement consulta = conexion.prepareStatement(
                "SELECT shobj_description(oid, 'pg_database') FROM pg_database WHERE datname = ?")) {
            consulta.setString(1, nombre);
            try (ResultSet resultado = consulta.executeQuery()) {
                if (resultado.next()) {
                    marca = resultado.getString(1);
                }
            }
        }
        try (Statement sentencia = conexion.createStatement();
                ResultSet resultado = sentencia.executeQuery(
                        "SELECT count(*) FROM pg_tables WHERE schemaname = 'public'")) {
            resultado.next();
            tablas = resultado.getInt(1);
        }
        if (tablas > 0 && !GuardaBaseE2E.MARCA.equals(marca)) {
            throw new IllegalStateException("La base " + nombre + " tiene tablas y no esta marcada como "
                    + "descartable (COMMENT ON DATABASE ... IS '" + GuardaBaseE2E.MARCA + "'). No se modifica.");
        }
        try (Statement sentencia = conexion.createStatement()) {
            sentencia.execute("COMMENT ON DATABASE " + GuardaBaseE2E.identificador(nombre)
                    + " IS '" + GuardaBaseE2E.MARCA + "'");
        }
    }

    /** Un reloj fijado por un test no se filtra a los siguientes, aunque el test falle. */
    @AfterEach
    void volverALaHoraReal() {
        reloj.usarHoraReal();
    }

    @BeforeEach
    void reiniciarDatos() {
        List<String> tablas = jdbc.queryForList(
                "SELECT quote_ident(tablename) FROM pg_tables WHERE schemaname = 'public'",
                String.class);
        jdbc.execute("TRUNCATE TABLE public." + String.join(", public.", tablas)
                + " RESTART IDENTITY CASCADE");
        capturaEnlaces.limpiar();
        sembrar();
    }

    private void sembrar() {
        if (hashClave == null) {
            hashClave = passwordEncoder.encode(CLAVE);
        }
        idAdmin = cuenta(ciAdmin, "Ana", "Admin", "ADMINISTRADOR", true);
        idFuncionario = cuenta(ciFuncionario, "Fabio", "Funcionario", "FUNCIONARIO", true);
        idFuncionario2 = cuenta(ciFuncionario2, "Flor", "Recepcion", "FUNCIONARIO", true);
        idMedico = cuenta(ciMedico, "Mario", "Medina", "MEDICO", true);
        idSocio1 = cuenta(ciSocio1, "Sofia", "Socia", "SOCIO", true);
        idSocio2 = cuenta(ciSocio2, "Santiago", "Soca", "SOCIO", true);
        idSocio3 = cuenta(ciSocio3, "Selva", "Suarez", "SOCIO", true);
        idSocio4 = cuenta(ciSocio4, "Simon", "Sosa", "SOCIO", true);
        idSocioNuevo = cuenta(ciSocioNuevo, "Nora", "Nueva", "SOCIO", false);

        idEspecialidad = jdbc.queryForObject(
                "INSERT INTO especialidad (nombre, requiere_pase) VALUES ('Medicina General', false)"
                        + " RETURNING id_especialidad", Long.class);
        idEspecialidadConPase = jdbc.queryForObject(
                "INSERT INTO especialidad (nombre, requiere_pase) VALUES ('Cardiologia', true)"
                        + " RETURNING id_especialidad", Long.class);
        jdbc.update("INSERT INTO medico_especialidad VALUES (?, ?)", idMedico, idEspecialidad);
        idConsultorio = jdbc.queryForObject(
                "INSERT INTO consultorio (nombre, ubicacion) VALUES ('Consultorio 1', 'Planta baja')"
                        + " RETURNING id_consultorio", Long.class);
    }

    private long cuenta(String ci, String nombre, String apellido, String rol, boolean activa) {
        jdbc.update("INSERT INTO persona VALUES (?, ?, ?, DATE '1985-05-05')", ci, nombre, apellido);
        return jdbc.queryForObject(
                "INSERT INTO cuenta (ci, rol, correo, telefono_1, direccion, contrasena_hash,"
                        + " primer_ingreso_completado) VALUES (?, ?, ?, '099111222', ?, ?, ?)"
                        + " RETURNING id_cuenta",
                Long.class, ci, rol, "u" + ci + "@ejemplo.invalid",
                activa ? "Calle Falsa 123" : null, activa ? hashClave : null, activa);
    }

    static String ci(int cuerpo) {
        String digitos = String.format("%07d", cuerpo);
        int suma = 0;
        for (int i = 0; i < PESOS.length; i++) {
            suma += Character.digit(digitos.charAt(i), 10) * PESOS[i];
        }
        return digitos + ((10 - suma % 10) % 10);
    }

    static String entorno(String nombre, String porDefecto) {
        String valor = System.getenv(nombre);
        return valor == null || valor.isBlank() ? porDefecto : valor;
    }

    static LocalDate hoy() {
        return LocalDate.now(ZONA);
    }

    /* ---------- HTTP ---------- */

    record Respuesta(int estado, String cuerpo, java.net.http.HttpHeaders cabeceras) {
        JsonNode json() {
            return cuerpo == null || cuerpo.isBlank() ? JSON.createObjectNode() : JSON.readTree(cuerpo);
        }

        String codigo() {
            return json().path("code").asString();
        }

        List<String> setCookies() {
            return cabeceras.allValues("set-cookie");
        }

        String refreshSetCookie() {
            return setCookies().stream()
                    .filter(c -> c.startsWith("refresh_token="))
                    .findFirst()
                    .orElse(null);
        }

        /** Valor del refresh token emitido ("" si es una cookie de borrado). */
        String refreshToken() {
            String cookie = refreshSetCookie();
            if (cookie == null) {
                return null;
            }
            String valor = cookie.substring("refresh_token=".length());
            int fin = valor.indexOf(';');
            return fin < 0 ? valor : valor.substring(0, fin);
        }
    }

    Respuesta enviar(String metodo, String ruta, String bearer, String cookieRefresh, String cuerpo) {
        HttpRequest.Builder peticion = HttpRequest.newBuilder(
                        URI.create("http://localhost:" + puerto + ruta))
                .timeout(Duration.ofSeconds(30));
        if (bearer != null) {
            peticion.header("Authorization", "Bearer " + bearer);
        }
        if (cookieRefresh != null) {
            peticion.header("Cookie", "refresh_token=" + cookieRefresh);
        }
        if (cuerpo != null) {
            peticion.header("Content-Type", "application/json");
            peticion.method(metodo, HttpRequest.BodyPublishers.ofString(cuerpo));
        } else {
            peticion.method(metodo, HttpRequest.BodyPublishers.noBody());
        }
        try {
            HttpResponse<String> respuesta = http.send(
                    peticion.build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            return new Respuesta(respuesta.statusCode(), respuesta.body(), respuesta.headers());
        } catch (IOException e) {
            throw new IllegalStateException(e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
    }

    Respuesta get(String ruta, String bearer) {
        return enviar("GET", ruta, bearer, null, null);
    }

    Respuesta post(String ruta, String bearer, String cuerpo) {
        return enviar("POST", ruta, bearer, null, cuerpo);
    }

    /** Sube un CSV como multipart/form-data (cargas masivas RF-30/32/34). */
    Respuesta postMultipart(String ruta, String bearer, String nombreArchivo, String contenidoCsv) {
        String boundary = "----ProyectoE2E" + System.nanoTime();
        String crlf = "\r\n";
        String cuerpo = "--" + boundary + crlf
                + "Content-Disposition: form-data; name=\"archivo\"; filename=\""
                + nombreArchivo + "\"" + crlf
                + "Content-Type: text/csv" + crlf + crlf
                + contenidoCsv + crlf
                + "--" + boundary + "--" + crlf;

        HttpRequest.Builder peticion = HttpRequest.newBuilder(
                        URI.create("http://localhost:" + puerto + ruta))
                .timeout(Duration.ofSeconds(30))
                .header("Content-Type",
                        "multipart/form-data; boundary=" + boundary)
                .POST(HttpRequest.BodyPublishers.ofString(cuerpo, StandardCharsets.UTF_8));
        if (bearer != null) {
            peticion.header("Authorization", "Bearer " + bearer);
        }
        try {
            HttpResponse<String> respuesta = http.send(
                    peticion.build(), HttpResponse.BodyHandlers.ofString(StandardCharsets.UTF_8));
            return new Respuesta(respuesta.statusCode(), respuesta.body(), respuesta.headers());
        } catch (IOException e) {
            throw new IllegalStateException(e);
        } catch (InterruptedException e) {
            Thread.currentThread().interrupt();
            throw new IllegalStateException(e);
        }
    }

    Respuesta login(String ci, String acceso) {
        return login(ci, CLAVE, acceso);
    }

    Respuesta login(String ci, String clave, String acceso) {
        return post("/api/auth/login", null, """
                {"ci":"%s","password":"%s","acceso":"%s","plataforma":"WEB"}
                """.formatted(ci, clave, acceso));
    }

    String token(String ci, String acceso) {
        Respuesta r = login(ci, acceso);
        assertTrue(r.estado() == 200,
                "Login fallido para " + acceso + ": " + r.estado() + " " + r.cuerpo());
        return r.json().path("token").asString();
    }

    String tokenSocio(String ci) {
        return token(ci, "SOCIO");
    }

    String tokenEmpleado(String ci) {
        return token(ci, "EMPLEADO");
    }

    /* ---------- Datos de agenda ---------- */

    static int diaSemana(LocalDate fecha) {
        return fecha.getDayOfWeek().getValue();
    }

    /** Crea por la API (RF-13) un turno de una fecha con numeros de 20 minutos desde las 09:00. */
    long crearTurnoPorApi(String tokenFuncionario, LocalDate fecha, int cantidadNumeros) {
        List<String> numeros = new ArrayList<>();
        for (int i = 0; i < cantidadNumeros; i++) {
            int inicio = 9 * 60 + i * 20;
            numeros.add("{\"numero\":%d,\"horaInicio\":\"%s\",\"horaFin\":\"%s\"}".formatted(
                    i + 1, hora(inicio), hora(inicio + 20)));
        }
        Respuesta r = post("/api/turnos-semanales", tokenFuncionario, """
                {"medicoId":%d,"especialidadId":%d,"consultorioId":%d,"diaSemana":%d,
                 "fechaInicio":"%s","fechaFin":"%s","numeros":[%s]}
                """.formatted(idMedico, idEspecialidad, idConsultorio, diaSemana(fecha),
                fecha, fecha, String.join(",", numeros)));
        assertTrue(r.estado() == 201, "Alta de turno semanal: " + r.estado() + " " + r.cuerpo());
        return jdbc.queryForObject(
                "SELECT id_turno FROM turno WHERE fecha = ? ORDER BY id_turno DESC LIMIT 1",
                Long.class, fecha);
    }

    static String hora(int minutos) {
        return "%02d:%02d".formatted(minutos / 60, minutos % 60);
    }

    long numeroId(long turnoId, int numero) {
        return jdbc.queryForObject(
                "SELECT id_numero FROM numero WHERE id_turno = ? AND numero = ?",
                Long.class, turnoId, numero);
    }

    /** Siembra directamente (solo en la base efimera) un turno con sus numeros desde las 10:00. */
    long sembrarTurno(LocalDate fecha, int cantidadNumeros) {
        long semanal = jdbc.queryForObject(
                "INSERT INTO turno_semanal (id_medico, id_especialidad, id_consultorio,"
                        + " id_funcionario_alta, dia_semana, fecha_inicio, fecha_fin)"
                        + " VALUES (?, ?, ?, ?, ?, ?, ?) RETURNING id_turno_semanal",
                Long.class, idMedico, idEspecialidad, idConsultorio, idFuncionario,
                diaSemana(fecha), fecha, fecha);
        long turno = jdbc.queryForObject(
                "INSERT INTO turno (id_turno_semanal, id_consultorio, fecha) VALUES (?, ?, ?)"
                        + " RETURNING id_turno", Long.class, semanal, idConsultorio, fecha);
        for (int i = 0; i < cantidadNumeros; i++) {
            int inicio = 10 * 60 + i * 20;
            long patron = jdbc.queryForObject(
                    "INSERT INTO numero_semanal (id_turno_semanal, numero, hora_inicio, hora_fin)"
                            + " VALUES (?, ?, ?::time, ?::time) RETURNING id_numero_semanal",
                    Long.class, semanal, i + 1, hora(inicio), hora(inicio + 20));
            jdbc.update("INSERT INTO numero (id_turno, id_numero_semanal, numero, hora_inicio, hora_fin)"
                    + " VALUES (?, ?, ?, ?::time, ?::time)",
                    turno, patron, i + 1, hora(inicio), hora(inicio + 20));
        }
        return turno;
    }

    long sembrarConsulta(long socio, long numero) {
        return jdbc.queryForObject(
                "INSERT INTO consulta (id_socio, id_numero) VALUES (?, ?) RETURNING id_consulta",
                Long.class, socio, numero);
    }

    String estadoConsulta(long consultaId) {
        return jdbc.queryForObject(
                "SELECT estado FROM consulta WHERE id_consulta = ?", String.class, consultaId);
    }

    int contar(String tabla) {
        return jdbc.queryForObject("SELECT count(*) FROM " + tabla, Integer.class);
    }
}
