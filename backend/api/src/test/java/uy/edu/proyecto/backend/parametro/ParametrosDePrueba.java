package uy.edu.proyecto.backend.parametro;

/**
 * Arma un ParametroService para los tests: parte de los valores por defecto de
 * la seccion 3.1.3 y deja cambiar uno o varios.
 */
public final class ParametrosDePrueba {

    private int agendarMaximaDias = 30;
    private int agendarMinimaHoras = 2;
    private int cancelarMinimaHoras = 2;
    private int consultasPorEspecialidad = 1;
    private int consultasTotal = 3;
    private int duracionMinima = 10;
    private int duracionMaxima = 60;
    private int duracionPaso = 5;
    private int paseInicial = 90;
    private int paseMinima = 1;
    private int paseMaxima = 365;
    private int recordatorioHoras = 24;

    private ParametrosDePrueba() {
    }

    public static ParametrosDePrueba nuevo() {
        return new ParametrosDePrueba();
    }

    public ParametrosDePrueba agendar(int minimaHoras, int maximaDias) {
        this.agendarMinimaHoras = minimaHoras;
        this.agendarMaximaDias = maximaDias;
        return this;
    }

    public ParametrosDePrueba cancelarHoras(int valor) {
        this.cancelarMinimaHoras = valor;
        return this;
    }

    public ParametrosDePrueba consultasPorEspecialidad(int valor) {
        this.consultasPorEspecialidad = valor;
        return this;
    }

    public ParametrosDePrueba consultasTotal(int valor) {
        this.consultasTotal = valor;
        return this;
    }

    public ParametrosDePrueba duracion(int minimo, int maximo, int paso) {
        this.duracionMinima = minimo;
        this.duracionMaxima = maximo;
        this.duracionPaso = paso;
        return this;
    }

    public ParametrosDePrueba paseVigencia(int inicial, int minima, int maxima) {
        this.paseInicial = inicial;
        this.paseMinima = minima;
        this.paseMaxima = maxima;
        return this;
    }

    public ParametroService construir() {
        return new ParametroService(
                agendarMaximaDias, agendarMinimaHoras, cancelarMinimaHoras,
                consultasPorEspecialidad, consultasTotal,
                duracionMinima, duracionMaxima, duracionPaso,
                paseInicial, paseMinima, paseMaxima, recordatorioHoras);
    }
}
