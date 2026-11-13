package uy.edu.proyecto.backend.usuario;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

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

@WebMvcTest(controllers = {
        DatosPersonalesController.class,
        CambioCorreoController.class
})
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class DatosPersonalesSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private DatosPersonalesService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private DatosPersonalesResponse datos() {
        return new DatosPersonalesResponse(
                91L, "45678911", "Ana", "Perez", "SOCIO",
                "ana@example.org", null,
                "099111222", null, "Calle 1"
        );
    }

    @Test
    void obtenerDatosRequiereAutenticacion() throws Exception {
        mockMvc.perform(get("/api/cuentas/me"))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }

    @Test
    void actualizarDatosRequiereAutenticacion() throws Exception {
        mockMvc.perform(patch("/api/cuentas/me")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"direccion\":\"Calle 9\"}"))
                .andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }

    @Test
    void cualquierRolAutenticadoLeeYEditaSusDatos() throws Exception {
        when(service.obtener(91L)).thenReturn(datos());
        when(service.actualizar(eq(91L), any())).thenReturn(datos());

        for (String rol : new String[]{
                "SOCIO", "FUNCIONARIO", "MEDICO", "ADMINISTRADOR"
        }) {
            var auth = jwt().jwt(token -> token.subject("91"))
                    .authorities(new SimpleGrantedAuthority("ROLE_" + rol));
            mockMvc.perform(get("/api/cuentas/me").with(auth))
                    .andExpect(status().isOk())
                    .andExpect(jsonPath("$.ci").value("45678911"));
            mockMvc.perform(patch("/api/cuentas/me").with(auth)
                            .contentType(MediaType.APPLICATION_JSON)
                            .content("{\"direccion\":\"Calle 9\"}"))
                    .andExpect(status().isOk());
        }
    }

    @Test
    void camposProtegidosSeRechazanCon400() throws Exception {
        String[] cuerpos = {
                "{\"ci\":\"12345678\"}",
                "{\"nombre\":\"Otro\"}",
                "{\"apellido\":\"Otro\"}",
                "{\"fechaNacimiento\":\"2000-01-01\"}",
                "{\"rol\":\"ADMINISTRADOR\"}",
                "{\"habilitada\":false}",
                "{\"id\":1}",
                "{\"direccion\":\"Calle 9\",\"estado\":\"INACTIVA\"}"
        };
        for (String cuerpo : cuerpos) {
            mockMvc.perform(patch("/api/cuentas/me")
                            .with(jwt().jwt(token -> token.subject("91"))
                                    .authorities(new SimpleGrantedAuthority(
                                            "ROLE_SOCIO")))
                            .contentType(MediaType.APPLICATION_JSON)
                            .content(cuerpo))
                    .andExpect(status().isBadRequest())
                    .andExpect(jsonPath("$.code").value("VALIDACION"));
        }
        verifyNoInteractions(service);
    }

    @Test
    void confirmarCambioDeCorreoEsPublico() throws Exception {
        mockMvc.perform(post("/api/auth/cambio-correo/confirmar")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"token\":\"abc\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.message").exists());

        verify(service).confirmarCambioCorreo(any());
    }
}
