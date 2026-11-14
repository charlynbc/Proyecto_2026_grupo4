package uy.edu.proyecto.backend.dispositivo;

import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = DispositivoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class DispositivoControllerTest {

    private static final OffsetDateTime REGISTRADO =
            OffsetDateTime.parse("2026-10-14T10:20:00-03:00");
    private static final String CUERPO = "{\"token\":\"fcm-token-1\"}";

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private DispositivoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private static RequestPostProcessor socio() {
        return jwt().jwt(token -> token.subject("91"))
                .authorities(new SimpleGrantedAuthority("ROLE_SOCIO"));
    }

    private static DispositivoRegistro registro(boolean creado) {
        return new DispositivoRegistro(new DispositivoDTO(61L, true, REGISTRADO), creado);
    }

    @Test
    void registroNuevoDevuelve201ConElCuerpoDelContrato() throws Exception {
        when(service.registrar(91L, "fcm-token-1")).thenReturn(registro(true));

        mockMvc.perform(post("/api/dispositivos")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(CUERPO))
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(61))
                .andExpect(jsonPath("$.habilitado").value(true))
                .andExpect(jsonPath("$.registradoEn").value("2026-10-14T10:20:00-03:00"));
    }

    @Test
    void registroDeUnaFilaExistenteDevuelve200ConElMismoCuerpo() throws Exception {
        when(service.registrar(91L, "fcm-token-1")).thenReturn(registro(false));

        mockMvc.perform(post("/api/dispositivos")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(CUERPO))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(61))
                .andExpect(jsonPath("$.habilitado").value(true))
                .andExpect(jsonPath("$.registradoEn").value("2026-10-14T10:20:00-03:00"));
    }

    @Test
    void unTokenInvalidoDevuelve400ConElCodigoVALIDACION() throws Exception {
        when(service.registrar(91L, "   ")).thenThrow(new ApiException(
                HttpStatus.BAD_REQUEST, "VALIDACION", "Falta el identificador."));

        mockMvc.perform(post("/api/dispositivos")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"   \"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"))
                .andExpect(jsonPath("$.message").value("Falta el identificador."));
    }

    @Test
    void sinCampoTokenElServicioRecibeNuloYResponde400() throws Exception {
        when(service.registrar(91L, null)).thenThrow(new ApiException(
                HttpStatus.BAD_REQUEST, "VALIDACION", "Falta el identificador."));

        mockMvc.perform(post("/api/dispositivos")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verify(service).registrar(91L, null);
    }

    @Test
    void registroSinCuerpoDevuelve400ConElCodigoVALIDACION() throws Exception {
        mockMvc.perform(post("/api/dispositivos")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"))
                .andExpect(jsonPath("$.message").isNotEmpty());

        verifyNoInteractions(service);
    }

    @Test
    void registroConJsonMalFormadoDevuelve400ConElCodigoVALIDACION() throws Exception {
        mockMvc.perform(post("/api/dispositivos")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verifyNoInteractions(service);
    }

    @Test
    void bajaDevuelve204SinCuerpo() throws Exception {
        mockMvc.perform(post("/api/dispositivos/baja")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content(CUERPO))
                .andExpect(status().isNoContent())
                .andExpect(content().string(""));

        verify(service).darDeBaja(91L, "fcm-token-1");
    }

    @Test
    void bajaConTokenInvalidoDevuelve400ConElCodigoVALIDACION() throws Exception {
        doThrow(new ApiException(
                        HttpStatus.BAD_REQUEST, "VALIDACION", "Falta el identificador."))
                .when(service).darDeBaja(91L, "");

        mockMvc.perform(post("/api/dispositivos/baja")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));
    }

    @Test
    void bajaSinCuerpoDevuelve400ConElCodigoVALIDACION() throws Exception {
        mockMvc.perform(post("/api/dispositivos/baja")
                        .with(socio())
                        .contentType(MediaType.APPLICATION_JSON))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verifyNoInteractions(service);
    }
}
