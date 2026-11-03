package uy.edu.proyecto.backend.usuario;

import java.util.ArrayList;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;

import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.csv.CsvArchivo;
import uy.edu.proyecto.backend.especialidad.Especialidad;
import uy.edu.proyecto.backend.especialidad.EspecialidadRepository;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.UsuarioCsvValidador.FilaUsuarioParseada;

/**
 * Carga masiva de usuarios (RF-32) segun la seccion 3.1.4 y las reglas de
 * RF-31. La previsualizacion informa totales y el motivo de cada fila con
 * error; la confirmacion importa solo las filas validas invocando el alta
 * individual (AltaUsuarioService), de modo que cada cuenta se registra en su
 * propia transaccion, con las mismas validaciones, bloqueos e indices que el
 * alta individual. No se envian correos ni se activan cuentas: quedan
 * pendientes de primer ingreso (RF-31).
 */
@Service
public class UsuarioImportacionService {

    private final CuentaRepository repository;
    private final EspecialidadRepository especialidadRepository;
    private final AltaUsuarioService altaUsuarioService;
    private final UsuarioCsvValidador validador = new UsuarioCsvValidador();

    public UsuarioImportacionService(
            CuentaRepository repository,
            EspecialidadRepository especialidadRepository,
            AltaUsuarioService altaUsuarioService
    ) {
        this.repository = repository;
        this.especialidadRepository = especialidadRepository;
        this.altaUsuarioService = altaUsuarioService;
    }

    public PrevisualizacionUsuarios previsualizar(String contenido) {
        List<FilaUsuarioParseada> filas = validar(contenido);
        filas = verificarContraBase(filas);

        int total = filas.size();
        int invalidas = (int) filas.stream()
                .filter(fila -> !fila.valida())
                .count();

        return new PrevisualizacionUsuarios(
                total,
                total - invalidas,
                invalidas,
                filas.stream().map(FilaUsuarioParseada::aFilaCsv).toList(),
                filas.stream()
                        .filter(fila -> !fila.valida())
                        .map(FilaUsuarioParseada::aFilaCsv)
                        .toList()
        );
    }

    public ResultadoImportacionUsuarios confirmar(String contenido) {
        List<FilaUsuarioParseada> filas = validar(contenido);
        filas = verificarEspecialidades(filas);

        List<FilaUsuarioParseada> procesadas = new ArrayList<>();
        for (FilaUsuarioParseada fila : filas) {
            if (!fila.valida()) {
                procesadas.add(fila);
                continue;
            }
            try {
                altaUsuarioService.crear(aAltaUsuarioRequest(fila));
                procesadas.add(fila);
            } catch (ApiException exception) {
                procesadas.add(rechazar(fila, exception.getMessage()));
            }
        }

        int total = procesadas.size();
        int rechazadas = (int) procesadas.stream()
                .filter(fila -> !fila.valida())
                .count();

        return new ResultadoImportacionUsuarios(
                total,
                total - rechazadas,
                rechazadas,
                procesadas.stream().map(FilaUsuarioParseada::aFilaCsv).toList(),
                procesadas.stream()
                        .filter(fila -> !fila.valida())
                        .map(FilaUsuarioParseada::aFilaCsv)
                        .toList()
        );
    }

    private List<FilaUsuarioParseada> validar(String contenido) {
        var filasCrudas = CsvArchivo.parsear(
                contenido,
                UsuarioCsvValidador.COLUMNAS
        );
        return validador.validar(filasCrudas);
    }

    /**
     * Controles de solo lectura contra la base para la previsualizacion:
     * especialidades conocidas, persona con datos coincidentes y cuenta del
     * mismo rol sin duplicar. La confirmacion vuelve a verificar todo dentro
     * del alta individual.
     */
    private List<FilaUsuarioParseada> verificarContraBase(
            List<FilaUsuarioParseada> filas
    ) {
        List<FilaUsuarioParseada> conEspecialidades =
                verificarEspecialidades(filas);

        List<FilaUsuarioParseada> actualizadas = new ArrayList<>();
        for (FilaUsuarioParseada fila : conEspecialidades) {
            if (!fila.valida()) {
                actualizadas.add(fila);
                continue;
            }

            String error = null;
            var persona = repository.buscarPersona(fila.ci());
            if (persona.isPresent()
                    && !coincideIdentidad(persona.get(), fila)) {
                error = "La CI ya esta registrada con otros datos personales";
            } else if (fila.rol().equals("SOCIO")
                    && repository.existeCuentaSocio(fila.ci())) {
                error = "La CI ya tiene una cuenta de socio";
            } else if (!fila.rol().equals("SOCIO")
                    && repository.existeCuentaEmpleadoHabilitada(fila.ci())) {
                error = "La CI ya tiene una cuenta de empleado habilitada";
            }

            actualizadas.add(error == null ? fila : rechazar(fila, error));
        }
        return actualizadas;
    }

    /** Rechaza las filas de medicos con especialidades que no existen. */
    private List<FilaUsuarioParseada> verificarEspecialidades(
            List<FilaUsuarioParseada> filas
    ) {
        Set<String> nombres = filas.stream()
                .filter(FilaUsuarioParseada::valida)
                .flatMap(fila -> fila.especialidades().stream())
                .map(nombre -> nombre.toLowerCase(Locale.ROOT))
                .collect(Collectors.toSet());

        if (nombres.isEmpty()) {
            return filas;
        }

        Map<String, Especialidad> existentes =
                especialidadRepository.buscarPorNombresLower(nombres);

        List<FilaUsuarioParseada> actualizadas = new ArrayList<>();
        for (FilaUsuarioParseada fila : filas) {
            if (!fila.valida()) {
                actualizadas.add(fila);
                continue;
            }
            String desconocida = null;
            for (String nombre : fila.especialidades()) {
                if (!existentes.containsKey(nombre.toLowerCase(Locale.ROOT))) {
                    desconocida = nombre;
                    break;
                }
            }
            actualizadas.add(desconocida == null
                    ? fila
                    : rechazar(fila, "Especialidad desconocida: " + desconocida));
        }
        return actualizadas;
    }

    private AltaUsuarioRequest aAltaUsuarioRequest(FilaUsuarioParseada fila) {
        List<Long> especialidadIds = List.of();
        if (fila.rol().equals("MEDICO")) {
            Map<String, Especialidad> existentes =
                    especialidadRepository.buscarPorNombresLower(
                            fila.especialidades()
                    );
            List<Long> ids = new ArrayList<>();
            for (String nombre : fila.especialidades()) {
                Especialidad especialidad = existentes.get(
                        nombre.toLowerCase(Locale.ROOT)
                );
                if (especialidad == null) {
                    throw new ApiException(
                            org.springframework.http.HttpStatus.BAD_REQUEST,
                            "VALIDACION",
                            "Especialidad desconocida: " + nombre
                    );
                }
                ids.add(especialidad.id());
            }
            especialidadIds = List.copyOf(ids);
        }

        return new AltaUsuarioRequest(
                fila.ci(),
                fila.nombre(),
                fila.apellido(),
                fila.fechaNacimiento(),
                fila.correo(),
                fila.telefono1(),
                fila.telefono2(),
                fila.direccion(),
                fila.rol(),
                especialidadIds
        );
    }

    private boolean coincideIdentidad(
            CuentaRepository.PersonaRegistrada persona,
            FilaUsuarioParseada fila
    ) {
        return persona.nombre().equals(fila.nombre())
                && persona.apellido().equals(fila.apellido())
                && persona.fechaNacimiento().equals(fila.fechaNacimiento());
    }

    private FilaUsuarioParseada rechazar(
            FilaUsuarioParseada fila,
            String error
    ) {
        return new FilaUsuarioParseada(
                fila.numero(),
                fila.ci(),
                fila.nombre(),
                fila.apellido(),
                fila.fechaNacimiento(),
                fila.correo(),
                fila.telefono1(),
                fila.telefono2(),
                fila.direccion(),
                fila.rol(),
                fila.especialidades(),
                error
        );
    }
}
