package uy.edu.proyecto.backend.auth;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
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

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.exception.ApiExceptionHandler;

class AuthControllerTest {

    private final AuthService service = mock(AuthService.class);
    private final CambioContrasenaService cambioContrasenaService =
            mock(CambioContrasenaService.class);
    private final RefreshCookieService cookieService =
            mock(RefreshCookieService.class);
    private MockMvc mockMvc;

    @BeforeEach
    void configurar() {
        mockMvc = MockMvcBuilders
                .standaloneSetup(new AuthController(
                        service, cambioContrasenaService, cookieService))
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @Test
    void loginDevuelveSesionYCookieHttpOnly() throws Exception {
        when(service.login(any()))
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
                "WEB"
        ));
    }

    @Test
    void cuerpoAntiguoCedulaClaveSeTrataSinCamposDelContrato() throws Exception {
        when(service.login(new LoginRequest(null, null, null, null)))
                .thenThrow(new ApiException(
                        org.springframework.http.HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "Falta un campo obligatorio"
                ));

        mockMvc.perform(
                        post("/api/auth/login")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("""
                                        {"cedula":"1234567","clave":"clave"}
                                        """)
                )
                .andExpect(status().isBadRequest())
                .andExpect(header().doesNotExist("Set-Cookie"));
    }

    @Test
    void registroPublicoYConfirmacionAntiguaNoExisten() throws Exception {
        mockMvc.perform(
                        post("/api/auth/registro")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content("{}")
                )
                .andExpect(status().is4xxClientError());
        mockMvc.perform(get("/api/auth/confirmar-email").param("token", "x"))
                .andExpect(status().isNotFound());
    }
}
