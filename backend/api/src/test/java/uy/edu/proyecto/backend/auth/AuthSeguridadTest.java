package uy.edu.proyecto.backend.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.times;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseCookie;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;

@WebMvcTest(controllers = AuthController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class AuthSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private AuthService authService;

    @MockitoBean
    private RefreshCookieService refreshCookieService;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void loginEsPublico() throws Exception {
        when(authService.login(any())).thenReturn(
                new AuthResult(
                        new LoginResponse("jwt", "Bearer", 900, "SOCIO", "Ana", "Perez"),
                        "v2.refresh"
                )
        );
        when(refreshCookieService.crear("v2.refresh")).thenReturn(
                org.springframework.http.ResponseCookie.from("refresh_token", "v2.refresh").build()
        );

        mockMvc.perform(
                        post("/api/auth/login")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"ci":"67890127","password":"x","acceso":"SOCIO"}
                                        """)
                )
                .andExpect(status().isOk());
    }

    @Test
    void refreshSiguePublicoConCookieDeRenovacion() throws Exception {
        when(authService.refresh("v2.refresh")).thenReturn(
                new AuthResult(
                        new LoginResponse("jwt", "Bearer", 900, "SOCIO", "Ana", "Perez"),
                        "v3.refresh"
                )
        );
        when(refreshCookieService.crear("v3.refresh")).thenReturn(
                ResponseCookie.from("refresh_token", "v3.refresh").build()
        );

        mockMvc.perform(post("/api/auth/refresh")
                        .cookie(new jakarta.servlet.http.Cookie(
                                "refresh_token", "v2.refresh"
                        )))
                .andExpect(status().isOk());
    }

    @Test
    void logoutRequiereAutenticacion() throws Exception {
        mockMvc.perform(post("/api/auth/logout"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    void logoutAceptaCualquierRolAutenticado() throws Exception {
        when(refreshCookieService.borrar()).thenReturn(
                ResponseCookie.from("refresh_token", "").maxAge(0).build()
        );

        for (String rol : new String[]{
                "SOCIO", "FUNCIONARIO", "MEDICO", "ADMINISTRADOR"
        }) {
            mockMvc.perform(post("/api/auth/logout")
                            .with(jwt().authorities(
                                    new SimpleGrantedAuthority("ROLE_" + rol)
                            ))
                            .cookie(new jakarta.servlet.http.Cookie(
                                    "refresh_token", "v2.refresh"
                            )))
                    .andExpect(status().isNoContent());
        }

        verify(authService, times(4)).logout("v2.refresh");
    }

    @Test
    void registroPublicoAntiguoYaNoEsAccesibleSinSesion() throws Exception {
        mockMvc.perform(
                        post("/api/auth/registro")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{}")
                )
                .andExpect(status().isUnauthorized());
        mockMvc.perform(get("/api/auth/confirmar-email").param("token", "x"))
                .andExpect(status().isUnauthorized());
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void registroAntiguoNoExisteNiParaAdministradores() throws Exception {
        mockMvc.perform(
                        post("/api/auth/registro")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{}")
                )
                .andExpect(status().is4xxClientError())
                .andExpect(result -> {
                    if (result.getResponse().getStatus() < 400
                            || result.getResponse().getStatus() == 201) {
                        throw new AssertionError("El registro no debe crear usuarios");
                    }
                });
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void endpointsDeLaPocYaNoSeAtienden() throws Exception {
        mockMvc.perform(get("/api/mis-reservas")).andExpect(status().isNotFound());
        mockMvc.perform(get("/api/profesionales")).andExpect(status().isNotFound());
        mockMvc.perform(
                        post("/api/reservas")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{}")
                )
                .andExpect(status().is4xxClientError());
    }
}
