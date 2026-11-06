package uy.edu.proyecto.backend.usuario;

import java.time.Clock;
import java.time.LocalDate;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.regex.Pattern;

import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CuentaRepository.CuentaCompleta;

/**
 * Correccion administrativa de datos de una cuenta (RF-38). CI, nombre,
 * apellido y fecha de nacimiento son de la persona: la correccion vale para
 * todas sus cuentas. Correo, telefonos y direccion son de la cuenta. Las
 * especialidades solo se corrigen en cuentas de medico y no se quita una
 * especialidad con turnos vigentes o consultas agendadas futuras. El rol
 * nunca se modifica (lo rechaza el controlador). Todo se aplica en una unica
 * transaccion; las consultas e historias clinicas ya registradas conservan
 * su estado y contenido.
 */
@Service
public class CorreccionUsuarioService {

    private static final Pattern CORREO = Pattern.compile(
            "^[^\\s@]+@[^\\s@]+\\.[^\\s@]+$"
    );

    private final CuentaRepository repository;
    private final Clock clock;

    public CorreccionUsuarioService(CuentaRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public CorreccionUsuarioResponse obtener(long idCuenta) {
        CuentaCompleta actual = repository.buscarCuentaCompleta(idCuenta)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "USUARIO_NO_ENCONTRADO",
                        "No existe una cuenta con ese identificador"
                ));

        List<Long> especialidadIds = actual.rol().equals("MEDICO")
                ? repository.especialidadesDelMedico(idCuenta)
                : List.of();
        return new CorreccionUsuarioResponse(
                actual.id(),
                actual.ci(),
                actual.nombre(),
                actual.apellido(),
                actual.fechaNacimiento(),
                actual.rol(),
                actual.correo(),
                actual.telefono1(),
                actual.telefono2(),
                actual.direccion(),
                especialidadIds,
                actual.habilitada() ? "ACTIVA" : "INACTIVA",
                actual.primerIngresoCompletado()
        );
    }

    @Transactional
    public CorreccionUsuarioResponse corregir(
            long idCuenta,
            CorreccionUsuarioRequest request
    ) {
        if (request == null || request.sinCambios()) {
            throw validacion("Debe indicar al menos un campo a corregir");
        }

        CuentaCompleta actual = repository.bloquearCuentaCompleta(idCuenta)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "USUARIO_NO_ENCONTRADO",
                        "No existe una cuenta con ese identificador"
                ));

        String ciFinal = normalizarCi(request.ci(), actual.ci());
        String nombreFinal = normalizarObligatorio(
                request.nombre(), actual.nombre(), "nombre", 100);
        String apellidoFinal = normalizarObligatorio(
                request.apellido(), actual.apellido(), "apellido", 100);
        LocalDate fechaFinal = request.fechaNacimiento() == null
                ? actual.fechaNacimiento()
                : request.fechaNacimiento();
        String correoFinal = normalizarCorreo(request.correo(), actual.correo());
        String telefono1Final = normalizarObligatorio(
                request.telefono1(), actual.telefono1(), "telefono1", 30);
        String telefono2Final = normalizarOpcional(
                request.telefono2(), actual.telefono2(), "telefono2", 30);
        String direccionFinal = normalizarOpcional(
                request.direccion(), actual.direccion(), "direccion", null);
        if (actual.primerIngresoCompletado() && direccionFinal == null) {
            throw validacion("La dirección es obligatoria para una cuenta"
                    + " que ya completó el primer ingreso");
        }

        if (!ciFinal.equals(actual.ci()) && repository.existePersona(ciFinal)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "CI_EN_USO",
                    "Ya existe una persona registrada con esa CI"
            );
        }

        List<Long> especialidadesFinales = actual.rol().equals("MEDICO")
                ? repository.especialidadesDelMedico(idCuenta)
                : List.of();
        if (request.especialidadIds() != null) {
            especialidadesFinales = corregirEspecialidades(
                    actual, request.especialidadIds(), especialidadesFinales);
        }

        boolean cambiaPersona = request.ci() != null || request.nombre() != null
                || request.apellido() != null || request.fechaNacimiento() != null;
        if (cambiaPersona) {
            try {
                repository.actualizarPersona(
                        actual.ci(), ciFinal, nombreFinal, apellidoFinal, fechaFinal);
            } catch (DuplicateKeyException exception) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "CI_EN_USO",
                        "Ya existe una persona registrada con esa CI"
                );
            }
        }

        boolean cambiaContacto = request.correo() != null
                || request.telefono1() != null || request.telefono2() != null
                || request.direccion() != null;
        if (cambiaContacto) {
            repository.actualizarContactoCuenta(
                    idCuenta, correoFinal, telefono1Final, telefono2Final,
                    direccionFinal);
        }

        return new CorreccionUsuarioResponse(
                actual.id(),
                ciFinal,
                nombreFinal,
                apellidoFinal,
                fechaFinal,
                actual.rol(),
                correoFinal,
                telefono1Final,
                telefono2Final,
                direccionFinal,
                especialidadesFinales,
                actual.habilitada() ? "ACTIVA" : "INACTIVA",
                actual.primerIngresoCompletado()
        );
    }

    /**
     * Reemplaza el conjunto de especialidades del medico. No se quita una
     * especialidad con turnos vigentes o consultas agendadas cuyo dia todavia
     * no termino; las altas reutilizan la misma validacion de RF-31.
     */
    private List<Long> corregirEspecialidades(
            CuentaCompleta actual,
            List<Long> nuevas,
            List<Long> actuales
    ) {
        if (!actual.rol().equals("MEDICO")) {
            throw validacion("Las especialidades solo corresponden a medicos");
        }
        if (nuevas.isEmpty()) {
            throw validacion("Un medico requiere al menos una especialidad");
        }
        if (nuevas.stream().anyMatch(id -> id == null || id <= 0)) {
            throw validacion("Los identificadores de especialidad deben ser positivos");
        }
        List<Long> normalizadas = List.copyOf(new LinkedHashSet<>(nuevas));
        if (normalizadas.size() != nuevas.size()) {
            throw validacion("No se permiten especialidades repetidas");
        }
        if (repository.especialidadesExistentes(normalizadas).size()
                != normalizadas.size()) {
            throw validacion("Una o mas especialidades no existen");
        }

        LocalDate hoy = LocalDate.now(clock);
        for (Long quitada : actuales) {
            if (normalizadas.contains(quitada)) {
                continue;
            }
            if (repository.medicoTieneTurnosVigentesEnEspecialidad(
                    actual.id(), quitada, hoy)) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "ESPECIALIDAD_EN_USO",
                        "No se puede quitar la especialidad " + quitada
                                + " porque el médico tiene turnos vigentes en ella"
                );
            }
            if (repository.medicoTieneConsultasFuturasEnEspecialidad(
                    actual.id(), quitada, hoy)) {
                throw new ApiException(
                        HttpStatus.CONFLICT,
                        "ESPECIALIDAD_EN_USO",
                        "No se puede quitar la especialidad " + quitada
                                + " porque el médico tiene consultas agendadas"
                                + " pendientes en ella"
                );
            }
        }

        for (Long quitada : actuales) {
            if (!normalizadas.contains(quitada)) {
                repository.eliminarEspecialidadDelMedico(actual.id(), quitada);
            }
        }
        List<Long> agregadas = normalizadas.stream()
                .filter(id -> !actuales.contains(id))
                .toList();
        if (!agregadas.isEmpty()) {
            repository.asociarEspecialidades(actual.id(), agregadas);
        }
        return normalizadas;
    }

    private String normalizarCi(String ci, String ciActual) {
        if (ci == null) {
            return ciActual;
        }
        return CiUruguaya.normalizarValida(ci)
                .orElseThrow(() -> new ApiException(
                        HttpStatus.BAD_REQUEST,
                        "CI_INVALIDA",
                        "La CI no es valida"
                ));
    }

    private String normalizarObligatorio(
            String valor,
            String actual,
            String campo,
            int longitudMaxima
    ) {
        if (valor == null) {
            return actual;
        }
        String normalizado = valor.trim();
        if (normalizado.isBlank()) {
            throw validacion("El campo " + campo + " es obligatorio");
        }
        if (normalizado.length() > longitudMaxima) {
            throw validacion("El campo " + campo + " supera la longitud permitida");
        }
        return normalizado;
    }

    /** Ausente conserva; cadena vacia borra (solo datos opcionales). */
    private String normalizarOpcional(
            String valor,
            String actual,
            String campo,
            Integer longitudMaxima
    ) {
        if (valor == null) {
            return actual;
        }
        String normalizado = valor.trim();
        if (longitudMaxima != null && normalizado.length() > longitudMaxima) {
            throw validacion("El campo " + campo + " supera la longitud permitida");
        }
        return normalizado.isEmpty() ? null : normalizado;
    }

    private String normalizarCorreo(String correo, String actual) {
        if (correo == null) {
            return actual;
        }
        String normalizado = correo.trim().toLowerCase();
        if (normalizado.isBlank() || normalizado.length() > 254
                || !CORREO.matcher(normalizado).matches()) {
            throw validacion("El correo no tiene un formato valido");
        }
        return normalizado;
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
