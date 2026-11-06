package uy.edu.proyecto.backend.usuario;

import java.time.LocalDate;
import java.time.format.DateTimeParseException;
import java.util.ArrayList;
import java.util.Iterator;
import java.util.List;
import java.util.Set;
import java.util.TreeSet;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import tools.jackson.databind.JsonNode;

import uy.edu.proyecto.backend.exception.ApiErrorResponse;
import uy.edu.proyecto.backend.exception.ApiException;

/**
 * Correccion administrativa de datos de una cuenta (RF-38). Acceso exclusivo
 * del rol ADMINISTRADOR (SecurityConfig). Solo se aceptan los campos
 * corregibles; cualquier otro (rol, estado, habilitada, id, ...) se rechaza
 * con 400 VALIDACION: el rol de la cuenta nunca se modifica.
 */
@RestController
@RequestMapping("/api/usuarios")
public class CorreccionUsuarioController {

    private static final Set<String> CAMPOS_CORREGIBLES = Set.of(
            "ci", "nombre", "apellido", "fechaNacimiento", "correo",
            "telefono1", "telefono2", "direccion", "especialidadIds"
    );

    private final CorreccionUsuarioService service;

    public CorreccionUsuarioController(CorreccionUsuarioService service) {
        this.service = service;
    }

    @GetMapping("/{id}")
    public CorreccionUsuarioResponse obtener(@PathVariable long id) {
        return service.obtener(id);
    }

    @PatchMapping("/{id}")
    public CorreccionUsuarioResponse corregir(
            @PathVariable long id,
            @RequestBody JsonNode cuerpo
    ) {
        return service.corregir(id, parsear(cuerpo));
    }

    private static CorreccionUsuarioRequest parsear(JsonNode cuerpo) {
        if (cuerpo == null || !cuerpo.isObject()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El cuerpo de la solicitud tiene un formato inválido"
            );
        }
        Set<String> rechazados = new TreeSet<>();
        Iterator<String> campos = cuerpo.propertyNames().iterator();
        while (campos.hasNext()) {
            String campo = campos.next();
            if (!CAMPOS_CORREGIBLES.contains(campo)) {
                rechazados.add(campo);
            }
        }
        if (!rechazados.isEmpty()) {
            String mensaje = "Campos no permitidos: "
                    + String.join(", ", rechazados)
                    + ". Solo se pueden corregir " + String.join(", ", CAMPOS_CORREGIBLES)
                    + ".";
            if (rechazados.contains("rol")) {
                mensaje += " El rol de la cuenta no se modifica.";
            }
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
        }
        return new CorreccionUsuarioRequest(
                texto(cuerpo, "ci"),
                texto(cuerpo, "nombre"),
                texto(cuerpo, "apellido"),
                fecha(cuerpo),
                texto(cuerpo, "correo"),
                texto(cuerpo, "telefono1"),
                texto(cuerpo, "telefono2"),
                texto(cuerpo, "direccion"),
                especialidadIds(cuerpo)
        );
    }

    /** Ausente devuelve null (no se toca); null explicito devuelve "" (borra). */
    private static String texto(JsonNode cuerpo, String campo) {
        JsonNode nodo = cuerpo.get(campo);
        if (nodo == null) {
            return null;
        }
        if (nodo.isNull()) {
            return "";
        }
        if (!nodo.isTextual()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El campo " + campo + " debe ser texto"
            );
        }
        return nodo.asString();
    }

    private static LocalDate fecha(JsonNode cuerpo) {
        String valor = texto(cuerpo, "fechaNacimiento");
        if (valor == null) {
            return null;
        }
        try {
            return LocalDate.parse(valor.trim());
        } catch (DateTimeParseException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El campo fechaNacimiento debe tener formato aaaa-mm-dd"
            );
        }
    }

    private static List<Long> especialidadIds(JsonNode cuerpo) {
        JsonNode nodo = cuerpo.get("especialidadIds");
        if (nodo == null) {
            return null;
        }
        if (!nodo.isArray()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "El campo especialidadIds debe ser un arreglo de enteros"
            );
        }
        List<Long> ids = new ArrayList<>();
        for (JsonNode elemento : nodo) {
            if (!elemento.isIntegralNumber()) {
                throw new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "VALIDACION",
                        "El campo especialidadIds debe ser un arreglo de enteros"
                );
            }
            ids.add(elemento.asLong());
        }
        return ids;
    }

    @ExceptionHandler(HttpMessageNotReadableException.class)
    public ResponseEntity<ApiErrorResponse> solicitudMalFormada() {
        return ResponseEntity
                .badRequest()
                .body(new ApiErrorResponse(
                        "VALIDACION",
                        "El cuerpo de la solicitud tiene un formato inválido"
                ));
    }
}
