package uy.edu.proyecto.backend.reserva;

import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class ReservaConsultaService {

    private final ReservaConsultaRepository repository;

    public ReservaConsultaService(ReservaConsultaRepository repository) {
        this.repository = repository;
    }

    public List<ReservaHistorial> listar(Long usuarioId) {
        return repository.listarPorUsuario(usuarioId);
    }

    @Transactional
    public ReservaCancelada cancelar(Long reservaId, Long usuarioId) {
        return repository.cancelar(reservaId, usuarioId).orElseThrow(
                () -> new ApiException(
                        HttpStatus.NOT_FOUND,
                        "RESERVA_NO_ENCONTRADA",
                        "No existe una reserva activa propia con ese id"
                )
        );
    }
}