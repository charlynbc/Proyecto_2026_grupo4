package uy.edu.proyecto.backend.usuario;

import java.util.Iterator;
import java.util.Set;
import java.util.TreeSet;

import org.springframework.http.HttpStatus;
import org.springframework.http.ResponseEntity;
import org.springframework.http.converter.HttpMessageNotReadableException;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.ExceptionHandler;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PatchMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

import tools.jackson.databind.JsonNode;

import uy.edu.proyecto.backend.exception.ApiErrorResponse;
import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/cuentas/me")
public class DatosPersonalesController {

    private static final Set<String> CAMPOS_EDITABLES =
            Set.of("direccion", "telefono1", "telefono2", "correo");

    private final DatosPersonalesService service;

    public DatosPersonalesController(DatosPersonalesService service) {
        this.service = service;
    }

    @GetMapping
    public DatosPersonalesResponse obtener(
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.obtener(idCuenta(jwt));
    }

    @PatchMapping
    public DatosPersonalesResponse actualizar(
            @RequestBody JsonNode cuerpo,
            @AuthenticationPrincipal Jwt jwt
    ) {
        return service.actualizar(idCuenta(jwt), parsear(cuerpo));
    }

    /**
     * Solo se aceptan los campos editables de RF-06. Cualquier otro (ci,
     * nombre, apellido, fechaNacimiento, rol, estado, id...) se rechaza con
     * 400 VALIDACION: esos solo los corrige el Administrador (RF-38).
     */
    private static ActualizarDatosPersonalesRequest parsear(JsonNode cuerpo) {
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
            if (!CAMPOS_EDITABLES.contains(campo)) {
                rechazados.add(campo);
            }
        }
        if (!rechazados.isEmpty()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "VALIDACION",
                    "Campos no permitidos: " + String.join(", ", rechazados)
                            + ". Solo se pueden actualizar direccion,"
                            + " telefono1, telefono2 y correo."
            );
        }
        return new ActualizarDatosPersonalesRequest(
                texto(cuerpo, "direccion"),
                texto(cuerpo, "telefono1"),
                texto(cuerpo, "telefono2"),
                texto(cuerpo, "correo")
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

    private static Long idCuenta(Jwt jwt) {
        try {
            return Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException | NullPointerException exception) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
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
