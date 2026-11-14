package uy.edu.proyecto.backend.parametro;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.junit.jupiter.api.Assertions.assertTrue;

class ParametroServiceTest {

    /** Variables de entorno, en el orden de los argumentos del constructor. */
    private static final String[] VARIABLES = {
            "PARAM_AGENDAR_ANTICIPACION_MAXIMA_DIAS",
            "PARAM_AGENDAR_ANTICIPACION_MINIMA_HORAS",
            "PARAM_CANCELAR_ANTICIPACION_MINIMA_HORAS",
            "PARAM_CONSULTAS_ACTIVAS_POR_ESPECIALIDAD",
            "PARAM_CONSULTAS_ACTIVAS_TOTAL",
            "PARAM_NUMERO_DURACION_MINIMA_MINUTOS",
            "PARAM_NUMERO_DURACION_MAXIMA_MINUTOS",
            "PARAM_NUMERO_DURACION_PASO_MINUTOS",
            "PARAM_PASE_VIGENCIA_INICIAL_DIAS",
            "PARAM_PASE_VIGENCIA_MINIMA_DIAS",
            "PARAM_PASE_VIGENCIA_MAXIMA_DIAS",
            "PARAM_RECORDATORIO_ANTELACION_HORAS"
    };

    private static Integer[] valoresPorDefecto() {
        return new Integer[] {30, 2, 2, 1, 3, 10, 60, 5, 90, 1, 365, 24};
    }

    private static ParametroService crear(Integer[] v) {
        return new ParametroService(
                v[0], v[1], v[2], v[3], v[4], v[5], v[6], v[7], v[8], v[9], v[10], v[11]);
    }

    private static Integer[] con(int indice, Integer valor) {
        Integer[] valores = valoresPorDefecto();
        valores[indice] = valor;
        return valores;
    }

    @Test
    void porDefectoTieneLosValoresDeLaSeccion313() {
        ParametroService p = ParametroService.porDefecto();

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
    }

    @Test
    void cadaParametroGuardaSuPropioValor() {
        ParametroService p = crear(new Integer[] {45, 3, 4, 2, 5, 15, 95, 10, 60, 2, 100, 48});

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
    }

    @Test
    void unValorNuloHaceFallarElArranqueNombrandoLaVariable() {
        for (int i = 0; i < VARIABLES.length; i++) {
            Integer[] valores = con(i, null);
            IllegalStateException error = assertThrows(
                    IllegalStateException.class, () -> crear(valores));
            assertTrue(error.getMessage().contains(VARIABLES[i]), error.getMessage());
        }
    }

    @Test
    void unValorCeroHaceFallarElArranqueNombrandoLaVariable() {
        for (int i = 0; i < VARIABLES.length; i++) {
            Integer[] valores = con(i, 0);
            IllegalStateException error = assertThrows(
                    IllegalStateException.class, () -> crear(valores));
            assertTrue(error.getMessage().contains(VARIABLES[i]), error.getMessage());
        }
    }

    @Test
    void unValorNegativoHaceFallarElArranqueNombrandoLaVariable() {
        for (int i = 0; i < VARIABLES.length; i++) {
            Integer[] valores = con(i, -1);
            IllegalStateException error = assertThrows(
                    IllegalStateException.class, () -> crear(valores));
            assertTrue(error.getMessage().contains(VARIABLES[i]), error.getMessage());
        }
    }

    @Test
    void laDuracionMinimaMayorQueLaMaximaHaceFallarElArranque() {
        Integer[] valores = con(5, 70);

        IllegalStateException error = assertThrows(
                IllegalStateException.class, () -> crear(valores));

        assertTrue(error.getMessage().contains("PARAM_NUMERO_DURACION_MINIMA_MINUTOS"),
                error.getMessage());
        assertTrue(error.getMessage().contains("PARAM_NUMERO_DURACION_MAXIMA_MINUTOS"),
                error.getMessage());
    }

    @Test
    void laVigenciaMinimaDePaseMayorQueLaMaximaHaceFallarElArranque() {
        Integer[] valores = con(9, 400);

        IllegalStateException error = assertThrows(
                IllegalStateException.class, () -> crear(valores));

        assertTrue(error.getMessage().contains("PARAM_PASE_VIGENCIA_MINIMA_DIAS"),
                error.getMessage());
        assertTrue(error.getMessage().contains("PARAM_PASE_VIGENCIA_MAXIMA_DIAS"),
                error.getMessage());
    }

    @Test
    void unPasoQueNoDivideElRangoHaceFallarElArranque() {
        // El rango es 60 - 10 = 50: 7 no lo divide, y 60 tampoco (es mayor que el rango).
        for (int paso : new int[] {7, 60}) {
            Integer[] valores = con(7, paso);
            IllegalStateException error = assertThrows(
                    IllegalStateException.class, () -> crear(valores));
            assertTrue(error.getMessage().contains("PARAM_NUMERO_DURACION_PASO_MINUTOS"),
                    error.getMessage());
        }
    }

    @Test
    void unPasoQueDivideElRangoEsValido() {
        // 50 / 25 = 2, 50 / 50 = 1 y 50 / 1 = 50.
        for (int paso : new int[] {25, 50, 1}) {
            Integer[] valores = con(7, paso);
            ParametroService p = assertDoesNotThrow(() -> crear(valores));
            assertEquals(paso, p.numeroDuracionPasoMinutos());
        }
    }

    @Test
    void conDuracionMinimaIgualALaMaximaCualquierPasoEsValido() {
        Integer[] valores = valoresPorDefecto();
        valores[5] = 30;
        valores[6] = 30;
        valores[7] = 5;

        assertDoesNotThrow(() -> crear(valores));
    }

    @Test
    void laVigenciaInicialDePaseFueraDelRangoPermitidoHaceFallarElArranque() {
        Integer[] masQueElMaximo = con(8, 400);
        Integer[] menosQueElMinimo = valoresPorDefecto();
        menosQueElMinimo[8] = 1;
        menosQueElMinimo[9] = 2;

        for (Integer[] valores : new Integer[][] {masQueElMaximo, menosQueElMinimo}) {
            IllegalStateException error = assertThrows(
                    IllegalStateException.class, () -> crear(valores));
            assertTrue(error.getMessage().contains("PARAM_PASE_VIGENCIA_INICIAL_DIAS"),
                    error.getMessage());
        }
    }

    @Test
    void lasUnidadesUsanSingularYPlural() {
        assertEquals("1 hora", ParametroService.horas(1));
        assertEquals("2 horas", ParametroService.horas(2));
        assertEquals("1 día", ParametroService.dias(1));
        assertEquals("30 días", ParametroService.dias(30));
        assertEquals("1 minuto", ParametroService.minutos(1));
        assertEquals("5 minutos", ParametroService.minutos(5));
        assertEquals("1 consulta", ParametroService.consultas(1));
        assertEquals("3 consultas", ParametroService.consultas(3));
    }
}
