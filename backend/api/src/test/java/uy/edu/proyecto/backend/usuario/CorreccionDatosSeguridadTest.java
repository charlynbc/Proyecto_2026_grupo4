package uy.edu.proyecto.backend.usuario;

import static org.mockito.ArgumentMatchers.any;
import static org.mockito.ArgumentMatchers.anyLong;
import static org.mockito.ArgumentMatchers.eq;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.patch;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import java.time.LocalDate;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.http.MediaType;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import uy.edu.proyecto.backend.consultorio.Consultorio;
import uy.edu.proyecto.backend.consultorio.ConsultorioService;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.especialidad.EspecialidadService;

/**
 * Seguridad de la correccion administrativa de datos (RF-38): los tres
 * endpoints PATCH son exclusivos del rol ADMINISTRADOR.
 */
@SpringBootTest
@AutoConfigureMockMvc
class CorreccionDatosSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private CorreccionUsuarioService correccionUsuarioService;

    @MockitoBean
    private EspecialidadService especialidadService;

    @MockitoBean
    private ConsultorioService consultorioService;

    /* ---------- Usuarios ---------- */

    @Test
    void corregirUsuarioSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(patch("/api/usuarios/10")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Nuevo\"}"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(correccionUsuarioService);
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioNoPuedeCorregirUsuarios() throws Exception {
        mockMvc.perform(patch("/api/usuarios/10")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Nuevo\"}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(correccionUsuarioService);
    }

    @Test
    @WithMockUser(roles = "FUNCIONARIO")
    void funcionarioNoPuedeCorregirUsuarios() throws Exception {
        mockMvc.perform(patch("/api/usuarios/10")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Nuevo\"}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(correccionUsuarioService);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorCorrigeUsuarios() throws Exception {
        when(correccionUsuarioService.corregir(eq(10L), any()))
                .thenReturn(new CorreccionUsuarioResponse(
                        10L, "12345672", "Sofia", "Socia",
                        LocalDate.of(1985, 5, 5), "SOCIO",
                        "sofia@ejemplo.invalid", "099111222", null,
                        "Calle Falsa 123", List.of(), "ACTIVA", true));

        mockMvc.perform(patch("/api/usuarios/10")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"nombre\":\"Sofia\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.id").value(10))
                .andExpect(jsonPath("$.rol").value("SOCIO"));

        verify(correccionUsuarioService).corregir(eq(10L), any());
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void corregirUsuarioRechazaElRol() throws Exception {
        mockMvc.perform(patch("/api/usuarios/10")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"rol\":\"ADMINISTRADOR\"}"))
                .andExpect(status().isBadRequest())
                .andExpect(jsonPath("$.code").value("VALIDACION"));

        verifyNoInteractions(correccionUsuarioService);
    }

    /* ---------- Especialidades ---------- */

    @Test
    void corregirEspecialidadSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(patch("/api/especialidades/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requierePase\":false}"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(especialidadService);
    }

    @Test
    @WithMockUser(roles = "FUNCIONARIO")
    void funcionarioNoPuedeCorregirEspecialidades() throws Exception {
        mockMvc.perform(patch("/api/especialidades/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requierePase\":false}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(especialidadService);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorCorrigeEspecialidades() throws Exception {
        when(especialidadService.corregir(1L, null, false))
                .thenReturn(new Especialidad(1L, "Cardiología", false));

        mockMvc.perform(patch("/api/especialidades/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"requierePase\":false}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.requierePase").value(false));

        verify(especialidadService).corregir(1L, null, false);
    }

    /* ---------- Consultorios ---------- */

    @Test
    void corregirConsultorioSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(patch("/api/consultorios/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ubicacion\":\"Piso 9\"}"))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(consultorioService);
    }

    @Test
    @WithMockUser(roles = "MEDICO")
    void medicoNoPuedeCorregirConsultorios() throws Exception {
        mockMvc.perform(patch("/api/consultorios/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ubicacion\":\"Piso 9\"}"))
                .andExpect(status().isForbidden());

        verifyNoInteractions(consultorioService);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorCorrigeConsultorios() throws Exception {
        when(consultorioService.corregir(1L, null, "Piso 9"))
                .thenReturn(new Consultorio(1L, "Consultorio 1", "Piso 9"));

        mockMvc.perform(patch("/api/consultorios/1")
                        .contentType(MediaType.APPLICATION_JSON)
                        .content("{\"ubicacion\":\"Piso 9\"}"))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.ubicacion").value("Piso 9"));

        verify(consultorioService).corregir(1L, null, "Piso 9");
    }
}
