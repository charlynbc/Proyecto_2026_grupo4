package uy.edu.proyecto.backend.busqueda;

import java.util.Locale;

/**
 * Regla unica de las busquedas de texto: sin distinguir mayusculas ni tildes.
 *
 * Se quitan las tildes de a, e, i, o, u y la dieresis de u. La enie es una
 * letra distinta de la n y se conserva (solo se pasa a minuscula). Como no se
 * usa la extension unaccent ni cambia el esquema, la columna se compara con
 * translate dentro de la consulta, con el mismo mapa que usa el texto.
 *
 * El mapa de la columna incluye las mayusculas acentuadas: asi no depende de
 * como LOWER trate esas letras segun la configuracion de la base.
 */
public final class TextoBusqueda {

    private static final String CON_TILDE = "áéíóúüÁÉÍÓÚÜÑ";
    private static final String SIN_TILDE = "aeiouuAEIOUUñ";

    private TextoBusqueda() {
    }

    /** El texto sin espacios en los extremos, sin tildes y en minusculas. */
    public static String normalizar(String texto) {
        if (texto == null) {
            return "";
        }
        StringBuilder resultado = new StringBuilder();
        for (char letra : texto.trim().toCharArray()) {
            int posicion = CON_TILDE.indexOf(letra);
            resultado.append(posicion < 0 ? letra : SIN_TILDE.charAt(posicion));
        }
        return resultado.toString().toLowerCase(Locale.ROOT);
    }

    /** Patron "contiene" para LIKE ... ESCAPE '!', con los comodines escapados. */
    public static String patron(String texto) {
        String literal = normalizar(texto)
                .replace("!", "!!")
                .replace("%", "!%")
                .replace("_", "!_");
        return "%" + literal + "%";
    }

    /** La expresion SQL [expresion] sin tildes ni mayusculas. */
    public static String columna(String expresion) {
        return "LOWER(translate(" + expresion + ", '" + CON_TILDE + "', '"
                + SIN_TILDE + "'))";
    }

    /** La condicion "contiene" sobre [expresion]; el parametro es {@link #patron}. */
    public static String contiene(String expresion) {
        return columna(expresion) + " LIKE ? ESCAPE '!'";
    }
}
