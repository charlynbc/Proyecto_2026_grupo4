package uy.edu.proyecto.backend.especialidad;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import static org.mockito.Mockito.when;

@SpringBootTest
@AutoConfigureMockMvc
class EspecialidadSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private EspecialidadService service;

    @Test
    void listarSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/especialidades"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void crearSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(
                post("/api/especialidades")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Prueba no autorizada",
                                  "requierePase": false
                                }
                                """)
        ).andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioNoPuedeCrearEspecialidad() throws Exception {
        mockMvc.perform(
                post("/api/especialidades")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Prueba no autorizada",
                                  "requierePase": false
                                }
                                """)
        ).andExpect(status().isForbidden());
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioPuedeConsultarEspecialidades() throws Exception {
        when(service.listar()).thenReturn(List.of());

        mockMvc.perform(get("/api/especialidades"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());
    }
}
