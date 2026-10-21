package uy.edu.proyecto.backend.consultorio;

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

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class ConsultorioControllerTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private ConsultorioService service;

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorPuedeCrearConsultorio() throws Exception {
        when(service.crear("Consultorio 7", "Piso 3"))
                .thenReturn(new Consultorio(
                        7L, "Consultorio 7", "Piso 3"
                ));

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
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(7))
                .andExpect(jsonPath("$.nombre").value("Consultorio 7"))
                .andExpect(jsonPath("$.ubicacion").value("Piso 3"));

        verify(service).crear("Consultorio 7", "Piso 3");
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void listarDevuelveItems() throws Exception {
        when(service.listar()).thenReturn(List.of(
                new Consultorio(1L, "Consultorio 1", "Piso 2")
        ));

        mockMvc.perform(get("/api/consultorios"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(1))
                .andExpect(jsonPath("$.items[0].nombre").value("Consultorio 1"))
                .andExpect(jsonPath("$.items[0].ubicacion").value("Piso 2"));

        verify(service).listar();
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void nombreAusenteDevuelve400() throws Exception {
        when(service.crear(null, "Piso 3"))
                .thenThrow(new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "El nombre del consultorio es obligatorio"
                ));

        mockMvc.perform(
                post("/api/consultorios")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "ubicacion": "Piso 3"
                                }
                                """)
        )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verify(service).crear(null, "Piso 3");
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void ubicacionAusenteDevuelve400() throws Exception {
        when(service.crear("Consultorio 7", null))
                .thenThrow(new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "La ubicación del consultorio es obligatoria"
                ));

        mockMvc.perform(
                post("/api/consultorios")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {
                                  "nombre": "Consultorio 7"
                                }
                                """)
        )
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verify(service).crear("Consultorio 7", null);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void duplicadoDevuelve409() throws Exception {
        when(service.crear("Consultorio 7", "Piso 3"))
                .thenThrow(new ApiException(
                        HttpStatus.CONFLICT,
                        "CONSULTORIO_DUPLICADO",
                        "Ya existe un consultorio registrado con ese nombre."
                ));

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
                .andExpect(status().isConflict())
                .andExpect(jsonPath("$.code").value("CONSULTORIO_DUPLICADO"));

        verify(service).crear("Consultorio 7", "Piso 3");
    }
}
