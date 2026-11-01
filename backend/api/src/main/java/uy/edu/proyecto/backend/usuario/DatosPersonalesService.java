package uy.edu.proyecto.backend.usuario;

import java.security.SecureRandom;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.regex.Pattern;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.auth.TokenHash;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.DatosPersonalesRepository.ContactoCuenta;

/**
 * RF-06: edicion de los datos personales permitidos (direccion, telefonos y
 * correo). La identidad sale siempre del JWT. Direccion y telefonos aplican de
 * inmediato; el correo se aplica recien cuando el usuario confirma desde el
 * enlace enviado al correo NUEVO (tabla enlace_cuenta, tipo CAMBIO_CORREO).
 * CI, nombre, apellido, fecha de nacimiento, rol y estado no se tocan: los
 * corrige el Administrador (RF-38).
 */
@Service
public class DatosPersonalesService {

    private static final int TOKEN_BYTES = 32;
    private static final int MAX_CORREO = 254;
    private static final int MAX_TELEFONO = 30;
    private static final Pattern FORMATO_CORREO =
            Pattern.compile("^[^@\\s]+@[^@\\s]+\\.[^@\\s]+$");
    private static final String MENSAJE_ENLACE_INVALIDO =
            "El enlace ya no es válido. Pedí uno nuevo desde tu perfil.";

    private final DatosPersonalesRepository repository;
    private final ApplicationEventPublisher eventPublisher;
    private final int tokenValidityHours;
    private final SecureRandom secureRandom = new SecureRandom();

    public DatosPersonalesService(
            DatosPersonalesRepository repository,
            ApplicationEventPublisher eventPublisher,
            @Value("${app.auth.email-change-token-validity-hours:24}")
            int tokenValidityHours
    ) {
        if (tokenValidityHours <= 0) {
            throw new IllegalArgumentException("La validez del enlace debe ser positiva");
        }
        this.repository = repository;
        this.eventPublisher = eventPublisher;
        this.tokenValidityHours = tokenValidityHours;
    }

    @Transactional(readOnly = true)
    public DatosPersonalesResponse obtener(Long idCuenta) {
        DatosPersonalesResponse datos = repository.buscarDatos(idCuenta)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "NO_ENCONTRADO",
                        "No se encontró la cuenta"
                ));
        String correoPendiente = repository
                .buscarCorreoPendiente(idCuenta)
                .orElse(null);
        return new DatosPersonalesResponse(
                datos.ci(),
                datos.nombre(),
                datos.apellido(),
                datos.rol(),
                datos.correo(),
                correoPendiente,
                datos.telefono1(),
                datos.telefono2(),
                datos.direccion()
        );
    }

    @Transactional
    public DatosPersonalesResponse actualizar(
            Long idCuenta,
            ActualizarDatosPersonalesRequest request
    ) {
        validar(request);

        ContactoCuenta actual = repository.bloquearCuentaHabilitada(idCuenta)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.UNAUTHORIZED,
                        "NO_AUTENTICADO",
                        "La sesion no es valida"
                ));

        String direccion = request.direccion() != null
                ? request.direccion().trim()
                : actual.direccion();
        String telefono1 = request.telefono1() != null
                ? request.telefono1().trim()
                : actual.telefono1();
        // telefono2 es el unico campo anulable: "" lo borra, ausente lo conserva.
        String telefono2 = request.telefono2() != null
                ? normalizarOpcional(request.telefono2())
                : actual.telefono2();

        repository.actualizarContacto(idCuenta, direccion, telefono1, telefono2);

        if (request.correo() != null) {
            String correoNuevo = request.correo().trim();
            if (!correoNuevo.equalsIgnoreCase(actual.correo())) {
                repository.invalidarEnlacesCambioCorreo(idCuenta);
                String token = generarToken();
                repository.crearEnlaceCambioCorreo(
                        idCuenta,
                        TokenHash.sha256(token),
                        correoNuevo,
                        OffsetDateTime.now(ZoneOffset.UTC)
                                .plusHours(tokenValidityHours)
                );
                String nombre = repository.buscarDatos(idCuenta)
                        .map(DatosPersonalesResponse::nombre)
                        .orElse("");
                eventPublisher.publishEvent(new CambioCorreoSolicitado(
                        idCuenta,
                        correoNuevo,
                        nombre,
                        token,
                        tokenValidityHours
                ));
            }
        }

        return obtener(idCuenta);
    }

    @Transactional
    public void confirmarCambioCorreo(ConfirmarCambioCorreoRequest request) {
        if (request == null || request.token() == null
                || request.token().isBlank()) {
            throw validacion("Falta un campo obligatorio");
        }

        repository.confirmarCambioCorreo(TokenHash.sha256(request.token()))
                .orElseThrow(() -> new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "ENLACE_INVALIDO",
                        MENSAJE_ENLACE_INVALIDO
                ));
    }

    private void validar(ActualizarDatosPersonalesRequest request) {
        if (request == null
                || (request.direccion() == null
                    && request.telefono1() == null
                    && request.telefono2() == null
                    && request.correo() == null)) {
            throw validacion("No hay ningún dato para actualizar");
        }
        if (request.direccion() != null && request.direccion().isBlank()) {
            throw validacion("La dirección no puede quedar vacía");
        }
        if (request.telefono1() != null
                && (request.telefono1().isBlank()
                    || request.telefono1().trim().length() > MAX_TELEFONO)) {
            throw validacion("El teléfono debe tener entre 1 y 30 caracteres");
        }
        if (request.telefono2() != null
                && request.telefono2().trim().length() > MAX_TELEFONO) {
            throw validacion("El teléfono debe tener entre 1 y 30 caracteres");
        }
        if (request.correo() != null) {
            String correo = request.correo().trim();
            if (correo.length() > MAX_CORREO
                    || !FORMATO_CORREO.matcher(correo).matches()) {
                throw validacion("El correo no tiene un formato válido");
            }
        }
    }

    private String generarToken() {
        byte[] bytes = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(bytes);
    }

    private String normalizarOpcional(String valor) {
        if (valor == null || valor.isBlank()) {
            return null;
        }
        return valor.trim();
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
