package uy.edu.proyecto.backend.security;

import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.time.Instant;
import java.time.OffsetDateTime;
import java.time.ZoneOffset;
import java.util.Optional;

import org.junit.jupiter.api.Test;
import org.springframework.dao.DataAccessResourceFailureException;
import org.springframework.security.oauth2.jwt.Jwt;

import uy.edu.proyecto.backend.auth.CuentaAuthRepository;
import uy.edu.proyecto.backend.auth.CuentaAuthRepository.Vigencia;

class CuentaVigenteValidatorTest {

    private static final Instant EMISION = Instant.parse("2026-03-10T12:00:00Z");

    private final CuentaAuthRepository repository = mock(CuentaAuthRepository.class);
    private final CuentaVigenteValidator validator = new CuentaVigenteValidator(repository);

    private static Jwt jwt(String sub, String rol, Instant emitido) {
        Jwt.Builder b = Jwt.withTokenValue("t").header("alg", "HS256").subject(sub)
                .claim("role", rol).expiresAt(EMISION.plusSeconds(900));
        if (emitido != null) {
            b.issuedAt(emitido);
        }
        return b.build();
    }

    private static Vigencia vigencia(String rol, boolean habilitada, Instant reactivada) {
        return new Vigencia(rol, habilitada, true,
                reactivada == null ? null : OffsetDateTime.ofInstant(reactivada, ZoneOffset.UTC));
    }

    @Test
    void cuentaHabilitadaYRolCoincidenteSeAcepta() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(vigencia("MEDICO", true, null)));
        assertFalse(validator.validate(jwt("7", "MEDICO", EMISION)).hasErrors());
    }

    @Test
    void cuentaInhabilitadaSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(vigencia("MEDICO", false, null)));
        assertTrue(validator.validate(jwt("7", "MEDICO", EMISION)).hasErrors());
    }

    @Test
    void cuentaInexistenteSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.empty());
        assertTrue(validator.validate(jwt("7", "MEDICO", EMISION)).hasErrors());
    }

    @Test
    void cuentaSinPrimerIngresoSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(
                new Vigencia("SOCIO", true, false, null)));
        assertTrue(validator.validate(jwt("7", "SOCIO", EMISION)).hasErrors());
    }

    @Test
    void rolDelTokenDistintoAlDeLaCuentaSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(vigencia("SOCIO", true, null)));
        assertTrue(validator.validate(jwt("7", "ADMINISTRADOR", EMISION)).hasErrors());
    }

    @Test
    void subjectNoNumericoSeRechazaSinConsultarLaBase() {
        assertTrue(validator.validate(jwt("abc", "SOCIO", EMISION)).hasErrors());
    }

    @Test
    void tokenSinFechaDeEmisionSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(vigencia("SOCIO", true, null)));
        assertTrue(validator.validate(jwt("7", "SOCIO", null)).hasErrors());
    }

    @Test
    void tokenEmitidoAntesDeLaReactivacionSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(
                vigencia("SOCIO", true, EMISION.plusSeconds(60))));
        assertTrue(validator.validate(jwt("7", "SOCIO", EMISION)).hasErrors());
    }

    @Test
    void tokenEmitidoEnElMismoSegundoDeLaReactivacionSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(vigencia("SOCIO", true, EMISION)));
        assertTrue(validator.validate(jwt("7", "SOCIO", EMISION)).hasErrors());
    }

    @Test
    void tokenEmitidoDespuesDeLaReactivacionSeAcepta() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(
                vigencia("SOCIO", true, EMISION.minusSeconds(5))));
        assertFalse(validator.validate(jwt("7", "SOCIO", EMISION)).hasErrors());
    }

    @Test
    void tokenNuevoDentroDelMismoSegundoDeLaReactivacionSeAcepta() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(
                vigencia("SOCIO", true, EMISION.plusMillis(100))));
        Jwt jwt = Jwt.withTokenValue("t").header("alg", "HS256").subject("7")
                .claim("role", "SOCIO")
                .claim("issued_at_precise", EMISION.plusMillis(500).toString())
                .issuedAt(EMISION).expiresAt(EMISION.plusSeconds(900)).build();
        assertFalse(validator.validate(jwt).hasErrors());
    }

    @Test
    void tokenAnteriorDentroDelMismoSegundoDeLaReactivacionSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(
                vigencia("SOCIO", true, EMISION.plusMillis(500))));
        Jwt jwt = Jwt.withTokenValue("t").header("alg", "HS256").subject("7")
                .claim("role", "SOCIO")
                .claim("issued_at_precise", EMISION.plusMillis(100).toString())
                .issuedAt(EMISION).expiresAt(EMISION.plusSeconds(900)).build();
        assertTrue(validator.validate(jwt).hasErrors());
    }

    @Test
    void fechaPrecisaMalformadaSeRechaza() {
        when(repository.buscarVigencia(7)).thenReturn(Optional.of(
                vigencia("SOCIO", true, EMISION.minusSeconds(3))));
        Jwt jwt = Jwt.withTokenValue("t").header("alg", "HS256").subject("7")
                .claim("role", "SOCIO").claim("issued_at_precise", "invalido")
                .issuedAt(EMISION).expiresAt(EMISION.plusSeconds(900)).build();
        assertTrue(validator.validate(jwt).hasErrors());
    }

    @Test
    void falloDeBaseDeDatosRechazaSinOmitirLaComprobacion() {
        when(repository.buscarVigencia(7))
                .thenThrow(new DataAccessResourceFailureException("base caida"));
        assertTrue(validator.validate(jwt("7", "SOCIO", EMISION)).hasErrors());
    }
}
