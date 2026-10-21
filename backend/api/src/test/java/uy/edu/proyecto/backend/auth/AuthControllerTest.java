package uy.edu.proyecto.backend.auth;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.header;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseCookie;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

class AuthControllerTest {

    private final AuthService service = mock(AuthService.class);
    private final RefreshCookieService cookieService =
            mock(RefreshCookieService.class);
    private MockMvc mockMvc;

    @BeforeEach
    void configurar() {
        mockMvc = MockMvcBuilders
                .standaloneSetup(new AuthController(service, cookieService))
                .build();
    }

    @Test
    void loginNuevoDevuelveSesionYCookieHttpOnly() throws Exception {
        when(service.login(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new AuthResult(
                        new LoginResponse(
                                "jwt",
                                "Bearer",
                                900,
                                "SOCIO",
                                "Ana",
                                "Perez"
                        ),
                        "v2.refresh"
                ));
        when(cookieService.crear("v2.refresh"))
                .thenReturn(ResponseCookie.from("refresh_token", "v2.refresh")
                        .httpOnly(true)
                        .path("/api/auth")
                        .build());

        mockMvc.perform(
                        post("/api/auth/login")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {
                                          "ci":"67890127",
                                          "password":"clave",
                                          "acceso":"SOCIO",
                                          "plataforma":"WEB"
                                        }
                                        """)
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.token").value("jwt"))
                .andExpect(jsonPath("$.role").value("SOCIO"))
                .andExpect(jsonPath("$.nombre").value("Ana"))
                .andExpect(header().string("Set-Cookie", org.hamcrest.Matchers.containsString("HttpOnly")));

        verify(service).login(new LoginRequest(
                "67890127",
                "clave",
                "SOCIO",
                "WEB",
                null,
                null
        ));
    }

    @Test
    void loginLegadoSigueAceptandoCedulaYClave() throws Exception {
        when(service.login(org.mockito.ArgumentMatchers.any()))
                .thenReturn(new AuthResult(
                        new LoginResponse("jwt", "Bearer", 900, "PACIENTE", null, null),
                        "refresh"
                ));
        when(cookieService.crear("refresh"))
                .thenReturn(ResponseCookie.from("refresh_token", "refresh")
                        .httpOnly(true)
                        .path("/api/auth")
                        .build());

        mockMvc.perform(
                        post("/api/auth/login")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"cedula":"1234567","clave":"clave"}
                                        """)
                )
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.role").value("PACIENTE"))
                .andExpect(jsonPath("$.nombre").doesNotExist());

        verify(service).login(new LoginRequest(
                null,
                null,
                null,
                null,
                "1234567",
                "clave"
        ));
    }
}
