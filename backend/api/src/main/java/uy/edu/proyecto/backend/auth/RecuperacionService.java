package uy.edu.proyecto.backend.auth;

import java.nio.charset.StandardCharsets;
import java.security.SecureRandom;
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

import uy.edu.proyecto.backend.auth.RecuperacionRepository.CuentaRecuperacion;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CiUruguaya;

/**
 * RF-05: recuperacion de contrasena. Replica el patron de seguridad del
 * primer ingreso (RF-02): respuesta publica identica exista o no la cuenta,
 * token aleatorio de 256 bits del que solo se guarda el hash SHA-256,
 * vencimiento a las 24 horas, un solo uso, y el correo sale despues del
 * commit en segundo plano. Los enlaces de recuperacion nunca se mezclan con
 * los de primer ingreso o cambio de correo (columna tipo de enlace_cuenta).
 *
 * Decisiones documentadas (el RF no las fija):
 * - Anti-abuso: si la cuenta ya tiene un enlace vigente creado hace menos de
 *   ANTI_REENVIO_SEGUNDOS, no se genera ni envia otro; la respuesta es la
 *   misma. Asi un pedido repetido no bombardea el correo ni invalida el
 *   enlace que ya viaja.
 * - Al completar la recuperacion se revocan TODAS las sesiones de la cuenta:
 *   la contrasena anterior pudo estar comprometida.
 * - Una cuenta inactivada no recibe correo ni puede completar el enlace
 *   (mismo criterio que RF-02).
 */
@Service
public class RecuperacionService {

    private static final String MENSAJE_SOLICITUD =
            "Si su cédula se encuentra registrada, se le ha enviado un correo electrónico con las instrucciones.";
    private static final String MENSAJE_ENLACE_INVALIDO =
            "El enlace ya no es válido. Pedí uno nuevo desde la pantalla de ingreso.";
    private static final Set<String> ACCESOS = Set.of("SOCIO", "EMPLEADO");
    private static final int TOKEN_BYTES = 32;
    private static final int MAX_BCRYPT_PASSWORD_BYTES = 72;
    private static final long ANTI_REENVIO_SEGUNDOS = 60;

    private final RecuperacionRepository repository;
    private final SesionRepository sesionRepository;
    private final PasswordEncoder passwordEncoder;
    private final ApplicationEventPublisher eventPublisher;
    private final int minimumPasswordLength;
    private final int tokenValidityHours;
    private final SecureRandom secureRandom = new SecureRandom();

    public RecuperacionService(
            RecuperacionRepository repository,
            SesionRepository sesionRepository,
            PasswordEncoder passwordEncoder,
            ApplicationEventPublisher eventPublisher,
            @Value("${app.auth.password-min-length:8}") int minimumPasswordLength,
            @Value("${app.auth.recovery-token-validity-hours:24}")
            int tokenValidityHours
    ) {
        if (tokenValidityHours <= 0) {
            throw new IllegalArgumentException("La validez del enlace debe ser positiva");
        }
        this.repository = repository;
        this.sesionRepository = sesionRepository;
        this.passwordEncoder = passwordEncoder;
        this.eventPublisher = eventPublisher;
        this.minimumPasswordLength = minimumPasswordLength;
        this.tokenValidityHours = tokenValidityHours;
    }

    @Transactional
    public SolicitudPrimerIngresoResponse solicitar(
            SolicitarRecuperacionRequest request
    ) {
        validarSolicitud(request);

        String ci = CiUruguaya.normalizarValida(request.ci())
                .orElseThrow(() -> validacion("La CI no es valida"));
        String acceso = request.acceso().trim();

        var cuentaActiva = repository.buscarCuentaActiva(ci, acceso);
        if (cuentaActiva.isPresent()) {
            generarEnlaceSiCorresponde(cuentaActiva.get());
        } else {
            // RF-05: si la CI figura pero no activo su cuenta, el correo
            // le indica que use "Es mi primera vez".
            repository.buscarCuentaPendiente(ci, acceso)
                    .ifPresent(cuenta -> eventPublisher.publishEvent(
                            new CuentaPendienteRecuperacionSolicitada(
                                    cuenta.id(),
                                    cuenta.correo(),
                                    cuenta.nombre()
                            )
                    ));
        }

        return new SolicitudPrimerIngresoResponse(MENSAJE_SOLICITUD);
    }

    @Transactional
    public void completar(CompletarRecuperacionRequest request) {
        validarActivacion(request);

        Long idCuenta = repository.completarConEnlace(
                        TokenHash.sha256(request.token()),
                        passwordEncoder.encode(request.password())
                )
                .orElseThrow(this::enlaceInvalido);

        // La contrasena anterior pudo estar comprometida: se cierran todas
        // las sesiones de la cuenta.
        sesionRepository.revocarOtrasSesiones(idCuenta, null);
    }

    private void generarEnlaceSiCorresponde(CuentaRecuperacion cuenta) {
        var ultimoEnlace = repository.ultimoEnlaceVigenteCreadoEn(cuenta.id());
        if (ultimoEnlace.isPresent()
                && ultimoEnlace.get().isAfter(
                        OffsetDateTime.now(ZoneOffset.UTC)
                                .minusSeconds(ANTI_REENVIO_SEGUNDOS))) {
            return;
        }

        repository.invalidarEnlacesPendientes(cuenta.id());
        String token = generarToken();
        repository.crearEnlace(
                cuenta.id(),
                TokenHash.sha256(token),
                OffsetDateTime.now(ZoneOffset.UTC).plusHours(tokenValidityHours)
        );
        eventPublisher.publishEvent(new RecuperacionLinkSolicitado(
                cuenta.id(),
                cuenta.correo(),
                cuenta.nombre(),
                token,
                tokenValidityHours
        ));
    }

    private void validarSolicitud(SolicitarRecuperacionRequest request) {
        if (request == null
                || estaVacio(request.ci())
                || estaVacio(request.acceso())) {
            throw validacion("Falta un campo obligatorio");
        }
        if (!ACCESOS.contains(request.acceso().trim())) {
            throw validacion("El acceso debe ser SOCIO o EMPLEADO");
        }
    }

    private void validarActivacion(CompletarRecuperacionRequest request) {
        if (request == null
                || estaVacio(request.token())
                || estaVacio(request.password())) {
            throw validacion("Falta un campo obligatorio");
        }
        if (request.password().length() < minimumPasswordLength
                || request.password().getBytes(StandardCharsets.UTF_8).length
                    > MAX_BCRYPT_PASSWORD_BYTES) {
            throw validacion(
                    "La contrasena debe tener al menos "
                            + minimumPasswordLength + " caracteres"
            );
        }
    }

    private String generarToken() {
        byte[] bytes = new byte[TOKEN_BYTES];
        secureRandom.nextBytes(bytes);
        return Base64.getUrlEncoder()
                .withoutPadding()
                .encodeToString(bytes);
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
