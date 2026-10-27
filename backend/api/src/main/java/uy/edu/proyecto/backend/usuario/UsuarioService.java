package uy.edu.proyecto.backend.usuario;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class UsuarioService {

    private final UsuarioPadronRepository repository;

    public UsuarioService(UsuarioPadronRepository repository) {
        this.repository = repository;
    }

    public UsuarioCuentaPageResponse listar(
            String rol,
            String estado,
            String texto,
            int page,
            int size
    ) {
        return listar(rol, estado, texto, null, null, page, size);
    }

    public UsuarioCuentaPageResponse listar(
            String rol,
            String estado,
            String texto,
            String orden,
            String sentido,
            int page,
            int size
    ) {
        String campo = orden == null || orden.isBlank() ? "apellido" : orden.trim();
        if (!"apellido".equals(campo) && !"fechaAlta".equals(campo)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "orden debe ser apellido o fechaAlta");
        }
        String direccion = sentido == null || sentido.isBlank()
                ? "asc" : sentido.trim().toLowerCase(java.util.Locale.ROOT);
        if (!"asc".equals(direccion) && !"desc".equals(direccion)) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "sentido debe ser asc o desc");
        }
        if (page < 0) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "page debe ser mayor o igual a 0"
            );
        }
        if (size <= 0 || size > 100) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "size debe estar entre 1 y 100"
            );
        }

        String rolNormalizado = rol == null || rol.isBlank() ? null : rol.trim().toUpperCase();
        if (rolNormalizado != null && !rolNormalizado.matches("SOCIO|FUNCIONARIO|MEDICO|ADMINISTRADOR")) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "ROL_INVALIDO",
                    "El rol solicitado no es válido"
            );
        }

        String estadoNormalizado = estado == null || estado.isBlank() ? null : estado.trim().toUpperCase();
        if (estadoNormalizado != null && !estadoNormalizado.matches("ACTIVA|INACTIVA")) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "ESTADO_INVALIDO",
                    "El estado solicitado no es válido"
            );
        }

        return repository.listar(rolNormalizado, estadoNormalizado, texto,
                campo, direccion, page, size);
    }
}
