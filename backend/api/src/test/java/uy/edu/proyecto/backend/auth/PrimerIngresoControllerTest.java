package uy.edu.proyecto.backend.auth;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class PrimerIngresoControllerTest {

    private final PrimerIngresoService service = mock(PrimerIngresoService.class);
    private MockMvc mockMvc;

    @BeforeEach
    void configurar() {
        mockMvc = MockMvcBuilders
                .standaloneSetup(new PrimerIngresoController(service))
                .build();
    }

    @Test
    void solicitarResponde202ConMensajeGenerico() throws Exception {
        when(service.solicitar(new SolicitarPrimerIngresoRequest(
                "67890127",
                "SOCIO"
        ))).thenReturn(new SolicitudPrimerIngresoResponse("mensaje"));

        mockMvc.perform(
                        post("/api/auth/primer-ingreso/solicitar")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"ci":"67890127","acceso":"SOCIO"}
                                        """)
                )
                .andExpect(status().isAccepted())
                .andExpect(jsonPath("$.message").value("mensaje"));

        verify(service).solicitar(new SolicitarPrimerIngresoRequest(
                "67890127",
                "SOCIO"
        ));
    }

    @Test
    void completarRespondeCuentaActivada() throws Exception {
        when(service.completar(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new CuentaActivadaResponse(
                        12L,
                        "67890127",
                        "Ana",
                        "Perez",
                        "SOCIO",
                        "ACTIVA",
                        true
                ));

        mockMvc.perform(
                        post("/api/auth/primer-ingreso/completar")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "token":"token",
                                          "direccion":"Direccion",
                                          "telefono1":"099111222",
                                          "password":"claveSegura1"
                                        }
                                        """)
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.rol").value("SOCIO"))
                .andExpect(jsonPath("$.activada").value(true));
    }
}
