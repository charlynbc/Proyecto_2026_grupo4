package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.util.List;
import java.util.Map;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.especialidad.EspecialidadRepository;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertNull;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyCollection;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.never;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class UsuarioImportacionServiceTest {

    private static final int[] PESOS = {2, 9, 8, 7, 6, 3, 4};

    private final CuentaRepository repository = mock(CuentaRepository.class);
    private final EspecialidadRepository especialidadRepository =
            mock(EspecialidadRepository.class);
    private final AltaUsuarioService altaUsuarioService =
            mock(AltaUsuarioService.class);

    private final UsuarioImportacionService service =
            new UsuarioImportacionService(
                    repository,
                    especialidadRepository,
                    altaUsuarioService
            );

    private static String ci(int cuerpo) {
        String digitos = String.format("%07d", cuerpo);
        int suma = 0;
        for (int i = 0; i < PESOS.length; i++) {
            suma += Character.digit(digitos.charAt(i), 10) * PESOS[i];
        }
        return digitos + ((10 - suma % 10) % 10);
    }

    private String encabezado() {
        return "ci,nombre,apellido,fecha_nacimiento,correo,telefono_1,"
                + "telefono_2,direccion,rol,especialidades\n";
    }

    private String filaSocio(int cuerpo) {
        return ci(cuerpo) + ",Juan,Perez,1990-01-15,juan" + cuerpo
                + "@example.org,099111222,,,SOCIO,\n";
    }

    @Test
    void previsualizaFilasValidas() {
        when(repository.buscarPersona(anyString()))
                .thenReturn(Optional.empty());
        when(repository.existeCuentaSocio(anyString())).thenReturn(false);

        var resultado = service.previsualizar(encabezado() + filaSocio(4000001));

        assertEquals(1, resultado.total());
        assertEquals(1, resultado.validas());
        assertEquals(0, resultado.invalidas());
    }

    @Test
    void previsualizacionMarcaEspecialidadDesconocida() {
        when(especialidadRepository.buscarPorNombresLower(anyCollection()))
                .thenReturn(Map.of());

        String csv = encabezado()
                + ci(4000002) + ",Maria,Gomez,1980-06-20,maria@example.org,"
                + "099222333,,,MEDICO,Cardiologia\n";

        var resultado = service.previsualizar(csv);

        assertEquals(0, resultado.validas());
        assertEquals(1, resultado.invalidas());
        assertTrue(resultado.errores().get(0).error()
                .contains("Especialidad desconocida"));
    }

    @Test
    void previsualizacionMarcaPersonaConDatosDiscordantes() {
        when(repository.buscarPersona(ci(4000003)))
                .thenReturn(Optional.of(new CuentaRepository.PersonaRegistrada(
                        ci(4000003), "Otro", "Nombre",
                        LocalDate.of(1990, 1, 15)
                )));

        var resultado = service.previsualizar(encabezado() + filaSocio(4000003));

        assertEquals(0, resultado.validas());
        assertTrue(resultado.errores().get(0).error()
                .contains("otros datos personales"));
    }

    @Test
    void previsualizacionMarcaSocioDuplicado() {
        when(repository.buscarPersona(ci(4000004)))
                .thenReturn(Optional.of(new CuentaRepository.PersonaRegistrada(
                        ci(4000004), "Juan", "Perez",
                        LocalDate.of(1990, 1, 15)
                )));
        when(repository.existeCuentaSocio(ci(4000004))).thenReturn(true);

        var resultado = service.previsualizar(encabezado() + filaSocio(4000004));

        assertEquals(0, resultado.validas());
        assertTrue(resultado.errores().get(0).error()
                .contains("cuenta de socio"));
    }

    @Test
    void previsualizacionMarcaEmpleadoDuplicado() {
        when(repository.buscarPersona(anyString()))
                .thenReturn(Optional.empty());
        when(repository.existeCuentaEmpleadoHabilitada(ci(4000005)))
                .thenReturn(true);

        String csv = encabezado()
                + ci(4000005) + ",Ana,Diaz,1995-03-10,ana@example.org,"
                + "099333444,,,FUNCIONARIO,\n";

        var resultado = service.previsualizar(csv);

        assertEquals(0, resultado.validas());
        assertTrue(resultado.errores().get(0).error()
                .contains("cuenta de empleado habilitada"));
    }

    @Test
    void previsualizacionNoConsultaBaseSiNoHayFilasValidas() {
        String csv = encabezado() + ",,,,,,,,,\n";

        var resultado = service.previsualizar(csv);

        assertEquals(0, resultado.validas());
        verifyNoInteractions(repository);
        verifyNoInteractions(especialidadRepository);
    }

    @Test
    void confirmarCreaCuentasPorCadaFilaValida() {
        when(especialidadRepository.buscarPorNombresLower(anyCollection()))
                .thenReturn(Map.of(
                        "cardiologia",
                        new Especialidad(1L, "Cardiologia", true),
                        "pediatria",
                        new Especialidad(2L, "Pediatria", false)
                ));
        when(altaUsuarioService.crear(any()))
                .thenAnswer(invocacion -> {
                    AltaUsuarioRequest request = invocacion.getArgument(0);
                    return new CuentaCreadaResponse(
                            1L, request.ci(), request.nombre(),
                            request.apellido(), request.rol(),
                            "ACTIVA", false
                    );
                });

        String csv = encabezado()
                + filaSocio(4000006)
                + ci(4000007) + ",Maria,Gomez,1980-06-20,maria@example.org,"
                + "099222333,,,MEDICO,Cardiologia|pediatria\n";

        var resultado = service.confirmar(csv);

        assertEquals(2, resultado.total());
        assertEquals(2, resultado.importadas());
        assertEquals(0, resultado.rechazadas());

        var capturador = org.mockito.ArgumentCaptor
                .forClass(AltaUsuarioRequest.class);
        verify(altaUsuarioService,
                org.mockito.Mockito.times(2)).crear(capturador.capture());

        AltaUsuarioRequest medico = capturador.getAllValues().get(1);
        assertEquals("MEDICO", medico.rol());
        assertEquals(List.of(1L, 2L), medico.especialidadIds());
        assertEquals(ci(4000007), medico.ci());
    }

    @Test
    void confirmarRechazaFilaCuandoElAltaIndividualFalla() {
        when(altaUsuarioService.crear(any()))
                .thenThrow(new ApiException(
                        HttpStatus.CONFLICT,
                        "SOCIO_DUPLICADO",
                        "La CI ya tiene una cuenta de socio"
                ));

        var resultado = service.confirmar(encabezado() + filaSocio(4000008));

        assertEquals(1, resultado.total());
        assertEquals(0, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertEquals("La CI ya tiene una cuenta de socio",
                resultado.errores().get(0).error());
    }

    @Test
    void confirmarNoInvocaElAltaParaFilasInvalidas() {
        String csv = encabezado()
                + "12345670,Juan,Perez,1990-01-15,juan@example.org,"
                + "099111222,,,SOCIO,\n";

        var resultado = service.confirmar(csv);

        assertEquals(0, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        verify(altaUsuarioService, never()).crear(any());
    }

    @Test
    void confirmarRechazaMedicoConEspecialidadDesconocidaSinInvocarAlta() {
        when(especialidadRepository.buscarPorNombresLower(anyCollection()))
                .thenReturn(Map.of());

        String csv = encabezado()
                + ci(4000009) + ",Maria,Gomez,1980-06-20,maria@example.org,"
                + "099222333,,,MEDICO,Inexistente\n";

        var resultado = service.confirmar(csv);

        assertEquals(0, resultado.importadas());
        assertEquals(1, resultado.rechazadas());
        assertTrue(resultado.errores().get(0).error()
                .contains("Especialidad desconocida"));
        verify(altaUsuarioService, never()).crear(any());
    }

    @Test
    void filasDelResultadoConservanDatosIdentificadores() {
        when(repository.buscarPersona(anyString()))
                .thenReturn(Optional.empty());
        when(repository.existeCuentaSocio(anyString())).thenReturn(false);

        var resultado = service.previsualizar(encabezado() + filaSocio(4000010));

        FilaUsuarioCsv fila = resultado.filas().get(0);
        assertEquals(2, fila.numero());
        assertEquals(ci(4000010), fila.ci());
        assertEquals("Juan", fila.nombre());
        assertEquals("Perez", fila.apellido());
        assertEquals("SOCIO", fila.rol());
        assertNull(fila.error());
    }
}
