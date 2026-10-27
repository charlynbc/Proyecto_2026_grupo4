package uy.edu.proyecto.backend.atencion;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mock;
import org.mockito.junit.jupiter.MockitoExtension;

import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertThrows;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;

@ExtendWith(MockitoExtension.class)
class HistoriaClinicaServiceTest {

    private static final Long SOCIO_ID = 91L;

    @Mock
    private HistoriaClinicaRepository repository;

    @Test
    void combinaFiltrosYOrdenValido() {
        HistoriaClinicaService service = new HistoriaClinicaService(repository);
        List<HistoriaClinicaDTO> expected = List.of();
        when(repository.listar(
                SOCIO_ID,
                LocalDate.parse("2026-01-01"),
                LocalDate.parse("2026-12-31"),
                3L,
                17L,
                "control",
                "especialidad",
                "asc"
        )).thenReturn(expected);

        assertEquals(expected, service.listar(
                SOCIO_ID,
                "2026-01-01",
                "2026-12-31",
                "3",
                "17",
                "control",
                "especialidad",
                "ASC"
        ));
        verify(repository).listar(
                SOCIO_ID,
                LocalDate.parse("2026-01-01"),
                LocalDate.parse("2026-12-31"),
                3L,
                17L,
                "control",
                "especialidad",
                "asc"
        );
    }

    @Test
    void ordenFechaEsAliasDeFechaAtencion() {
        HistoriaClinicaService service = new HistoriaClinicaService(repository);
        when(repository.listar(
                SOCIO_ID, null, null, null, null, null, "fecha_atencion", "asc"
        )).thenReturn(List.of());

        assertEquals(List.of(), service.listar(
                SOCIO_ID, null, null, null, null, null, "fecha", "asc"
        ));
    }

    @Test
    void listaVaciaEsValida() {
        HistoriaClinicaService service = new HistoriaClinicaService(repository);
        when(repository.listar(
                SOCIO_ID, null, null, null, null, null, "fecha_atencion", "desc"
        )).thenReturn(List.of());

        assertEquals(List.of(), service.listar(
                SOCIO_ID, null, null, null, null, null, null, null
        ));
    }

    @Test
    void rechazaFechasOrdenFiltrosEIdsInvalidosSinConsultarRepositorio() {
        HistoriaClinicaService service = new HistoriaClinicaService(repository);

        assertThrows(ApiException.class, () -> service.listar(
                SOCIO_ID, "2026-02-01", "2026-01-01", null, null, null, null, null
        ));
        assertThrows(ApiException.class, () -> service.listar(
                SOCIO_ID, "01-01-2026", null, null, null, null, null, null
        ));
        assertThrows(ApiException.class, () -> service.listar(
                SOCIO_ID, null, null, "0", null, null, null, null
        ));
        assertThrows(ApiException.class, () -> service.listar(
                SOCIO_ID, null, null, null, "xyz", null, null, null
        ));
        assertThrows(ApiException.class, () -> service.listar(
                SOCIO_ID, null, null, null, null, null, "afeccion", null
        ));
        assertThrows(ApiException.class, () -> service.listar(
                SOCIO_ID, null, null, null, null, null, null, "sideways"
        ));

        verifyNoInteractions(repository);
    }

    @Test
    void detalleUsaSocioAutenticadoYOcultaSiNoEsPropietario() {
        HistoriaClinicaService service = new HistoriaClinicaService(repository);
        HistoriaClinicaDTO expected = null;
        when(repository.obtenerDetalle(SOCIO_ID, 5530L)).thenReturn(expected);

        ApiException exception = assertThrows(
                ApiException.class,
                () -> service.detalle(SOCIO_ID, 5530L)
        );

        assertEquals("HISTORIA_NO_ENCONTRADA", exception.getCode());
        assertEquals("La atención no existe o no pertenece a este socio", exception.getMessage());
        verify(repository).obtenerDetalle(SOCIO_ID, 5530L);
    }

    @Test
    void rechazaIdentificadoresDeDetalleInvalidosAntesDeConsultar() {
        HistoriaClinicaService service = new HistoriaClinicaService(repository);

        assertThrows(ApiException.class, () -> service.detalle(SOCIO_ID, 0L));

        verifyNoInteractions(repository);
    }
}
