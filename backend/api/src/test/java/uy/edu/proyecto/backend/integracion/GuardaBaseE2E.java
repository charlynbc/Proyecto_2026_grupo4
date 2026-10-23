package uy.edu.proyecto.backend.integracion;

import java.util.regex.Matcher;
import java.util.regex.Pattern;

/**
 * Condiciones que debe cumplir una base antes de reinicializarla (DROP SCHEMA).
 * Se evalua sin conectar: primero se valida todo y recien despues se toca la base.
 */
final class GuardaBaseE2E {

    static final String VARIABLE_HABILITACION = "E2E_ALLOW_DESTRUCTIVE";
    static final String MARCA = "proyecto-e2e-descartable";

    // Nombres en minusculas, empiezan con letra y terminan en _e2e o _test.
    private static final Pattern URL_BASE = Pattern.compile(
            "^jdbc:postgresql://(localhost|127\\.0\\.0\\.1)(:\\d{1,5})?/([a-z][a-z0-9_]{0,40}_(?:e2e|test))$");

    private GuardaBaseE2E() {
    }

    /** Devuelve el nombre de la base si la URL y la habilitacion son validas; si no, lanza. */
    static String validar(String url, String habilitacion) {
        if (!"true".equals(habilitacion)) {
            throw new IllegalStateException(VARIABLE_HABILITACION
                    + "=true es obligatorio para reinicializar la base de pruebas");
        }
        return nombreBase(url);
    }

    static String nombreBase(String url) {
        Matcher coincidencia = url == null ? null : URL_BASE.matcher(url);
        if (coincidencia == null || !coincidencia.matches()) {
            throw new IllegalStateException("Base no autorizada: solo se admite localhost/127.0.0.1 con "
                    + "un nombre en minusculas [a-z][a-z0-9_]* que termine en _e2e o _test");
        }
        return coincidencia.group(3);
    }

    /** Identificador ya validado, entrecomillado para SQL. */
    static String identificador(String nombre) {
        return "\"" + nombre.replace("\"", "\"\"") + "\"";
    }
}
