package uy.edu.proyecto.backend.usuario;

import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;
import static org.mockito.Mockito.verify;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

import com.fasterxml.jackson.databind.ObjectMapper;

import uy.edu.proyecto.backend.exception.ApiExceptionHandler;

class AltaUsuarioControllerTest {

    private final AltaUsuarioService service = mock(AltaUsuarioService.class);
    private final UsuarioService usuarioService = mock(UsuarioService.class);
    private final ObjectMapper objectMapper = new ObjectMapper().findAndRegisterModules();
    private static final long ADMIN = 1L;
    private MockMvc mockMvc;

    @BeforeEach
    void configurar() {
        var jwt = org.springframework.security.oauth2.jwt.Jwt.withTokenValue("t")
                .header("alg", "none").subject("1").build();
        org.springframework.security.core.context.SecurityContextHolder.getContext().setAuthentication(
                new org.springframework.security.authentication.TestingAuthenticationToken(jwt, null, "ROLE_ADMINISTRADOR"));
        mockMvc = MockMvcBuilders
                .standaloneSetup(new AltaUsuarioController(service, usuarioService))
                .setCustomArgumentResolvers(
                        new org.springframework.security.web.method.annotation.AuthenticationPrincipalArgumentResolver())
                .setControllerAdvice(new ApiExceptionHandler())
                .build();
    }

    @org.junit.jupiter.api.AfterEach
    void limpiar() {
        org.springframework.security.core.context.SecurityContextHolder.clearContext();
    }

    @Test
    void crearDevuelveLaCuentaPendienteConStatus201() throws Exception {
        AltaUsuarioRequest request = new AltaUsuarioRequest(
                "67890127",
                "Ana",
                "Perez",
                LocalDate.of(1990, 1, 1),
                "ana@example.org",
                "099111222",
                null,
                null,
                "SOCIO",
                List.of()
        );
        when(service.crear(request)).thenReturn(new CuentaCreadaResponse(
                12L,
                "67890127",
                "Ana",
                "Perez",
                "SOCIO",
                "ACTIVA",
                false
        ));

        mockMvc.perform(
                        post("/api/usuarios")
                                .contentType(MediaType.APPLICATION_JSON)
                                .content(objectMapper.writeValueAsString(request))
                )
                .andExpect(status().isCreated())
                .andExpect(jsonPath("$.id").value(12))
                .andExpect(jsonPath("$.ci").value("67890127"))
                .andExpect(jsonPath("$.estado").value("ACTIVA"))
                .andExpect(jsonPath("$.activada").value(false));

        verify(service).crear(request);
    }

    @Test
    void listarDevuelveUnaPaginaDeCuentasConLosFiltrosSolicitados() throws Exception {
        when(usuarioService.listar(ADMIN, "SOCIO", "ACTIVA", "45678911", 0, 10))
                .thenReturn(new UsuarioCuentaPageResponse(
                        List.of(new UsuarioCuentaDTO(
                                42L,
                                "45678911",
                                "Lucia",
                                "Fernandez",
                                "SOCIO",
                                "lucia@example.org",
                                "ACTIVA",
                                true,
                                java.time.OffsetDateTime.parse("2026-09-01T09:00:00-03:00"),
                                false
                        )),
                        0,
                        10,
                        1
                ));

        mockMvc.perform(get("/api/usuarios")
                        .param("rol", "SOCIO")
                        .param("estado", "ACTIVA")
                        .param("texto", "45678911")
                        .param("page", "0")
                        .param("size", "10"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(42))
                .andExpect(jsonPath("$.items[0].ci").value("45678911"))
                .andExpect(jsonPath("$.items[0].fechaAlta").exists())
                .andExpect(jsonPath("$.items[0].puedeInactivar").value(false))
                .andExpect(jsonPath("$.items[0].password").doesNotExist());

        verify(usuarioService).listar(ADMIN, "SOCIO", "ACTIVA", "45678911", 0, 10);
    }
}
