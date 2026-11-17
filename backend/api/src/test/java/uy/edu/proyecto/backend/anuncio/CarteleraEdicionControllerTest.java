package uy.edu.proyecto.backend.anuncio;

import java.nio.charset.StandardCharsets;
import java.util.List;
import java.util.Map;
import org.junit.jupiter.api.Test;
import org.mockito.ArgumentCaptor;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.http.HttpMethod;
import org.springframework.http.HttpStatus;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.request.RequestPostProcessor;
import org.springframework.web.multipart.MultipartFile;
import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.exception.ApiException;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

/** PUT /api/admin/anuncios/{id}: ruta, roles, multipart y formato de los errores. */
@WebMvcTest(controllers = CarteleraController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class CarteleraEdicionControllerTest {
    private static final String RUTA = "/api/admin/anuncios/42";
    private static final String DATOS = "{\"titulo\":\"Titulo\",\"resumen\":\"Resumen\",\"texto\":\"Texto\"}";

    @Autowired MockMvc mvc;
    @MockitoBean CarteleraService service;
    @MockitoBean JwtDecoder jwtDecoder;

    private static RequestPostProcessor rol(String rol) {
        return jwt().authorities(new SimpleGrantedAuthority("ROLE_" + rol));
    }

    private static MockMultipartFile datos(String json) {
        return new MockMultipartFile("datos", "datos.json", "application/json",
                json.getBytes(StandardCharsets.UTF_8));
    }

    private static org.springframework.test.web.servlet.request.MockMultipartHttpServletRequestBuilder put(String ruta) {
        return multipart(HttpMethod.PUT, ruta);
    }

    @Test
    void sinTokenRecibe401() throws Exception {
        mvc.perform(put(RUTA).file(datos(DATOS))).andExpect(status().isUnauthorized());
        verifyNoInteractions(service);
    }

    @Test
    void siNoEsAdministradorRecibe403() throws Exception {
        for (String rol : List.of("SOCIO", "MEDICO", "FUNCIONARIO")) {
            mvc.perform(put(RUTA).file(datos(DATOS)).with(rol(rol))).andExpect(status().isForbidden());
        }
        verifyNoInteractions(service);
    }

    @Test
    void elAdministradorEditaYRecibe204() throws Exception {
        mvc.perform(put(RUTA).file(datos(DATOS)).with(rol("ADMINISTRADOR")))
                .andExpect(status().isNoContent());

        verify(service).editar(42, new AnuncioDTO.Edicion("Titulo", "Resumen", "Texto"), Map.of());
    }

    @Test
    void laParteDatosNoCuentaComoArchivoPeroLasDemasSi() throws Exception {
        var nueva = new MockMultipartFile("nueva1", "a.png", "image/png", new byte[] {1, 2});

        mvc.perform(put(RUTA).file(datos(DATOS)).file(nueva).with(rol("ADMINISTRADOR")))
                .andExpect(status().isNoContent());

        @SuppressWarnings("unchecked")
        ArgumentCaptor<Map<String, MultipartFile>> captor = ArgumentCaptor.forClass(Map.class);
        verify(service).editar(eq(42L), any(), captor.capture());
        assertEquals(List.of("nueva1"), List.copyOf(captor.getValue().keySet()));
    }

    @Test
    void laListaDeImagenesLlegaTalCualComoIdsYArchivos() throws Exception {
        var nueva = new MockMultipartFile("nueva1", "a.png", "image/png", new byte[] {1});
        String json = "{\"titulo\":\"Titulo\",\"texto\":\"Texto\","
                + "\"imagenes\":[{\"id\":12},{\"archivo\":\"nueva1\"},{\"id\":14}]}";

        mvc.perform(put(RUTA).file(datos(json)).file(nueva).with(rol("ADMINISTRADOR")))
                .andExpect(status().isNoContent());

        verify(service).editar(eq(42L), eq(new AnuncioDTO.Edicion("Titulo", null, "Texto", List.of(
                new AnuncioDTO.ImagenEdicion(12L, null), new AnuncioDTO.ImagenEdicion(null, "nueva1"),
                new AnuncioDTO.ImagenEdicion(14L, null)))), any());
    }

    @Test
    void imagenesVaciasAusentesONulasSeDistinguen() throws Exception {
        mvc.perform(put(RUTA).file(datos("{\"titulo\":\"T\",\"texto\":\"X\",\"imagenes\":[]}")).with(rol("ADMINISTRADOR")))
                .andExpect(status().isNoContent());
        mvc.perform(put(RUTA).file(datos("{\"titulo\":\"T\",\"texto\":\"X\",\"imagenes\":null}")).with(rol("ADMINISTRADOR")))
                .andExpect(status().isNoContent());
        mvc.perform(put(RUTA).file(datos("{\"titulo\":\"T\",\"texto\":\"X\"}")).with(rol("ADMINISTRADOR")))
                .andExpect(status().isNoContent());

        verify(service).editar(eq(42L), eq(new AnuncioDTO.Edicion("T", null, "X", List.of())), any());
        verify(service, org.mockito.Mockito.times(2))
                .editar(eq(42L), eq(new AnuncioDTO.Edicion("T", null, "X", null)), any());
    }

    @Test
    void dosArchivosConElMismoNombreSonUnaValidacion() throws Exception {
        var una = new MockMultipartFile("nueva1", "a.png", "image/png", new byte[] {1});
        var otra = new MockMultipartFile("nueva1", "b.png", "image/png", new byte[] {2});

        mvc.perform(put(RUTA).file(datos(DATOS)).file(una).file(otra).with(rol("ADMINISTRADOR")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"))
                .andExpect(jsonPath("$.message").value("Hay dos archivos con el mismo nombre: nueva1"));
        verifyNoInteractions(service);
    }

    @Test
    void sinLaParteDatosEs400ConElFormatoDeError() throws Exception {
        mvc.perform(put(RUTA).file(new MockMultipartFile("otra", "x.txt", "text/plain", new byte[] {1}))
                        .with(rol("ADMINISTRADOR")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));
        verifyNoInteractions(service);
    }

    @Test
    void conUnJsonInvalidoEs400ConElFormatoDeError() throws Exception {
        mvc.perform(put(RUTA).file(datos("{no es json")).with(rol("ADMINISTRADOR")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));
        verifyNoInteractions(service);
    }

    @Test
    void unaNovedadInexistenteEs404ConElFormatoDeError() throws Exception {
        doThrow(new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO", "Anuncio no encontrado"))
                .when(service).editar(anyLong(), any(), any());

        mvc.perform(put("/api/admin/anuncios/99").file(datos(DATOS)).with(rol("ADMINISTRADOR")))
                .andExpect(status().isNotFound())
                .andExpect(jsonPath("$.code").value("NO_ENCONTRADO"));
    }

    @Test
    void unaValidacionDelServicioLlegaConSuMensaje() throws Exception {
        doThrow(new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                "El título es obligatorio y admite hasta 160 caracteres"))
                .when(service).editar(anyLong(), any(), any());

        mvc.perform(put(RUTA).file(datos("{\"titulo\":\"\"}")).with(rol("ADMINISTRADOR")))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"))
                .andExpect(jsonPath("$.message").value("El título es obligatorio y admite hasta 160 caracteres"));
    }

    @Test
    void laRutaDeVigenciaSigueSiendoOtra() throws Exception {
        mvc.perform(org.springframework.test.web.servlet.request.MockMvcRequestBuilders
                        .put(RUTA + "/vigencia")
                        .contentType("application/json")
                        .content("{\"vigenteDesde\":null,\"vigenteHasta\":\"2099-01-01T00:00:00Z\"}")
                        .with(rol("ADMINISTRADOR")))
                .andExpect(status().isNoContent());
    }
}
