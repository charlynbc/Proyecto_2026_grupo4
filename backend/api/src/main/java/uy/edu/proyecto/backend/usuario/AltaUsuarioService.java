package uy.edu.proyecto.backend.usuario;

import java.util.LinkedHashSet;
import java.util.List;
import java.util.Set;
import java.util.regex.Pattern;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class AltaUsuarioService {

    private static final Set<String> ROLES = Set.of(
            "SOCIO",
            "MEDICO",
            "FUNCIONARIO",
            "ADMINISTRADOR"
    );
    private static final Pattern CORREO = Pattern.compile(
            "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
    );

    private final CuentaRepository repository;

    public AltaUsuarioService(CuentaRepository repository) {
        this.repository = repository;
    }

    @Transactional
    public CuentaCreadaResponse crear(AltaUsuarioRequest request) {
        validarSolicitud(request);

        String ci = CiUruguaya.normalizarValida(request.ci())
                .orElseThrow(() -> error(
                        HttpStatus.BAD_REQUEST,
                        "CI_INVALIDA",
                        "La CI no es valida"
                ));
        String nombre = request.nombre().trim();
        String apellido = request.apellido().trim();
        String rol = request.rol().trim();
        String correo = request.correo().trim().toLowerCase();
        String telefono1 = request.telefono1().trim();
        String telefono2 = normalizarOpcional(request.telefono2());
        String direccion = normalizarOpcional(request.direccion());
        List<Long> especialidadIds = normalizarEspecialidades(
                request.especialidadIds()
        );

        validarEspecialidades(rol, especialidadIds);

        repository.crearPersonaSiNoExiste(
                ci,
                nombre,
                apellido,
                request.fechaNacimiento()
        );

        CuentaRepository.PersonaRegistrada persona =
                repository.buscarPersonaParaActualizar(ci)
                        .orElseThrow(() -> new IllegalStateException(
                                "La persona no quedo disponible para el alta"
                        ));

        if (!coincideIdentidad(persona, nombre, apellido, request.fechaNacimiento())) {
            throw error(
                    HttpStatus.CONFLICT,
                    "DATOS_PERSONA_DISCORDANTES",
                    "La CI ya esta registrada con otros datos personales"
            );
        }

        if (rol.equals("SOCIO") && repository.existeCuentaSocio(ci)) {
            throw error(
                    HttpStatus.CONFLICT,
                    "SOCIO_DUPLICADO",
                    "La CI ya tiene una cuenta de socio"
            );
        }

        if (!rol.equals("SOCIO")
                && repository.existeCuentaEmpleadoHabilitada(ci)) {
            throw error(
                    HttpStatus.CONFLICT,
                    "EMPLEADO_DUPLICADO",
                    "La CI ya tiene una cuenta de empleado habilitada"
            );
        }

        Long id;
        try {
            id = repository.crearCuenta(
                    ci,
                    rol,
                    correo,
                    telefono1,
                    telefono2,
                    direccion
            );
        } catch (DuplicateKeyException exception) {
            throw error(
                    HttpStatus.CONFLICT,
                    rol.equals("SOCIO") ? "SOCIO_DUPLICADO" : "EMPLEADO_DUPLICADO",
                    rol.equals("SOCIO")
                            ? "La CI ya tiene una cuenta de socio"
                            : "La CI ya tiene una cuenta de empleado habilitada"
            );
        }

        if (rol.equals("MEDICO")) {
            repository.asociarEspecialidades(id, especialidadIds);
        }

        return new CuentaCreadaResponse(
                id,
                ci,
                nombre,
                apellido,
                rol,
                "ACTIVA",
                false
        );
    }

    private void validarSolicitud(AltaUsuarioRequest request) {
        if (request == null) {
            throw validacion("El cuerpo de la solicitud es obligatorio");
        }
        if (estaVacio(request.ci())
                || estaVacio(request.nombre())
                || estaVacio(request.apellido())
                || request.fechaNacimiento() == null
                || estaVacio(request.correo())
                || estaVacio(request.telefono1())
                || estaVacio(request.rol())) {
            throw validacion("Falta un campo obligatorio");
        }
        if (request.nombre().trim().length() > 100
                || request.apellido().trim().length() > 100
                || request.correo().trim().length() > 254
                || request.telefono1().trim().length() > 30
                || (request.telefono2() != null
                    && request.telefono2().trim().length() > 30)) {
            throw validacion("Un campo supera la longitud permitida");
        }
        if (!CORREO.matcher(request.correo().trim()).matches()) {
            throw validacion("El correo no tiene un formato valido");
        }
        if (!ROLES.contains(request.rol().trim())) {
            throw validacion("El rol indicado no es valido");
        }
    }

    private void validarEspecialidades(String rol, List<Long> ids) {
        if (rol.equals("MEDICO") && ids.isEmpty()) {
            throw validacion("Un medico requiere al menos una especialidad");
        }
        if (!rol.equals("MEDICO") && !ids.isEmpty()) {
            throw validacion("Las especialidades solo corresponden a medicos");
        }
        if (!ids.isEmpty()
                && repository.especialidadesExistentes(ids).size() != ids.size()) {
            throw validacion("Una o mas especialidades no existen");
        }
    }

    private List<Long> normalizarEspecialidades(List<Long> ids) {
        if (ids == null) {
            return List.of();
        }
        if (ids.stream().anyMatch(id -> id == null || id <= 0)) {
            throw validacion("Los identificadores de especialidad deben ser positivos");
        }
        List<Long> normalizados = List.copyOf(new LinkedHashSet<>(ids));
        if (normalizados.size() != ids.size()) {
            throw validacion("No se permiten especialidades repetidas");
        }
        return normalizados;
    }

    private boolean coincideIdentidad(
            CuentaRepository.PersonaRegistrada persona,
            String nombre,
            String apellido,
            java.time.LocalDate fechaNacimiento
    ) {
        return persona.nombre().equals(nombre)
                && persona.apellido().equals(apellido)
                && persona.fechaNacimiento().equals(fechaNacimiento);
    }

    private String normalizarOpcional(String valor) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        return valor.trim();
    }

    private boolean estaVacio(String valor) {
        return valor == null || valor.isBlank();
    }

    private ApiException validacion(String mensaje) {
        return error(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }

    private ApiException error(
            HttpStatus status,
            String codigo,
            String mensaje
    ) {
        return new ApiException(status, codigo, mensaje);
    }
}
