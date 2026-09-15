package uy.edu.proyecto.backend.reserva;

import java.time.OffsetDateTime;

import org.springframework.context.ApplicationEventPublisher;
import org.springframework.dao.DuplicateKeyException;
import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.notificacion.ReservaCreadaEvent;

@Service
public class ReservaService {

    private final HorarioRepository horarioRepository;
    private final ReservaRepository reservaRepository;
    private final ApplicationEventPublisher eventPublisher;

    public ReservaService(
            HorarioRepository horarioRepository,
            ReservaRepository reservaRepository,
            ApplicationEventPublisher eventPublisher
    ) {
        this.horarioRepository = horarioRepository;
        this.reservaRepository = reservaRepository;
        this.eventPublisher = eventPublisher;
    }

    @Transactional
    public Reserva crear(
            Long usuarioId,
            CrearReservaRequest request
    ) {

        OffsetDateTime inicio =
                horarioRepository
                        .buscarInicio(
                                request.horarioId()
                        )
                        .orElseThrow(
                                () -> new ApiException(
                                        HttpStatus.NOT_FOUND,
                                        "El horario no existe"
                                )
                        );

        if (!inicio.isAfter(
                OffsetDateTime.now()
        )) {

            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "El horario ya comenzo"
            );
        }

        try {

            Reserva reserva =
                    reservaRepository
                            .crear(
                                    usuarioId,
                                    request.horarioId()
                            )
                            .orElseThrow(
                                    () -> new ApiException(
                                            HttpStatus.CONFLICT,
                                            "No se pudo reservar el horario"
                                    )
                            );

            eventPublisher.publishEvent(
                    new ReservaCreadaEvent(
                            usuarioId,
                            reserva.id(),
                            reserva.horarioId()
                    )
            );

            return reserva;

        } catch (DuplicateKeyException exception) {

            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "El horario ya esta ocupado"
            );
        }
    }
}
