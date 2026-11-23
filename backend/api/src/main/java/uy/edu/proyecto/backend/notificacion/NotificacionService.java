package uy.edu.proyecto.backend.notificacion;

import java.time.Clock;
import java.time.OffsetDateTime;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

/** RNF-23: la lista de avisos del socio autenticado (contrato, GET /api/notificaciones). */
@Service
public class NotificacionService {
    private static final int SIZE_POR_DEFECTO = 20;
    private static final int SIZE_MAXIMO = 100;

    private final NotificacionRepository repository;
    private final Clock clock;

    public NotificacionService(NotificacionRepository repository, Clock clock) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public NotificacionPageResponse listar(Long socioId, String page, String size) {
        if (socioId == null || socioId <= 0) {
            throw validacion("El identificador del socio debe ser positivo");
        }
        int pagina = entero(page, 0, 0, Integer.MAX_VALUE, "page debe ser un entero mayor o igual a 0");
        int cantidad = entero(size, SIZE_POR_DEFECTO, 1, SIZE_MAXIMO, "size debe estar entre 1 y 100");

        // La hora de Uruguay del servidor: un recordatorio se lista desde su hora.
        OffsetDateTime ahora = OffsetDateTime.now(clock);
        var items = repository.listar(socioId, ahora, pagina, cantidad).stream()
                .map(fila -> new NotificacionDTO(
                        fila.id(),
                        fila.tipo(),
                        NotificacionTextos.titulo(fila.tipo()),
                        fila.contenido(),
                        fila.creadaEn().atZoneSameInstant(clock.getZone()).toOffsetDateTime(),
                        fila.consultaId(),
                        fila.atencionId()))
                .toList();
        return new NotificacionPageResponse(items, pagina, cantidad, repository.total(socioId, ahora));
    }

    /** Un parametro ausente o en blanco vale el valor por defecto; fuera de rango o no numerico es un 400. */
    private static int entero(String crudo, int defecto, int minimo, int maximo, String mensaje) {
        if (crudo == null || crudo.isBlank()) {
            return defecto;
        }
        try {
            int valor = Integer.parseInt(crudo.trim());
            if (valor >= minimo && valor <= maximo) {
                return valor;
            }
        } catch (NumberFormatException ignorada) {
            // Se informa con el mensaje de abajo.
        }
        throw validacion(mensaje);
    }

    private static ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
