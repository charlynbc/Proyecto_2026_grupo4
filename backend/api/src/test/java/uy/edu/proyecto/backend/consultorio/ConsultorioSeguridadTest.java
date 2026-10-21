package uy.edu.proyecto.backend.consultorio;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ConsultorioSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ConsultorioService service;

    @Test
    void listarSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/consultorios"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void crearSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(
                post("/api/consultorios")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Consultorio 7",
                                  "ubicacion": "Piso 3"
                                }
                                """)
        )
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioNoPuedeCrearConsultorio() throws Exception {
        mockMvc.perform(
                post("/api/consultorios")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Consultorio 7",
                                  "ubicacion": "Piso 3"
                                }
                                """)
        )
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioPuedeConsultarConsultorios() throws Exception {
        when(service.listar()).thenReturn(List.of());

        mockMvc.perform(get("/api/consultorios"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray());

        verify(service).listar();
    }
}
