package uy.edu.proyecto.backend.usuario;

import java.util.Optional;

public final class CiUruguaya {

    private static final int[] PESOS = {2, 9, 8, 7, 6, 3, 4};

    private CiUruguaya() {
    }

    public static Optional<String> normalizarValida(String valor) {
        if (valor == null) {
            return Optional.empty();
        }

        String ci = valor.replaceAll("[.\\-\\s]", "");
        if (!ci.matches("\\d{7,8}")) {
            return Optional.empty();
        }

        String cuerpo = ci.substring(0, ci.length() - 1);
        String cuerpoCompleto = "0".repeat(7 - cuerpo.length()) + cuerpo;
        int suma = 0;
        for (int i = 0; i < PESOS.length; i++) {
            suma += Character.digit(cuerpoCompleto.charAt(i), 10) * PESOS[i];
        }

        int verificador = (10 - suma % 10) % 10;
        if (verificador != Character.digit(ci.charAt(ci.length() - 1), 10)) {
            return Optional.empty();
        }

        return Optional.of(ci);
    }
}
