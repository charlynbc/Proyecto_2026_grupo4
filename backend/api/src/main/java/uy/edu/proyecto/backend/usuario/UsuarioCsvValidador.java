package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

import uy.edu.proyecto.backend.csv.CsvArchivo;

/**
 * Validaciones por fila del CSV de usuarios (RF-32): mismas reglas del alta
 * individual (RF-31) mas la deteccion de filas repetidas dentro del archivo
 * (misma CI y mismo rol), conservando la primera aparicion (seccion 3.1.4).
 */
public class UsuarioCsvValidador {

    static final List<String> COLUMNAS = List.of(
            "ci", "nombre", "apellido", "fecha_nacimiento", "correo",
            "telefono_1", "telefono_2", "direccion", "rol", "especialidades"
    );

    private static final Set<String> ROLES = Set.of(
            "SOCIO",
            "MEDICO",
            "FUNCIONARIO",
            "ADMINISTRADOR"
    );
    private static final Pattern CORREO = Pattern.compile(
            "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
    );

    /** Fila con todos los campos parseados, lista para el alta individual. */
    public record FilaUsuarioParseada(
            int numero,
            String ci,
            String nombre,
            String apellido,
            LocalDate fechaNacimiento,
            String correo,
            String telefono1,
            String telefono2,
            String direccion,
            String rol,
            List<String> especialidades,
            String error
    ) {
        public boolean valida() {
            return error == null;
        }

        /** Vista reducida para la respuesta de la API. */
        public FilaUsuarioCsv aFilaCsv() {
            return new FilaUsuarioCsv(
                    numero,
                    ci,
                    nombre,
                    apellido,
                    rol,
                    error
            );
        }
    }

    public List<FilaUsuarioParseada> validar(List<CsvArchivo.FilaCruda> filas) {
        List<FilaUsuarioParseada> resultados = new ArrayList<>();
        Map<String, Integer> cuentasVistas = new HashMap<>();

        for (CsvArchivo.FilaCruda fila : filas) {
            if (fila.error() != null) {
                resultados.add(new FilaUsuarioParseada(
                        fila.numero(),
                        null, null, null, null, null, null, null, null,
                        null, List.of(), fila.error()
                ));
                continue;
            }

            String ciTexto = texto(fila.valor(0));
            String nombre = texto(fila.valor(1));
            String apellido = texto(fila.valor(2));
            String fechaTexto = texto(fila.valor(3));
            String correo = texto(fila.valor(4));
            String telefono1 = texto(fila.valor(5));
            String telefono2 = texto(fila.valor(6));
            String direccion = texto(fila.valor(7));
            String rolTexto = texto(fila.valor(8));
            String especialidadesTexto = texto(fila.valor(9));

            String error = null;
            String ci = null;
            LocalDate fechaNacimiento = null;
            String rol = rolTexto.toUpperCase(Locale.ROOT);
            List<String> especialidades = List.of();

            if (ciTexto.isEmpty() || nombre.isEmpty() || apellido.isEmpty()
                    || fechaTexto.isEmpty() || correo.isEmpty()
                    || telefono1.isEmpty() || rolTexto.isEmpty()) {
                error = "Falta un campo obligatorio (ci, nombre, apellido,"
                        + " fecha_nacimiento, correo, telefono_1, rol)";
            } else if (CiUruguaya.normalizarValida(ciTexto).isEmpty()) {
                error = "La CI no es valida";
            } else if (nombre.length() > 100 || apellido.length() > 100
                    || correo.length() > 254 || telefono1.length() > 30
                    || telefono2.length() > 30) {
                error = "Un campo supera la longitud permitida";
            } else if (!CORREO.matcher(correo).matches()) {
                error = "El correo no tiene un formato valido";
            } else if (!ROLES.contains(rol)) {
                error = "El rol indicado no es valido";
            } else {
                ci = CiUruguaya.normalizarValida(ciTexto).orElseThrow();
                try {
                    fechaNacimiento = LocalDate.parse(fechaTexto);
                } catch (DateTimeParseException exception) {
                    error = "fecha_nacimiento debe tener formato aaaa-mm-dd";
                }
            }

            if (error == null) {
                especialidades = parsearEspecialidades(especialidadesTexto);
                if (rol.equals("MEDICO") && especialidades.isEmpty()) {
                    error = "Un medico requiere al menos una especialidad";
                } else if (!rol.equals("MEDICO") && !especialidades.isEmpty()) {
                    error = "Las especialidades solo corresponden a medicos";
                } else if (tieneRepetidas(especialidades)) {
                    error = "No se permiten especialidades repetidas";
                }
            }

            if (error == null) {
                String clave = ci + "|" + rol;
                Integer primeraFila = cuentasVistas.putIfAbsent(
                        clave,
                        fila.numero()
                );
                if (primeraFila != null) {
                    error = "Fila repetida (misma CI y rol)."
                            + " Primera aparición válida en fila "
                            + primeraFila;
                }
            }

            resultados.add(new FilaUsuarioParseada(
                    fila.numero(),
                    ci,
                    nombre,
                    apellido,
                    fechaNacimiento,
                    correo,
                    telefono1,
                    telefono2.isEmpty() ? null : telefono2,
                    direccion.isEmpty() ? null : direccion,
                    rol,
                    especialidades,
                    error
            ));
        }

        return resultados;
    }

    /** Las especialidades de un medico se separan con "|" (RF-32). */
    private List<String> parsearEspecialidades(String texto) {
        if (texto.isEmpty()) {
            return List.of();
        }
        List<String> nombres = new ArrayList<>();
        for (String parte : texto.split("\\|")) {
            String nombre = parte.trim();
            if (!nombre.isEmpty()) {
                nombres.add(nombre);
            }
        }
        return List.copyOf(new LinkedHashSet<>(nombres));
    }

    private boolean tieneRepetidas(List<String> nombres) {
        Set<String> vistos = new HashSet<>();
        for (String nombre : nombres) {
            if (!vistos.add(nombre.toLowerCase(Locale.ROOT))) {
                return true;
            }
        }
        return false;
    }

    private String texto(String valor) {
        return valor == null ? "" : valor.trim();
    }
}
