package uy.edu.proyecto.backend.auth;

import java.security.SecureRandom;
import java.nio.charset.StandardCharsets;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Base64;
import java.util.Set;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.http.HttpStatus;
import org.springframework.security.crypto.password.PasswordEncoder;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.auth.PrimerIngresoRepository.CuentaPendiente;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CiUruguaya;

@Service
public class PrimerIngresoService {

    private static final String MENSAJE_SOLICITUD =
            "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.";
    private static final String MENSAJE_ENLACE_INVALIDO =
            "El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.";
    private static final Set<String> ACCESOS = Set.of("SOCIO", "EMPLEADO");
    private static final int TOKEN_BYTES = 32;
    private static final int MAX_BCRYPT_PASSWORD_BYTES = 72;

    private final PrimerIngresoRepository repository;
    private final PasswordEncoder passwordEncoder;
    private final ApplicationEventPublisher eventPublisher;
    private final int minimumPasswordLength;
    private final int tokenValidityHours;
    private final SecureRandom secureRandom = new SecureRandom();

    public PrimerIngresoService(
            PrimerIngresoRepository repository,
            PasswordEncoder passwordEncoder,
            ApplicationEventPublisher eventPublisher,
            @Value("${app.auth.password-min-length:8}") int minimumPasswordLength,
            @Value("${app.auth.first-login-token-validity-hours:24}") int tokenValidityHours
    ) {
        if (tokenValidityHours <= 0) {
            throw new IllegalArgumentException("La validez del enlace debe ser positiva");
        }
        this.repository = repository;
        this.passwordEncoder = passwordEncoder;
        this.eventPublisher = eventPublisher;
        this.minimumPasswordLength = minimumPasswordLength;
        this.tokenValidityHours = tokenValidityHours;
    }

    @Transactional
    public SolicitudPrimerIngresoResponse solicitar(
            SolicitarPrimerIngresoRequest request
    ) {
        validarSolicitud(request);

        String ci = CiUruguaya.normalizarValida(request.ci())
                .orElseThrow(() -> validacion("La CI no es valida"));
        String acceso = request.acceso().trim();

        var cuentaPendiente = repository.buscarCuentaPendiente(ci, acceso);
        if (cuentaPendiente.isPresent()) {
            var cuenta = cuentaPendiente.get();
            repository.invalidarEnlacesPendientes(cuenta.id());
            String token = generarToken();
            repository.crearEnlace(
                    cuenta.id(),
                    TokenHash.sha256(token),
                    OffsetDateTime.now(ZoneOffset.UTC).plusHours(tokenValidityHours)
            );
            eventPublisher.publishEvent(new PrimerIngresoLinkSolicitado(
                    cuenta.id(),
                    cuenta.correo(),
                    cuenta.nombre(),
                    token,
                    tokenValidityHours
            ));
        } else {
            repository.buscarCuentaActiva(ci, acceso)
                    .ifPresent(cuenta -> eventPublisher.publishEvent(
                            new CuentaActivaPrimerIngresoSolicitada(
                                    cuenta.id(),
                                    cuenta.correo(),
                                    cuenta.nombre()
                            )
                    ));
        }

        return new SolicitudPrimerIngresoResponse(MENSAJE_SOLICITUD);
    }

    @Transactional
    public CuentaActivadaResponse completar(
            CompletarPrimerIngresoRequest request
    ) {
        validarActivacion(request);

        String direccion = request.direccion().trim();
        String telefono1 = request.telefono1().trim();
        String telefono2 = normalizarOpcional(request.telefono2());
        String passwordHash = passwordEncoder.encode(request.password());

        return repository.activarConEnlace(
                        TokenHash.sha256(request.token()),
                        direccion,
                        telefono1,
                        telefono2,
                        passwordHash
                )
                .orElseThrow(this::enlaceInvalido);
    }

    private void validarSolicitud(SolicitarPrimerIngresoRequest request) {
        if (request == null
                || estaVacio(request.ci())
                || estaVacio(request.acceso())) {
            throw validacion("Falta un campo obligatorio");
        }
        if (!ACCESOS.contains(request.acceso().trim())) {
            throw validacion("El acceso debe ser SOCIO o EMPLEADO");
        }
    }

    private void validarActivacion(CompletarPrimerIngresoRequest request) {
        if (request == null
                || estaVacio(request.token())
                || estaVacio(request.direccion())
                || estaVacio(request.telefono1())
                || estaVacio(request.password())) {
            throw validacion("Falta un campo obligatorio");
        }
        if (request.telefono1().trim().length() > 30
                || (request.telefono2() != null
                    && request.telefono2().trim().length() > 30)
                || request.password().length() < minimumPasswordLength
                || request.password().getBytes(StandardCharsets.UTF_8).length
                    > MAX_BCRYPT_PASSWORD_BYTES) {
            throw validacion("Los datos de activacion no son validos");
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

    private boolean estaVacio(String valor) {
        return valor == null || valor.isBlank();
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }

    private ApiException enlaceInvalido() {
        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "ENLACE_INVALIDO",
                MENSAJE_ENLACE_INVALIDO
        );
    }
}
