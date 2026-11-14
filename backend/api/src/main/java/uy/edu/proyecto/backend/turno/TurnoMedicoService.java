package uy.edu.proyecto.backend.turno;

import java.time.Clock;
import java.time.LocalDate;
import java.time.OffsetDateTime;
import java.time.ZoneId;
import java.time.format.DateTimeParseException;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.parametro.ParametroService;
import uy.edu.proyecto.backend.parametro.VentanaAgendar;

@Service
public class TurnoMedicoService {

    private static final ZoneId ZONA_MONTEVIDEO =
            ZoneId.of("America/Montevideo");

    private final TurnoMedicoRepository repository;
    private final Clock clock;
    private final ParametroService parametros;

    public TurnoMedicoService(
            TurnoMedicoRepository repository,
            Clock clock,
            ParametroService parametros
    ) {
        this.repository = repository;
        this.clock = clock;
        this.parametros = parametros;
    }

    @Transactional(readOnly = true)
    public TurnosMedicoResponse listar(Long medicoId, String fechaSolicitada) {
        validarMedicoId(medicoId);
        LocalDate fecha = parsearFecha(fechaSolicitada);
        return new TurnosMedicoResponse(repository.listar(medicoId, fecha));
    }

    @Transactional(readOnly = true)
    public NumerosTurnoMedicoResponse obtenerNumeros(
            Long medicoId,
            Long turnoId,
            Boolean llegada,
            String ordenSolicitada,
            String sentidoSolicitado
    ) {
        validarMedicoId(medicoId);
        if (turnoId == null || turnoId <= 0) {
            throw validacion("El id del turno debe ser mayor que cero");
        }

        String orden = ordenSolicitada == null
                ? "hora"
                : ordenSolicitada.trim();
        String sentido = sentidoSolicitado == null
                ? "asc"
                : sentidoSolicitado.trim();
        if (!orden.equals("hora") && !orden.equals("horaLlegada")) {
            throw validacion("orden debe ser hora o horaLlegada");
        }
        if (!sentido.equals("asc") && !sentido.equals("desc")) {
            throw validacion("sentido debe ser asc o desc");
        }

        VentanaAgendar ventana = parametros.ventanaAgendar(OffsetDateTime.now(clock));
        return repository.obtenerNumeros(
                        medicoId,
                        turnoId,
                        llegada,
                        orden,
                        sentido,
                        ventana.minimoInicio(),
                        ventana.maximoInicio()
                )
                .orElseThrow(() -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "NO_ENCONTRADO",
                        "No existe el turno indicado para este médico"
                ));
    }

    private void validarMedicoId(Long medicoId) {
        if (medicoId == null || medicoId <= 0) {
            throw new ApiException(
                    HttpStatus.UNAUTHORIZED,
                    "TOKEN_INVALIDO",
                    "La sesión no es válida"
            );
        }
    }

    private LocalDate parsearFecha(String valor) {
        try {
            return LocalDate.parse(valor);
        } catch (DateTimeParseException | NullPointerException exception) {
            throw validacion("fecha debe tener formato YYYY-MM-DD");
        }
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "VALIDACION",
                mensaje
        );
    }
}
