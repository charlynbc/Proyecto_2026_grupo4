package uy.edu.proyecto.backend.anuncio;

import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpStatus;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.exception.ApiException;

/** GET /api/admin/anuncios/{id}: el detalle de cualquier novedad, solo para el administrador. */
@WebMvcTest(controllers = CarteleraController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class CarteleraDetalleAdminTest {

    private static final String RUTA = "/api/admin/anuncios/42";

    @Autowired
    private MockMvc mvc;

    @MockitoBean
    private CarteleraService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    private static org.springframework.test.web.servlet.request.RequestPostProcessor rol(String rol) {
        return jwt().authorities(new SimpleGrantedAuthority("ROLE_" + rol));
    }

    private void vencida() {
        when(service.detalle(42)).thenReturn(new AnuncioDTO.DetalleAdministracion(
                42, "Campana de vacunacion", "Resumen corto", "**Comienza** el lunes",
                OffsetDateTime.parse("2026-11-01T10:00:00-03:00"), null,
                OffsetDateTime.parse("2026-11-10T00:00:00-03:00"), "VENCIDO", null,
                List.of(new AnuncioDTO.Imagen(101, 0, "https://storage.example/101"))));
    }

    @Test
    void sinTokenRecibe401() throws Exception {
        mvc.perform(get(RUTA)).andExpect(status().isUnauthorized());
    }

    @Test
    void siNoEsAdministradorRecibe403() throws Exception {
        for (String rol : List.of("SOCIO", "MEDICO", "FUNCIONARIO")) {
            mvc.perform(get(RUTA).with(rol(rol))).andExpect(status().isForbidden());
        }
    }

    @Test
    void elAdministradorVeUnaVencidaConTodoSuContenido() throws Exception {
        vencida();
        mvc.perform(get(RUTA).with(rol("ADMINISTRADOR")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(42))
                .andExpect(jsonPath("$.titulo").value("Campana de vacunacion"))
                .andExpect(jsonPath("$.resumen").value("Resumen corto"))
                .andExpect(jsonPath("$.texto").value("**Comienza** el lunes"))
                .andExpect(jsonPath("$.publicadoEn").value("2026-11-01T10:00:00-03:00"))
                .andExpect(jsonPath("$.vigenteDesde").doesNotExist())
                .andExpect(jsonPath("$.vigenteHasta").value("2026-11-10T00:00:00-03:00"))
                .andExpect(jsonPath("$.estado").value("VENCIDO"))
                .andExpect(jsonPath("$.posicion").doesNotExist())
                .andExpect(jsonPath("$.imagenes[0].id").value(101))
                .andExpect(jsonPath("$.imagenes[0].orden").value(0))
                .andExpect(jsonPath("$.imagenes[0].url").value("https://storage.example/101"));
    }

    @Test
    void siNoExisteResponde404ConElFormatoDeError() throws Exception {
        when(service.detalle(99)).thenThrow(
                new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO", "Anuncio no encontrado"));
        mvc.perform(get("/api/admin/anuncios/99").with(rol("ADMINISTRADOR")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NO_ENCONTRADO"));
    }
}
