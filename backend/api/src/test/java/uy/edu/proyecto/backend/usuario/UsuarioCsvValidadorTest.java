package uy.edu.proyecto.backend.usuario;

import org.junit.jupiter.api.Test;

import uy.edu.proyecto.backend.csv.CsvArchivo;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;

class UsuarioCsvValidadorTest {

    private static final int[] PESOS = {2, 9, 8, 7, 6, 3, 4};

    private final UsuarioCsvValidador validador = new UsuarioCsvValidador();

    private static String ci(int cuerpo) {
        String digitos = String.format("%07d", cuerpo);
        int suma = 0;
        for (int i = 0; i < PESOS.length; i++) {
            suma += Character.digit(digitos.charAt(i), 10) * PESOS[i];
        }
        return digitos + ((10 - suma % 10) % 10);
    }

    private java.util.List<UsuarioCsvValidador.FilaUsuarioParseada> validar(
            String csv
    ) {
        return validador.validar(
                CsvArchivo.parsear(csv, UsuarioCsvValidador.COLUMNAS)
        );
    }

    private String encabezado() {
        return "ci,nombre,apellido,fecha_nacimiento,correo,telefono_1,"
                + "telefono_2,direccion,rol,especialidades\n";
    }

    @Test
    void aceptaSocioValido() {
        String csv = encabezado()
                + ci(3000001) + ",Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,\n";

        var filas = validar(csv);

        assertEquals(1, filas.size());
        assertTrue(filas.get(0).valida());
        assertEquals(ci(3000001), filas.get(0).ci());
        assertEquals("SOCIO", filas.get(0).rol());
        assertNull(filas.get(0).telefono2());
    }

    @Test
    void aceptaMedicoConVariasEspecialidades() {
        String csv = encabezado()
                + ci(3000002) + ",Maria,Gomez,1980-06-20,maria@example.org,"
                + "099222333,,Calle 1,MEDICO,Cardiologia|Pediatria\n";

        var filas = validar(csv);

        assertTrue(filas.get(0).valida());
        assertEquals(
                java.util.List.of("Cardiologia", "Pediatria"),
                filas.get(0).especialidades()
        );
    }

    @Test
    void aceptaFuncionarioYAdministrador() {
        String csv = encabezado()
                + ci(3000003) + ",Ana,Diaz,1995-03-10,ana@example.org,"
                + "099333444,,,FUNCIONARIO,\n"
                + ci(3000004) + ",Luis,Sosa,1992-07-01,luis@example.org,"
                + "099444555,,,administrador,\n";

        var filas = validar(csv);

        assertTrue(filas.get(0).valida());
        assertTrue(filas.get(1).valida());
        assertEquals("ADMINISTRADOR", filas.get(1).rol());
    }

    @Test
    void normalizaCiConPuntosYGuion() {
        String cruda = ci(3000005);
        String conFormato = cruda.substring(0, 1) + "."
                + cruda.substring(1, 4) + "." + cruda.substring(4, 7)
                + "-" + cruda.substring(7);

        var filas = validar(encabezado()
                + conFormato + ",Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,\n");

        assertTrue(filas.get(0).valida());
        assertEquals(cruda, filas.get(0).ci());
    }

    @Test
    void rechazaCiInvalida() {
        var filas = validar(encabezado()
                + "12345670,Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,\n");

        assertFalse(filas.get(0).valida());
        assertEquals("La CI no es valida", filas.get(0).error());
    }

    @Test
    void rechazaCamposObligatoriosFaltantes() {
        var filas = validar(encabezado()
                + ci(3000006) + ",,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,\n"
                + encabezadoVacio());

        assertFalse(filas.get(0).valida());
        assertTrue(filas.get(0).error().contains("obligatorio"));
        assertFalse(filas.get(1).valida());
    }

    private String encabezadoVacio() {
        return ",,,,,,,,,\n";
    }

    @Test
    void rechazaCorreoInvalido() {
        var filas = validar(encabezado()
                + ci(3000007) + ",Juan,Perez,1990-01-15,no-es-correo,"
                + "099111222,,,SOCIO,\n");

        assertEquals("El correo no tiene un formato valido",
                filas.get(0).error());
    }

    @Test
    void rechazaFechaInvalida() {
        var filas = validar(encabezado()
                + ci(3000008) + ",Juan,Perez,15/01/1990,juan@example.org,"
                + "099111222,,,SOCIO,\n");

        assertTrue(filas.get(0).error().contains("aaaa-mm-dd"));
    }

    @Test
    void rechazaRolInvalido() {
        var filas = validar(encabezado()
                + ci(3000009) + ",Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,GERENTE,\n");

        assertEquals("El rol indicado no es valido", filas.get(0).error());
    }

    @Test
    void medicoSinEspecialidadesSeRechaza() {
        var filas = validar(encabezado()
                + ci(3000010) + ",Maria,Gomez,1980-06-20,maria@example.org,"
                + "099222333,,,MEDICO,\n");

        assertEquals("Un medico requiere al menos una especialidad",
                filas.get(0).error());
    }

    @Test
    void socioConEspecialidadesSeRechaza() {
        var filas = validar(encabezado()
                + ci(3000011) + ",Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,Cardiologia\n");

        assertEquals("Las especialidades solo corresponden a medicos",
                filas.get(0).error());
    }

    @Test
    void rechazaEspecialidadesRepetidas() {
        var filas = validar(encabezado()
                + ci(3000012) + ",Maria,Gomez,1980-06-20,maria@example.org,"
                + "099222333,,,MEDICO,Cardiologia|CARDIOLOGIA\n");

        assertEquals("No se permiten especialidades repetidas",
                filas.get(0).error());
    }

    @Test
    void detectaFilaRepetidaMismaCiYRol() {
        String csv = encabezado()
                + ci(3000013) + ",Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,\n"
                + ci(3000013) + ",Juan,Perez,1990-01-15,otro@example.org,"
                + "099111222,,,SOCIO,\n";

        var filas = validar(csv);

        assertTrue(filas.get(0).valida());
        assertFalse(filas.get(1).valida());
        assertTrue(filas.get(1).error().contains("fila 2"));
    }

    @Test
    void mismaCiConDistintoRolNoEsRepetida() {
        String csv = encabezado()
                + ci(3000014) + ",Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,\n"
                + ci(3000014) + ",Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,FUNCIONARIO,\n";

        var filas = validar(csv);

        assertTrue(filas.get(0).valida());
        assertTrue(filas.get(1).valida());
    }

    @Test
    void propagaErrorDeFilaMalFormada() {
        var filas = validar(encabezado()
                + ci(3000015) + ",Juan,Perez\n");

        assertFalse(filas.get(0).valida());
        assertTrue(filas.get(0).error().contains("columnas"));
    }
}
