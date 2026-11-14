package uy.edu.proyecto.backend.dispositivo;

import java.time.OffsetDateTime;

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
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = DispositivoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class DispositivoSeguridadTest {

    private static final String CUERPO = "{\"token\":\"fcm-token-de-prueba\"}";
    private static final String[] ROLES_DE_EMPLEADO =
            {"FUNCIONARIO", "MEDICO", "ADMINISTRADOR"};

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private DispositivoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void registrarSinJwtDevuelve401() throws Exception {
        mockMvc.perform(post("/api/dispositivos")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(CUERPO))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void bajaSinJwtDevuelve401() throws Exception {
        mockMvc.perform(post("/api/dispositivos/baja")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(CUERPO))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void registrarRechazaRolesDeEmpleado() throws Exception {
        for (String rol : ROLES_DE_EMPLEADO) {
            mockMvc.perform(post("/api/dispositivos")
                            .with(jwt().jwt(token -> token.subject("31"))
                                    .authorities(new SimpleGrantedAuthority("ROLE_" + rol)))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(CUERPO))
                    .andExpect(status().isForbidden());
        }

        verifyNoInteractions(service);
    }

    @Test
    void bajaRechazaRolesDeEmpleado() throws Exception {
        for (String rol : ROLES_DE_EMPLEADO) {
            mockMvc.perform(post("/api/dispositivos/baja")
                            .with(jwt().jwt(token -> token.subject("31"))
                                    .authorities(new SimpleGrantedAuthority("ROLE_" + rol)))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(CUERPO))
                    .andExpect(status().isForbidden());
        }

        verifyNoInteractions(service);
    }

    @Test
    void socioRegistraConSuIdentidadDelJwt() throws Exception {
        OffsetDateTime registrado = OffsetDateTime.parse("2026-10-14T10:20:00-03:00");
        when(service.registrar(eq(91L), eq("fcm-token-de-prueba")))
                .thenReturn(new DispositivoRegistro(
                        new DispositivoDTO(61L, true, registrado), false));

        mockMvc.perform(post("/api/dispositivos")
                        .param("socioId", "1")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(CUERPO))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(61));

        verify(service).registrar(91L, "fcm-token-de-prueba");
    }

    @Test
    void socioDaDeBajaConSuIdentidadDelJwt() throws Exception {
        mockMvc.perform(post("/api/dispositivos/baja")
                        .param("socioId", "1")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO")))
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(CUERPO))
                .andExpect(status().isNoContent());

        verify(service).darDeBaja(91L, "fcm-token-de-prueba");
    }

    @Test
    void getNoEstaPermitidoEnDispositivos() throws Exception {
        mockMvc.perform(get("/api/dispositivos")
                        .with(jwt().jwt(token -> token.subject("91"))
                                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"))))
                .andExpect(status().is4xxClientError());

        verifyNoInteractions(service);
    }
}
