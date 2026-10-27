package uy.edu.proyecto.backend.medico;

import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.webmvc.test.autoconfigure.WebMvcTest;
import org.springframework.context.annotation.Import;
import org.springframework.security.core.authority.SimpleGrantedAuthority;
import org.springframework.security.oauth2.jwt.JwtDecoder;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.config.SecurityConfig;
import uy.edu.proyecto.backend.config.SecurityErrorHandler;
import uy.edu.proyecto.backend.especialidad.Especialidad;

import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.security.test.web.servlet.request.SecurityMockMvcRequestPostProcessors.jwt;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@WebMvcTest(controllers = MedicoController.class)
@Import({SecurityConfig.class, SecurityErrorHandler.class})
@TestPropertySource(properties = "app.cors.allowed-origin=http://localhost:5173")
class MedicoSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private MedicoService service;

    @MockitoBean
    private JwtDecoder jwtDecoder;

    @Test
    void funcionarioPuedeListarMedicosYEspecialidadesSinDatosSensibles() throws Exception {
        when(service.listar(3L)).thenReturn(List.of(new MedicoDTO(
                17L,
                "Marta",
                "Rodriguez",
                List.of(new Especialidad(3L, "Cardiologia", true))
        )));

        mockMvc.perform(get("/api/medicos?especialidadId=3")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                        )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$[0].id").value(17))
                .andExpect(jsonPath("$[0].nombre").value("Marta"))
                .andExpect(jsonPath("$[0].apellido").value("Rodriguez"))
                .andExpect(jsonPath("$[0].especialidades[0].id").value(3))
                .andExpect(jsonPath("$[0].password").doesNotExist())
                .andExpect(jsonPath("$[0].correo").doesNotExist());

        verify(service).listar(3L);
    }

    @Test
    void medicoSinResultadosDevuelveListaVacia() throws Exception {
        when(service.listar(null)).thenReturn(List.of());

        mockMvc.perform(get("/api/medicos")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                        )))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$").isEmpty());
    }

    @Test
    void rolDistintoDeFuncionarioNoPuedeConsultarMedicos() throws Exception {
        mockMvc.perform(get("/api/medicos")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_SOCIO")
                        )))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    void consultaSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(get("/api/medicos"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void parametroDeEspecialidadNoNumericoDevuelve400() throws Exception {
        mockMvc.perform(get("/api/medicos?especialidadId=abc")
                        .with(jwt().authorities(
                                new SimpleGrantedAuthority("ROLE_FUNCIONARIO")
                        )))
                .andExpect(status().isBadRequest());

        verifyNoInteractions(service);
    }
}
