package uy.edu.proyecto.backend.parametro;

import java.time.OffsetDateTime;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.stereotype.Service;

/**
 * Unico punto de lectura de los parametros configurables (RNF-26, seccion 3.1.3
 * de Requerimientos). Los valores vienen de variables de entorno PARAM_* por
 * medio de app.parametros.* en application.properties.
 *
 * Valida todo al construirse: un valor nulo, cero o negativo, un minimo mayor
 * que su maximo o un paso que no divide el rango hacen fallar el arranque con un
 * mensaje que nombra la variable de entorno.
 */
@Service
public class ParametroService {

    static final String AGENDAR_ANTICIPACION_MAXIMA_DIAS = "PARAM_AGENDAR_ANTICIPACION_MAXIMA_DIAS";
    static final String AGENDAR_ANTICIPACION_MINIMA_HORAS = "PARAM_AGENDAR_ANTICIPACION_MINIMA_HORAS";
    static final String CANCELAR_ANTICIPACION_MINIMA_HORAS = "PARAM_CANCELAR_ANTICIPACION_MINIMA_HORAS";
    static final String CONSULTAS_ACTIVAS_POR_ESPECIALIDAD = "PARAM_CONSULTAS_ACTIVAS_POR_ESPECIALIDAD";
    static final String CONSULTAS_ACTIVAS_TOTAL = "PARAM_CONSULTAS_ACTIVAS_TOTAL";
    static final String NUMERO_DURACION_MINIMA_MINUTOS = "PARAM_NUMERO_DURACION_MINIMA_MINUTOS";
    static final String NUMERO_DURACION_MAXIMA_MINUTOS = "PARAM_NUMERO_DURACION_MAXIMA_MINUTOS";
    static final String NUMERO_DURACION_PASO_MINUTOS = "PARAM_NUMERO_DURACION_PASO_MINUTOS";
    static final String PASE_VIGENCIA_INICIAL_DIAS = "PARAM_PASE_VIGENCIA_INICIAL_DIAS";
    static final String PASE_VIGENCIA_MINIMA_DIAS = "PARAM_PASE_VIGENCIA_MINIMA_DIAS";
    static final String PASE_VIGENCIA_MAXIMA_DIAS = "PARAM_PASE_VIGENCIA_MAXIMA_DIAS";
    static final String RECORDATORIO_ANTELACION_HORAS = "PARAM_RECORDATORIO_ANTELACION_HORAS";

    private final int agendarAnticipacionMaximaDias;
    private final int agendarAnticipacionMinimaHoras;
    private final int cancelarAnticipacionMinimaHoras;
    private final int consultasActivasPorEspecialidad;
    private final int consultasActivasTotal;
    private final int numeroDuracionMinimaMinutos;
    private final int numeroDuracionMaximaMinutos;
    private final int numeroDuracionPasoMinutos;
    private final int paseVigenciaInicialDias;
    private final int paseVigenciaMinimaDias;
    private final int paseVigenciaMaximaDias;
    private final int recordatorioAntelacionHoras;

    public ParametroService(
            @Value("${app.parametros.agendar-anticipacion-maxima-dias:30}")
            Integer agendarAnticipacionMaximaDias,
            @Value("${app.parametros.agendar-anticipacion-minima-horas:2}")
            Integer agendarAnticipacionMinimaHoras,
            @Value("${app.parametros.cancelar-anticipacion-minima-horas:2}")
            Integer cancelarAnticipacionMinimaHoras,
            @Value("${app.parametros.consultas-activas-por-especialidad:1}")
            Integer consultasActivasPorEspecialidad,
            @Value("${app.parametros.consultas-activas-total:3}")
            Integer consultasActivasTotal,
            @Value("${app.parametros.numero-duracion-minima-minutos:10}")
            Integer numeroDuracionMinimaMinutos,
            @Value("${app.parametros.numero-duracion-maxima-minutos:60}")
            Integer numeroDuracionMaximaMinutos,
            @Value("${app.parametros.numero-duracion-paso-minutos:5}")
            Integer numeroDuracionPasoMinutos,
            @Value("${app.parametros.pase-vigencia-inicial-dias:90}")
            Integer paseVigenciaInicialDias,
            @Value("${app.parametros.pase-vigencia-minima-dias:1}")
            Integer paseVigenciaMinimaDias,
            @Value("${app.parametros.pase-vigencia-maxima-dias:365}")
            Integer paseVigenciaMaximaDias,
            @Value("${app.parametros.recordatorio-antelacion-horas:24}")
            Integer recordatorioAntelacionHoras
    ) {
        this.agendarAnticipacionMaximaDias =
                positivo(AGENDAR_ANTICIPACION_MAXIMA_DIAS, agendarAnticipacionMaximaDias);
        this.agendarAnticipacionMinimaHoras =
                positivo(AGENDAR_ANTICIPACION_MINIMA_HORAS, agendarAnticipacionMinimaHoras);
        this.cancelarAnticipacionMinimaHoras =
                positivo(CANCELAR_ANTICIPACION_MINIMA_HORAS, cancelarAnticipacionMinimaHoras);
        this.consultasActivasPorEspecialidad =
                positivo(CONSULTAS_ACTIVAS_POR_ESPECIALIDAD, consultasActivasPorEspecialidad);
        this.consultasActivasTotal = positivo(CONSULTAS_ACTIVAS_TOTAL, consultasActivasTotal);
        this.numeroDuracionMinimaMinutos =
                positivo(NUMERO_DURACION_MINIMA_MINUTOS, numeroDuracionMinimaMinutos);
        this.numeroDuracionMaximaMinutos =
                positivo(NUMERO_DURACION_MAXIMA_MINUTOS, numeroDuracionMaximaMinutos);
        this.numeroDuracionPasoMinutos =
                positivo(NUMERO_DURACION_PASO_MINUTOS, numeroDuracionPasoMinutos);
        this.paseVigenciaInicialDias =
                positivo(PASE_VIGENCIA_INICIAL_DIAS, paseVigenciaInicialDias);
        this.paseVigenciaMinimaDias =
                positivo(PASE_VIGENCIA_MINIMA_DIAS, paseVigenciaMinimaDias);
        this.paseVigenciaMaximaDias =
                positivo(PASE_VIGENCIA_MAXIMA_DIAS, paseVigenciaMaximaDias);
        this.recordatorioAntelacionHoras =
                positivo(RECORDATORIO_ANTELACION_HORAS, recordatorioAntelacionHoras);

        validarRangos();
    }

    /** Los valores de la seccion 3.1.3 de Requerimientos, para tests y como referencia. */
    public static ParametroService porDefecto() {
        return new ParametroService(30, 2, 2, 1, 3, 10, 60, 5, 90, 1, 365, 24);
    }

    /**
     * Regla unica de la ventana de agendar: desde ahora mas la anticipacion
     * minima hasta ahora mas la maxima, ambos como instantes.
     */
    public VentanaAgendar ventanaAgendar(OffsetDateTime ahora) {
        return new VentanaAgendar(
                ahora.plusHours(agendarAnticipacionMinimaHoras),
                ahora.plusDays(agendarAnticipacionMaximaDias));
    }

    public int agendarAnticipacionMaximaDias() {
        return agendarAnticipacionMaximaDias;
    }

    public int agendarAnticipacionMinimaHoras() {
        return agendarAnticipacionMinimaHoras;
    }

    public int cancelarAnticipacionMinimaHoras() {
        return cancelarAnticipacionMinimaHoras;
    }

    public int consultasActivasPorEspecialidad() {
        return consultasActivasPorEspecialidad;
    }

    public int consultasActivasTotal() {
        return consultasActivasTotal;
    }

    public int numeroDuracionMinimaMinutos() {
        return numeroDuracionMinimaMinutos;
    }

    public int numeroDuracionMaximaMinutos() {
        return numeroDuracionMaximaMinutos;
    }

    public int numeroDuracionPasoMinutos() {
        return numeroDuracionPasoMinutos;
    }

    public int paseVigenciaInicialDias() {
        return paseVigenciaInicialDias;
    }

    public int paseVigenciaMinimaDias() {
        return paseVigenciaMinimaDias;
    }

    public int paseVigenciaMaximaDias() {
        return paseVigenciaMaximaDias;
    }

    public int recordatorioAntelacionHoras() {
        return recordatorioAntelacionHoras;
    }

    /** "1 hora" o "2 horas": para armar los mensajes con el valor del parametro. */
    public static String horas(int cantidad) {
        return cantidad + (cantidad == 1 ? " hora" : " horas");
    }

    public static String dias(int cantidad) {
        return cantidad + (cantidad == 1 ? " día" : " días");
    }

    public static String minutos(int cantidad) {
        return cantidad + (cantidad == 1 ? " minuto" : " minutos");
    }

    public static String consultas(int cantidad) {
        return cantidad + (cantidad == 1 ? " consulta" : " consultas");
    }

    private void validarRangos() {
        if (numeroDuracionMinimaMinutos > numeroDuracionMaximaMinutos) {
            throw new IllegalStateException(
                    NUMERO_DURACION_MINIMA_MINUTOS + " (" + numeroDuracionMinimaMinutos
                            + ") no puede ser mayor que " + NUMERO_DURACION_MAXIMA_MINUTOS
                            + " (" + numeroDuracionMaximaMinutos + ")");
        }
        int rango = numeroDuracionMaximaMinutos - numeroDuracionMinimaMinutos;
        if (rango % numeroDuracionPasoMinutos != 0) {
            throw new IllegalStateException(
                    NUMERO_DURACION_PASO_MINUTOS + " (" + numeroDuracionPasoMinutos
                            + ") debe dividir el rango entre "
                            + NUMERO_DURACION_MINIMA_MINUTOS + " y "
                            + NUMERO_DURACION_MAXIMA_MINUTOS + " (" + rango + " minutos)");
        }
        if (paseVigenciaMinimaDias > paseVigenciaMaximaDias) {
            throw new IllegalStateException(
                    PASE_VIGENCIA_MINIMA_DIAS + " (" + paseVigenciaMinimaDias
                            + ") no puede ser mayor que " + PASE_VIGENCIA_MAXIMA_DIAS
                            + " (" + paseVigenciaMaximaDias + ")");
        }
        if (paseVigenciaInicialDias < paseVigenciaMinimaDias
                || paseVigenciaInicialDias > paseVigenciaMaximaDias) {
            throw new IllegalStateException(
                    PASE_VIGENCIA_INICIAL_DIAS + " (" + paseVigenciaInicialDias
                            + ") debe estar entre " + PASE_VIGENCIA_MINIMA_DIAS + " ("
                            + paseVigenciaMinimaDias + ") y " + PASE_VIGENCIA_MAXIMA_DIAS
                            + " (" + paseVigenciaMaximaDias + ")");
        }
    }

    private static int positivo(String variable, Integer valor) {
        if (valor == null) {
            throw new IllegalStateException(variable + " no puede estar vacío");
        }
        if (valor <= 0) {
            throw new IllegalStateException(
                    variable + " debe ser un número entero mayor que cero (valor: " + valor + ")");
        }
        return valor;
    }
}
