package uy.edu.proyecto.backend.security;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.dao.DataAccessException;
import org.springframework.security.oauth2.core.OAuth2Error;
import org.springframework.security.oauth2.core.OAuth2TokenValidator;
import org.springframework.security.oauth2.core.OAuth2TokenValidatorResult;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.stereotype.Component;

import uy.edu.proyecto.backend.auth.CuentaAuthRepository;
import uy.edu.proyecto.backend.auth.CuentaAuthRepository.Vigencia;

/**
 * Comprueba en cada solicitud que la cuenta del JWT exista, siga habilitada y conserve el rol
 * del token. Un JWT emitido en o antes de la ultima reactivacion de la cuenta se rechaza, de modo
 * que reactivar una cuenta no revive los tokens previos a su inactivacion. Si la base no responde
 * se rechaza (nunca se omite la comprobacion).
 */
@Component
public class CuentaVigenteValidator implements OAuth2TokenValidator<Jwt> {

    private static final Logger LOG = LoggerFactory.getLogger(CuentaVigenteValidator.class);

    private final CuentaAuthRepository repository;

    public CuentaVigenteValidator(CuentaAuthRepository repository) {
        this.repository = repository;
    }

    @Override
    public OAuth2TokenValidatorResult validate(Jwt jwt) {
        long idCuenta;
        try {
            idCuenta = Long.parseLong(jwt.getSubject());
        } catch (NumberFormatException e) {
            return rechazo("Identidad de cuenta invalida");
        }

        Vigencia vigencia;
        try {
            vigencia = repository.buscarVigencia(idCuenta).orElse(null);
        } catch (DataAccessException e) {
            LOG.error("No se pudo verificar la cuenta del token; se rechaza la solicitud", e);
            return rechazo("No fue posible verificar la cuenta");
        }

        if (vigencia == null
                || !vigencia.habilitada()
                || !vigencia.primerIngresoCompletado()) {
            return rechazo("La cuenta no esta habilitada");
        }
        if (!vigencia.rol().equals(jwt.getClaimAsString("role"))) {
            return rechazo("El rol del token ya no coincide con la cuenta");
        }
        if (jwt.getIssuedAt() == null) {
            return rechazo("El token no informa su fecha de emision");
        }
        if (vigencia.reactivadaEn() != null
                && !jwt.getIssuedAt().isAfter(vigencia.reactivadaEn().toInstant())) {
            return rechazo("El token fue emitido antes de la ultima reactivacion de la cuenta");
        }
        return OAuth2TokenValidatorResult.success();
    }

    private static OAuth2TokenValidatorResult rechazo(String descripcion) {
        return OAuth2TokenValidatorResult.failure(
                new OAuth2Error("invalid_token", descripcion, null));
    }
}
