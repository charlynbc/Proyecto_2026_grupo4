package uy.edu.proyecto.backend.especialidad;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.exception.ApiException;

@SpringBootTest
@AutoConfigureMockMvc
class EspecialidadControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private EspecialidadService service;

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorPuedeCrearEspecialidad() throws Exception {
        when(service.crear("Neurología", true))
                .thenReturn(new Especialidad(9L, "Neurología", true));

        mockMvc.perform(
                post("/api/especialidades")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Neurología",
                                  "requierePase": true
                                }
                                """)
        )
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(9))
                .andExpect(jsonPath("$.nombre").value("Neurología"))
                .andExpect(jsonPath("$.requierePase").value(true));

        verify(service).crear("Neurología", true);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void rechazaRequierePaseAusente() throws Exception {
        mockMvc.perform(
                post("/api/especialidades")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Neurología"
                                }
                                """)
        )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verifyNoInteractions(service);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void duplicadoDevuelve409() throws Exception {
        when(service.crear("Neurología", true))
                .thenThrow(new ApiException(
                        HttpStatus.CONFLICT,
                        "ESPECIALIDAD_DUPLICADA",
                        "Ya existe una especialidad registrada con ese nombre."
                ));

        mockMvc.perform(
                post("/api/especialidades")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Neurología",
                                  "requierePase": true
                                }
                                """)
        )
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code")
                        .value("ESPECIALIDAD_DUPLICADA"));
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void aplicaFiltros() throws Exception {
        when(service.listar("cardio", "true", "nombre"))
                .thenReturn(List.of(new Especialidad(2L, "Cardiología", true)));
        mockMvc.perform(get("/api/especialidades").param("nombre", "cardio")
                        .param("requierePase", "true").param("orden", "nombre"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(2));
        verify(service).listar("cardio", "true", "nombre");
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void listarDevuelveItems() throws Exception {
        when(service.listar())
                .thenReturn(List.of(
                        new Especialidad(1L, "Cardiología", true)
                ));

        mockMvc.perform(get("/api/especialidades"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].nombre")
                        .value("Cardiología"));
    }
}
