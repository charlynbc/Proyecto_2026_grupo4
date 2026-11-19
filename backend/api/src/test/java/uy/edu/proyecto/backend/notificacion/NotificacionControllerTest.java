package uy.edu.proyecto.backend.notificacion;

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
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.post;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** GET /api/notificaciones: solo el socio, con su id del token, y la forma de la respuesta del contrato. */
@WebMvcTest(controllers = NotificacionController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class NotificacionControllerTest {
    private static final String RUTA = "/api/notificaciones";

    @Autowired MockMvc mvc;
    @MockitoBean NotificacionService service;
    @MockitoBean JwtDecoder jwtDecoder;

    private static RequestPostProcessor rol(String rol, String sujeto) {
        return jwt().authorities(new SimpleGrantedAuthority("ROLE_" + rol)).jwt(token -> token.subject(sujeto));
    }

    @Test
    void sinTokenRecibe401() throws Exception {
        mvc.perform(get(RUTA)).andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }

    @Test
    void conCualquierOtroRolRecibe403() throws Exception {
        for (String rol : List.of("FUNCIONARIO", "MEDICO", "ADMINISTRADOR")) {
            mvc.perform(get(RUTA).with(rol(rol, "5"))).andExpect(status().isForbidden());
        }
        verifyNoInteractions(service);
    }

    @Test
    void otroRolNoPuedeNiConLosParametrosDeOtroSocio() throws Exception {
        mvc.perform(get(RUTA + "?socioId=77").with(rol("ADMINISTRADOR", "5"))).andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }

    @Test
    void elSocioSeSacaDelTokenYNoDelPedido() throws Exception {
        when(service.listar(any(), any(), any())).thenReturn(new NotificacionPageResponse(List.of(), 0, 20, 0));

        mvc.perform(get(RUTA + "?socioId=5&idSocio=5&id=5").with(rol("SOCIO", "77"))).andExpect(status().isOk());

        verify(service).listar(eq(77L), eq(null), eq(null));
    }

    @Test
    void pasaPageYSizeTalCualAlServicio() throws Exception {
        when(service.listar(any(), any(), any())).thenReturn(new NotificacionPageResponse(List.of(), 2, 5, 0));

        mvc.perform(get(RUTA + "?page=2&size=5").with(rol("SOCIO", "77"))).andExpect(status().isOk());

        verify(service).listar(77L, "2", "5");
    }

    @Test
    void respondeConLosCamposExactosDelContrato() throws Exception {
        when(service.listar(any(), any(), any())).thenReturn(new NotificacionPageResponse(List.of(
                new NotificacionDTO(15001, "SUSPENSION", "Turno suspendido", "Se suspendió el turno",
                        OffsetDateTime.parse("2026-10-16T11:20:00-03:00"), 9001)), 0, 20, 1));

        mvc.perform(get(RUTA).with(rol("SOCIO", "77")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items[0].id").value(15001))
                .andExpect(jsonPath("$.items[0].tipo").value("SUSPENSION"))
                .andExpect(jsonPath("$.items[0].titulo").value("Turno suspendido"))
                .andExpect(jsonPath("$.items[0].contenido").value("Se suspendió el turno"))
                .andExpect(jsonPath("$.items[0].creadaEn").value("2026-10-16T11:20:00-03:00"))
                .andExpect(jsonPath("$.items[0].consultaId").value(9001))
                .andExpect(jsonPath("$.items[0].length()").value(6))
                .andExpect(jsonPath("$.page").value(0))
                .andExpect(jsonPath("$.size").value(20))
                .andExpect(jsonPath("$.total").value(1))
                .andExpect(jsonPath("$.length()").value(4));
    }

    @Test
    void sinAvisosDevuelveItemsVaciosYTotalCero() throws Exception {
        when(service.listar(any(), any(), any())).thenReturn(new NotificacionPageResponse(List.of(), 0, 20, 0));

        mvc.perform(get(RUTA).with(rol("SOCIO", "77")))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.items").isArray())
                .andExpect(jsonPath("$.items.length()").value(0))
                .andExpect(jsonPath("$.total").value(0));
    }

    @Test
    void unaValidacionDelServicioLlegaComoCodeYMessage() throws Exception {
        when(service.listar(any(), anyString(), any())).thenThrow(
                new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", "page debe ser un entero mayor o igual a 0"));

        mvc.perform(get(RUTA + "?page=-1").with(rol("SOCIO", "77")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"))
                .andExpect(jsonPath("$.message").value("page debe ser un entero mayor o igual a 0"));
    }

    @Test
    void unTokenSinSujetoNumericoEs401SinPasarPorElServicio() throws Exception {
        for (String sujeto : new String[] {"no-es-un-numero", "0", "-3"}) {
            mvc.perform(get(RUTA).with(rol("SOCIO", sujeto)))
                    .andExpect(status().isUnauthorized())
                    .andExpect(jsonPath("$.code").value("TOKEN_INVALIDO"));
        }
        verifyNoInteractions(service);
    }

    @Test
    void otrosMetodosTampocoSonDeOtroRol() throws Exception {
        mvc.perform(post(RUTA).with(rol("MEDICO", "5"))).andExpect(status().isForbidden());
        verifyNoInteractions(service);
    }
}
