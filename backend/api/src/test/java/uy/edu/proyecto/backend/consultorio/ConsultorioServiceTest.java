package uy.edu.proyecto.backend.consultorio;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

class ConsultorioServiceTest {

    private final ConsultorioRepository repository =
            mock(ConsultorioRepository.class);

    private final ConsultorioService service =
            new ConsultorioService(repository);

    @Test
    void listarDevuelveConsultorios() {
        Consultorio consultorio =
                new Consultorio(1L, "Consultorio 1", "Piso 2");

        when(repository.listar())
                .thenReturn(List.of(consultorio));

        List<Consultorio> resultado = service.listar();

        assertEquals(1, resultado.size());
        assertEquals("Consultorio 1", resultado.get(0).nombre());

        verify(repository).listar();
    }

    @Test
    void crearNormalizaNombreYUbicacion() {
        Consultorio esperado =
                new Consultorio(1L, "Consultorio 7", "Piso 3");

        when(repository.crear("Consultorio 7", "Piso 3"))
                .thenReturn(esperado);

        Consultorio resultado =
                service.crear("  Consultorio 7  ", "  Piso 3  ");

        assertEquals("Consultorio 7", resultado.nombre());
        assertEquals("Piso 3", resultado.ubicacion());

        verify(repository).crear("Consultorio 7", "Piso 3");
    }

    @Test
    void rechazaNombreNulo() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear(null, "Piso 3")
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());

        verifyNoInteractions(repository);
    }

    @Test
    void rechazaNombreVacio() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("   ", "Piso 3")
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());

        verifyNoInteractions(repository);
    }

    @Test
    void rechazaUbicacionNula() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("Consultorio 7", null)
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());
        assertEquals("VALIDACION", error.getCode());

        verifyNoInteractions(repository);
    }

    @Test
    void rechazaUbicacionVacia() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("Consultorio 7", "   ")
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());

        verifyNoInteractions(repository);
    }

    @Test
    void rechazaNombreDeMasDe120Caracteres() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("A".repeat(121), "Piso 3")
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());

        verifyNoInteractions(repository);
    }

    @Test
    void rechazaUbicacionDeMasDe200Caracteres() {
        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("Consultorio 7", "A".repeat(201))
        );

        assertEquals(HttpStatus.BAD_REQUEST, error.getStatus());

        verifyNoInteractions(repository);
    }

    @Test
    void aceptaLongitudesMaximas() {
        String nombre = "A".repeat(120);
        String ubicacion = "B".repeat(200);

        Consultorio esperado =
                new Consultorio(2L, nombre, ubicacion);

        when(repository.crear(nombre, ubicacion))
                .thenReturn(esperado);

        Consultorio resultado = service.crear(nombre, ubicacion);

        assertEquals(nombre, resultado.nombre());
        assertEquals(ubicacion, resultado.ubicacion());

        verify(repository).crear(nombre, ubicacion);
    }

    @Test
    void duplicadoDevuelveConflicto409() {
        when(repository.crear("Consultorio 7", "Piso 3"))
                .thenThrow(new DuplicateKeyException("uq_consultorio_nombre"));

        ApiException error = assertThrows(
                ApiException.class,
                () -> service.crear("Consultorio 7", "Piso 3")
        );

        assertEquals(HttpStatus.CONFLICT, error.getStatus());
        assertEquals("CONSULTORIO_DUPLICADO", error.getCode());
    }
}
