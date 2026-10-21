package uy.edu.proyecto.backend.especialidad;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

class EspecialidadServiceTest {

    private final EspecialidadRepository repository =
            mock(EspecialidadRepository.class);

    private final EspecialidadService service =
            new EspecialidadService(repository);

    @Test
    void listarDevuelveEspecialidades() {
        Especialidad especialidad =
                new Especialidad(1L, "Cardiología", true);

        when(repository.listar())
                .thenReturn(List.of(especialidad));

        List<Especialidad> resultado = service.listar();

        assertEquals(1, resultado.size());
        assertEquals("Cardiología", resultado.get(0).nombre());
        verify(repository).listar();
    }

    @Test
    void crearEliminaEspaciosDelNombre() {
        Especialidad esperada =
                new Especialidad(1L, "Cardiología", true);

        when(repository.crear("Cardiología", true))
                .thenReturn(esperada);

        Especialidad resultado =
                service.crear("  Cardiología  ", true);

        assertEquals("Cardiología", resultado.nombre());
        verify(repository).crear("Cardiología", true);
    }

    @Test
    void rechazaNombreNulo() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(null, true)
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaNombreVacio() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("   ", false)
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void rechazaNombreDeMasDe120Caracteres() {
        String nombre = "A".repeat(121);

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(nombre, true)
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());
        verifyNoInteractions(repository);
    }

    @Test
    void aceptaNombreDe120Caracteres() {
        String nombre = "A".repeat(120);
        Especialidad esperada =
                new Especialidad(2L, nombre, false);

        when(repository.crear(nombre, false))
                .thenReturn(esperada);

        Especialidad resultado =
                service.crear(nombre, false);

        assertEquals(nombre, resultado.nombre());
        verify(repository).crear(nombre, false);
    }

    @Test
    void duplicadoDevuelveConflicto409() {
        when(repository.crear("Cardiología", true))
                .thenThrow(new DuplicateKeyException("uq_especialidad_nombre"));

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("Cardiología", true)
        );

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("ESPECIALIDAD_DUPLICADA", error.getCode());
    }
}
