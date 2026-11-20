package uy.edu.proyecto.backend.notificacion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;

import java.io.IOException;
import java.io.InputStream;
import java.util.Properties;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.ConfigDataApplicationContextInitializer;
import org.springframework.boot.test.context.runner.ApplicationContextRunner;

/**
 * La propiedad app.notificaciones.procesos-programados.habilitados (variable
 * NOTIFICACIONES_PROCESOS_PROGRAMADOS_HABILITADOS) apaga los procesos
 * programados de avisos: el poller de envios y la generacion de recordatorios. El listener que envia al
 * crearse la notificacion no depende de ella.
 */
class ProcesosProgramadosHabilitadosTest {

    private static final String PROPIEDAD =
            "app.notificaciones.procesos-programados.habilitados";

    private final ApplicationContextRunner runner = new ApplicationContextRunner()
            .withBean(EnvioNotificacionDispatcher.class,
                    () -> mock(EnvioNotificacionDispatcher.class))
            .withBean(RecordatorioConsultaService.class,
                    () -> mock(RecordatorioConsultaService.class))
            .withUserConfiguration(EnvioNotificacionPoller.class,
                    EnvioNotificacionListener.class,
                    RecordatorioConsultaProceso.class);

    @Test
    void sinLaPropiedadElPollerEstaActivo() {
        runner.run(contexto -> assertTrue(contexto.containsBean("envioNotificacionPoller")));
    }

    @Test
    void conTrueElPollerEstaActivo() {
        runner.withPropertyValues(PROPIEDAD + "=true")
                .run(contexto -> assertTrue(
                        contexto.containsBean("envioNotificacionPoller")));
    }

    @Test
    void conFalseNoHayPollerProgramado() {
        runner.withPropertyValues(PROPIEDAD + "=false")
                .run(contexto -> assertFalse(
                        contexto.containsBean("envioNotificacionPoller")));
    }

    @Test
    void conFalseElListenerQueEnviaAlCrearseSigueActivo() {
        runner.withPropertyValues(PROPIEDAD + "=false")
                .run(contexto -> assertTrue(
                        contexto.containsBean("envioNotificacionListener")));
    }

    @Test
    void conTrueElListenerTambienEstaActivo() {
        runner.withPropertyValues(PROPIEDAD + "=true")
                .run(contexto -> assertTrue(
                        contexto.containsBean("envioNotificacionListener")));
    }

    @Test
    void sinLaPropiedadElProcesoDeRecordatoriosEstaActivo() {
        runner.run(contexto -> assertTrue(
                contexto.containsBean("recordatorioConsultaProceso")));
    }

    @Test
    void conTrueElProcesoDeRecordatoriosEstaActivo() {
        runner.withPropertyValues(PROPIEDAD + "=true")
                .run(contexto -> assertTrue(
                        contexto.containsBean("recordatorioConsultaProceso")));
    }

    @Test
    void conFalseNoHayProcesoDeRecordatorios() {
        runner.withPropertyValues(PROPIEDAD + "=false")
                .run(contexto -> assertFalse(
                        contexto.containsBean("recordatorioConsultaProceso")));
    }

    @Test
    void conLaConfiguracionRealLaVariableEnFalseApagaElProcesoDeRecordatorios() {
        runner.withInitializer(new ConfigDataApplicationContextInitializer())
                .withPropertyValues(
                        "NOTIFICACIONES_PROCESOS_PROGRAMADOS_HABILITADOS=false")
                .run(contexto -> assertFalse(
                        contexto.containsBean("recordatorioConsultaProceso")));
    }

    @Test
    void applicationPropertiesDeclaraLaVariableConValorPorDefectoTrue()
            throws IOException {
        Properties propiedades = new Properties();
        try (InputStream in = getClass().getResourceAsStream("/application.properties")) {
            propiedades.load(in);
        }

        assertEquals("${NOTIFICACIONES_PROCESOS_PROGRAMADOS_HABILITADOS:true}",
                propiedades.getProperty(PROPIEDAD));
    }

    @Test
    void conLaConfiguracionRealSinVariableElPollerEstaActivo() {
        runner.withInitializer(new ConfigDataApplicationContextInitializer())
                .run(contexto -> assertTrue(
                        contexto.containsBean("envioNotificacionPoller")));
    }

    @Test
    void conLaConfiguracionRealLaVariableEnFalseApagaElPoller() {
        runner.withInitializer(new ConfigDataApplicationContextInitializer())
                .withPropertyValues(
                        "NOTIFICACIONES_PROCESOS_PROGRAMADOS_HABILITADOS=false")
                .run(contexto -> {
                    assertFalse(contexto.containsBean("envioNotificacionPoller"));
                    assertTrue(contexto.containsBean("envioNotificacionListener"));
                });
    }
}
