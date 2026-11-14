package uy.edu.proyecto.backend.parametro;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

/**
 * Comprueba el cableado entre las variables PARAM_*, application.properties y
 * ParametroService, sin base de datos: levanta solo ese bean.
 */
class ParametroPropiedadesTest {

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withInitializer(new ConfigDataApplicationContextInitializer())
            .withUserConfiguration(ParametroService.class);

    @Test
    void applicationPropertiesDeclaraCadaVariableConSuValorPorDefecto() throws IOException {
        Properties propiedades = new Properties();
        try (InputStream in = getClass().getResourceAsStream("/application.properties")) {
            propiedades.load(in);
        }

        assertEquals("${PARAM_AGENDAR_ANTICIPACION_MAXIMA_DIAS:30}",
                propiedades.getProperty("app.parametros.agendar-anticipacion-maxima-dias"));
        assertEquals("${PARAM_AGENDAR_ANTICIPACION_MINIMA_HORAS:2}",
                propiedades.getProperty("app.parametros.agendar-anticipacion-minima-horas"));
        assertEquals("${PARAM_CANCELAR_ANTICIPACION_MINIMA_HORAS:2}",
                propiedades.getProperty("app.parametros.cancelar-anticipacion-minima-horas"));
        assertEquals("${PARAM_CONSULTAS_ACTIVAS_POR_ESPECIALIDAD:1}",
                propiedades.getProperty("app.parametros.consultas-activas-por-especialidad"));
        assertEquals("${PARAM_CONSULTAS_ACTIVAS_TOTAL:3}",
                propiedades.getProperty("app.parametros.consultas-activas-total"));
        assertEquals("${PARAM_NUMERO_DURACION_MINIMA_MINUTOS:10}",
                propiedades.getProperty("app.parametros.numero-duracion-minima-minutos"));
        assertEquals("${PARAM_NUMERO_DURACION_MAXIMA_MINUTOS:60}",
                propiedades.getProperty("app.parametros.numero-duracion-maxima-minutos"));
        assertEquals("${PARAM_NUMERO_DURACION_PASO_MINUTOS:5}",
                propiedades.getProperty("app.parametros.numero-duracion-paso-minutos"));
        assertEquals("${PARAM_PASE_VIGENCIA_INICIAL_DIAS:90}",
                propiedades.getProperty("app.parametros.pase-vigencia-inicial-dias"));
        assertEquals("${PARAM_PASE_VIGENCIA_MINIMA_DIAS:1}",
                propiedades.getProperty("app.parametros.pase-vigencia-minima-dias"));
        assertEquals("${PARAM_PASE_VIGENCIA_MAXIMA_DIAS:365}",
                propiedades.getProperty("app.parametros.pase-vigencia-maxima-dias"));
        assertEquals("${PARAM_RECORDATORIO_ANTELACION_HORAS:24}",
                propiedades.getProperty("app.parametros.recordatorio-antelacion-horas"));
    }

    @Test
    void lasPropiedadesDeAuthConservanSuNombreYSuVariable() throws IOException {
        Properties propiedades = new Properties();
        try (InputStream in = getClass().getResourceAsStream("/application.properties")) {
            propiedades.load(in);
        }

        assertEquals("${PASSWORD_MIN_LENGTH:8}",
                propiedades.getProperty("app.auth.password-min-length"));
        assertEquals("${FIRST_LOGIN_TOKEN_VALIDITY_HOURS:24}",
                propiedades.getProperty("app.auth.first-login-token-validity-hours"));
        assertEquals("${EMAIL_CHANGE_TOKEN_VALIDITY_HOURS:24}",
                propiedades.getProperty("app.auth.email-change-token-validity-hours"));
        assertEquals("${RECOVERY_TOKEN_VALIDITY_HOURS:24}",
                propiedades.getProperty("app.auth.recovery-token-validity-hours"));
    }

    @Test
    void cadaPropiedadDeAuthLlegaAlParametroQueLeCorresponde() {
        runner.withPropertyValues(
                        "app.auth.password-min-length=12",
                        "app.auth.first-login-token-validity-hours=36",
                        "app.auth.email-change-token-validity-hours=72",
                        "app.auth.recovery-token-validity-hours=6")
                .run(contexto -> {
                    ParametroService p = contexto.getBean(ParametroService.class);

                    assertEquals(12, p.contrasenaLongitudMinima());
                    assertEquals(36, p.enlacePrimerIngresoHoras());
                    assertEquals(72, p.enlaceCambioCorreoHoras());
                    assertEquals(6, p.enlaceRecuperacionHoras());
                });
    }

    @Test
    void sinVariablesDeAuthQuedanLosValoresDeSiempre() {
        runner.run(contexto -> {
            ParametroService p = contexto.getBean(ParametroService.class);

            assertEquals(8, p.contrasenaLongitudMinima());
            assertEquals(24, p.enlacePrimerIngresoHoras());
            assertEquals(24, p.enlaceCambioCorreoHoras());
            assertEquals(24, p.enlaceRecuperacionHoras());
        });
    }

    @Test
    void sinVariablesDeEntornoQuedanLosValoresDeLaSeccion313() {
        runner.run(contexto -> {
            ParametroService p = contexto.getBean(ParametroService.class);

            assertEquals(30, p.agendarAnticipacionMaximaDias());
            assertEquals(2, p.agendarAnticipacionMinimaHoras());
            assertEquals(2, p.cancelarAnticipacionMinimaHoras());
            assertEquals(1, p.consultasActivasPorEspecialidad());
            assertEquals(3, p.consultasActivasTotal());
            assertEquals(10, p.numeroDuracionMinimaMinutos());
            assertEquals(60, p.numeroDuracionMaximaMinutos());
            assertEquals(5, p.numeroDuracionPasoMinutos());
            assertEquals(90, p.paseVigenciaInicialDias());
            assertEquals(1, p.paseVigenciaMinimaDias());
            assertEquals(365, p.paseVigenciaMaximaDias());
            assertEquals(24, p.recordatorioAntelacionHoras());
        });
    }

    @Test
    void cadaPropiedadLlegaAlParametroQueLeCorresponde() {
        runner.withPropertyValues(
                        "app.parametros.agendar-anticipacion-maxima-dias=45",
                        "app.parametros.agendar-anticipacion-minima-horas=3",
                        "app.parametros.cancelar-anticipacion-minima-horas=4",
                        "app.parametros.consultas-activas-por-especialidad=2",
                        "app.parametros.consultas-activas-total=5",
                        "app.parametros.numero-duracion-minima-minutos=15",
                        "app.parametros.numero-duracion-maxima-minutos=95",
                        "app.parametros.numero-duracion-paso-minutos=10",
                        "app.parametros.pase-vigencia-inicial-dias=60",
                        "app.parametros.pase-vigencia-minima-dias=2",
                        "app.parametros.pase-vigencia-maxima-dias=100",
                        "app.parametros.recordatorio-antelacion-horas=48")
                .run(contexto -> {
                    ParametroService p = contexto.getBean(ParametroService.class);

                    assertEquals(45, p.agendarAnticipacionMaximaDias());
                    assertEquals(3, p.agendarAnticipacionMinimaHoras());
                    assertEquals(4, p.cancelarAnticipacionMinimaHoras());
                    assertEquals(2, p.consultasActivasPorEspecialidad());
                    assertEquals(5, p.consultasActivasTotal());
                    assertEquals(15, p.numeroDuracionMinimaMinutos());
                    assertEquals(95, p.numeroDuracionMaximaMinutos());
                    assertEquals(10, p.numeroDuracionPasoMinutos());
                    assertEquals(60, p.paseVigenciaInicialDias());
                    assertEquals(2, p.paseVigenciaMinimaDias());
                    assertEquals(100, p.paseVigenciaMaximaDias());
                    assertEquals(48, p.recordatorioAntelacionHoras());
                });
    }

    @Test
    void unValorInvalidoEnLaConfiguracionHaceFallarElArranque() {
        runner.withPropertyValues("app.parametros.consultas-activas-total=0")
                .run(contexto -> {
                    assertTrue(contexto.getStartupFailure() != null);
                    Throwable causa = contexto.getStartupFailure();
                    while (causa.getCause() != null) {
                        causa = causa.getCause();
                    }
                    assertTrue(causa instanceof IllegalStateException, causa.toString());
                    assertTrue(causa.getMessage().contains("PARAM_CONSULTAS_ACTIVAS_TOTAL"),
                            causa.getMessage());
                });
    }
}
