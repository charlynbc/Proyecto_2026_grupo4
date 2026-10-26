package uy.edu.proyecto.backend.medico;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.especialidad.Especialidad;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class MedicoServiceTest {

    @Mock
    private MedicoRepository repository;

    @Test
    void listaMedicosConEspecialidadesYFiltroOpcional() {
        MedicoService service = new MedicoService(repository);
        List<MedicoDTO> expected = List.of(new MedicoDTO(
                17L,
                "Marta",
                "Rodriguez",
                List.of(new Especialidad(3L, "Cardiologia", true))
        ));
        when(repository.listar(3L)).thenReturn(expected);

        assertEquals(expected, service.listar(3L));
        verify(repository).listar(3L);
    }

    @Test
    void devuelveListaVaciaSiNoHayMedicos() {
        MedicoService service = new MedicoService(repository);
        when(repository.listar(null)).thenReturn(List.of());

        assertEquals(List.of(), service.listar(null));
        verify(repository).listar(null);
    }

    @Test
    void rechazaEspecialidadNoPositivaSinConsultarRepositorio() {
        MedicoService service = new MedicoService(repository);

        assertThrows(
                uy.edu.proyecto.backend.exception.ApiException.class,
                () -> service.listar(0L)
        );

        verifyNoInteractions(repository);
    }
}
