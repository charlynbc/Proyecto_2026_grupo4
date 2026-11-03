package uy.edu.proyecto.backend.usuario;

import java.nio.charset.StandardCharsets;
import java.util.List;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.boot.webmvc.test.autoconfigure.AutoConfigureMockMvc;
import org.springframework.mock.web.MockMultipartFile;
import org.springframework.security.test.context.support.WithMockUser;
import org.springframework.test.context.bean.override.mockito.MockitoBean;
import org.springframework.test.web.servlet.MockMvc;

import static org.mockito.ArgumentMatchers.anyString;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.verifyNoInteractions;
import static org.mockito.Mockito.when;
import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.multipart;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.jsonPath;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

@SpringBootTest
@AutoConfigureMockMvc
class UsuarioImportacionSeguridadTest {

    @Autowired
    private MockMvc mockMvc;

    @MockitoBean
    private UsuarioImportacionService service;

    private MockMultipartFile archivo() {
        return new MockMultipartFile(
                "archivo",
                "usuarios.csv",
                "text/csv",
                ("ci,nombre,apellido,fecha_nacimiento,correo,telefono_1,"
                        + "telefono_2,direccion,rol,especialidades\n")
                        .getBytes(StandardCharsets.UTF_8)
        );
    }

    @Test
    void previsualizarSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(multipart("/api/usuarios/importaciones/previsualizar")
                        .file(archivo()))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    void confirmarSinAutenticacionDevuelve401() throws Exception {
        mockMvc.perform(multipart("/api/usuarios/importaciones/confirmar")
                        .file(archivo()))
                .andExpect(status().isUnauthorized());

        verifyNoInteractions(service);
    }

    @Test
    @WithMockUser(roles = "SOCIO")
    void socioNoPuedePrevisualizar() throws Exception {
        mockMvc.perform(multipart("/api/usuarios/importaciones/previsualizar")
                        .file(archivo()))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    @WithMockUser(roles = "MEDICO")
    void medicoNoPuedeConfirmar() throws Exception {
        mockMvc.perform(multipart("/api/usuarios/importaciones/confirmar")
                        .file(archivo()))
                .andExpect(status().isForbidden());

        verifyNoInteractions(service);
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorPuedePrevisualizar() throws Exception {
        when(service.previsualizar(anyString())).thenReturn(
                new PrevisualizacionUsuarios(0, 0, 0, List.of(), List.of())
        );

        mockMvc.perform(multipart("/api/usuarios/importaciones/previsualizar")
                        .file(archivo()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.total").value(0));

        verify(service).previsualizar(anyString());
    }

    @Test
    @WithMockUser(roles = "ADMINISTRADOR")
    void administradorPuedeConfirmar() throws Exception {
        when(service.confirmar(anyString())).thenReturn(
                new ResultadoImportacionUsuarios(0, 0, 0, List.of(), List.of())
        );

        mockMvc.perform(multipart("/api/usuarios/importaciones/confirmar")
                        .file(archivo()))
                .andExpect(status().isOk())
                .andExpect(jsonPath("$.importadas").value(0));

        verify(service).confirmar(anyString());
    }
}
