package uy.edu.proyecto.backend.atencion;

import java.time.OffsetDateTime;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = AtencionController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AtencionSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AtencionService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void socioNoPuedeRegistrarResultadoMedico() throws Exception {
        mockMvc.perform(post("/api/medico/consultas/9001/resultado")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_SOCIO")
                        ))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"resultado\":\"NO_SE_PRESENTO\"}"))
                .andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void medicoRegistraResultadoEnEndpointAcordado() throws Exception {
        when(service.registrarResultado(
                eq(17L),
                eq(9001L),
                any(ResultadoConsultaRequest.class)
        )).thenReturn(new ResultadoConsultaResponse(
                9001L,
                "NO_SE_PRESENTO",
                null,
                OffsetDateTime.parse("2026-10-20T09:41:00-03:00"),
                List.of()
        ));

        mockMvc.perform(post("/api/medico/consultas/9001/resultado")
                        .with(jwt().jwt(token -> token.subject("17"))
                                .authorities(new SimpleGrantedAuthority("ROLE_MEDICO")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("""
                                {"resultado":"NO_SE_PRESENTO"}
                                """))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.consultaId").value(9001))
                .andExpect(jsonPath("$.estado").value("NO_SE_PRESENTO"))
                .andExpect(jsonPath("$.atencionId").doesNotExist())
                .andExpect(jsonPath("$.pases").isEmpty());

        verify(service).registrarResultado(
                eq(17L),
                eq(9001L),
                any(ResultadoConsultaRequest.class)
        );
    }
}
