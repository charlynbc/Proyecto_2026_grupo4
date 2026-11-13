package uy.edu.proyecto.backend.usuario;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class UsuarioService {

    private final UsuarioPadronRepository repository;
    private final CuentaRepository cuentaRepository;
    private final Clock clock;

    public UsuarioService(
            UsuarioPadronRepository repository,
            CuentaRepository cuentaRepository,
            Clock clock
    ) {
        this.repository = repository;
        this.cuentaRepository = cuentaRepository;
        this.clock = clock;
    }

    public UsuarioCuentaPageResponse listar(
            long idAdministrador,
            String rol,
            String estado,
            String texto,
            int page,
            int size
    ) {
        return listar(idAdministrador, rol, estado, texto, null, null, page, size);
    }

    public UsuarioCuentaPageResponse listar(
            long idAdministrador,
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

        UsuarioCuentaPageResponse pagina = repository.listar(
                rolNormalizado, estadoNormalizado, texto, campo, direccion, page, size);
        return new UsuarioCuentaPageResponse(
                conPuedeInactivar(pagina.items(), idAdministrador),
                pagina.page(),
                pagina.size(),
                pagina.total()
        );
    }

    /**
     * Completa puedeInactivar de cada fila con la misma regla que usa
     * inactivar. La agenda de los medicos de la pagina se pide en lote: dos
     * consultas como maximo, sin importar cuantas filas haya.
     */
    private List<UsuarioCuentaDTO> conPuedeInactivar(
            List<UsuarioCuentaDTO> filas,
            long idAdministrador
    ) {
        Set<Long> idsMedico = filas.stream()
                .filter(fila -> "MEDICO".equals(fila.rol()))
                .map(UsuarioCuentaDTO::id)
                .collect(Collectors.toSet());
        LocalDate hoy = LocalDate.now(clock);
        Set<Long> conFechasActivas = idsMedico.isEmpty()
                ? Set.of()
                : cuentaRepository.medicosConFechasActivasDesde(idsMedico, hoy);
        Set<Long> conConsultas = idsMedico.isEmpty()
                ? Set.of()
                : cuentaRepository.medicosConConsultasAgendadasDesde(idsMedico, hoy);

        return filas.stream()
                .map(fila -> {
                    ReglaInactivacion.AgendaMedico agenda = new ReglaInactivacion.AgendaMedico() {
                        @Override
                        public boolean tieneFechasActivas() {
                            return conFechasActivas.contains(fila.id());
                        }

                        @Override
                        public boolean tieneConsultasAgendadas() {
                            return conConsultas.contains(fila.id());
                        }
                    };
                    boolean puede = ReglaInactivacion.evaluar(
                            fila.id(),
                            idAdministrador,
                            () -> new ReglaInactivacion.CuentaCandidata(
                                    fila.rol(), "ACTIVA".equals(fila.estado())),
                            agenda
                    ).isEmpty();
                    return fila.conPuedeInactivar(puede);
                })
                .toList();
    }
}
