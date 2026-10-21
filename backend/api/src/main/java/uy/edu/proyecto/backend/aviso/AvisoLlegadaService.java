package uy.edu.proyecto.backend.aviso;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.agenda.ConsultaDTO;
import uy.edu.proyecto.backend.aviso.AvisoLlegadaRepository.Funcionario;
import uy.edu.proyecto.backend.aviso.AvisoLlegadaRepository.Socio;
import uy.edu.proyecto.backend.exception.ApiException;
import uy.edu.proyecto.backend.usuario.CiUruguaya;

@Service
public class AvisoLlegadaService {

    private final AvisoLlegadaRepository repository;
    private final Clock clock;

    public AvisoLlegadaService(
            AvisoLlegadaRepository repository,
            Clock clock
    ) {
        this.repository = repository;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<ConsultaDTO> consultasDeHoy(String ciSolicitada) {
        String ci = normalizarCi(ciSolicitada);
        if (repository.buscarSocioHabilitado(ci).isEmpty()) {
            throw noEncontrado("No existe un socio activo con esa CI");
        }
        return repository.listarConsultasAgendadas(ci, LocalDate.now(clock));
    }

    @Transactional
    public ResultadoAvisoLlegada registrar(
            String ciSolicitada,
            Long funcionarioId
    ) {
        String ci = normalizarCi(ciSolicitada);
        if (funcionarioId == null || funcionarioId <= 0) {
            throw validacion("La identidad del funcionario no es válida");
        }

        Funcionario funcionario = repository
                .buscarFuncionarioActivo(funcionarioId)
                .orElseThrow(() -> noEncontrado(
                        "No existe un funcionario activo"
                ));
        Socio socio = repository.bloquearSocioHabilitado(ci)
                .orElseThrow(() -> noEncontrado(
                        "No existe un socio activo con esa CI"
                ));

        if (funcionario.ci().equals(socio.ci())) {
            throw new ApiException(
                    HttpStatus.FORBIDDEN,
                    "CONFLICTO_INTERES",
                    "Un funcionario no puede registrar su propio aviso de llegada"
            );
        }

        LocalDate hoy = LocalDate.now(clock);
        var existente = repository.buscarAviso(socio.id(), hoy);
        if (existente.isPresent()) {
            return new ResultadoAvisoLlegada(existente.get(), false);
        }
        if (!repository.socioTieneConsultaAgendadaHoy(socio.id(), hoy)) {
            throw new ApiException(
                    HttpStatus.CONFLICT,
                    "SIN_CONSULTAS_AGENDADAS",
                    "El socio no tiene consultas agendadas para hoy"
            );
        }

        var creado = repository.crearSiNoExiste(socio, funcionario, hoy);
        if (creado.isPresent()) {
            return new ResultadoAvisoLlegada(creado.get(), true);
        }

        AvisoLlegadaDTO original = repository.buscarAviso(socio.id(), hoy)
                .orElseThrow(() -> new IllegalStateException(
                        "La inserción del aviso no creó ni encontró un registro"
                ));
        return new ResultadoAvisoLlegada(original, false);
    }

    private String normalizarCi(String valor) {
        return CiUruguaya.normalizarValida(valor)
                .orElseThrow(() -> validacion("La CI no es válida"));
    }

    private ApiException validacion(String mensaje) {
        return new ApiException(
                HttpStatus.BAD_REQUEST,
                "VALIDACION",
                mensaje
        );
    }

    private ApiException noEncontrado(String mensaje) {
        return new ApiException(
                HttpStatus.NOT_FOUND,
                "NO_ENCONTRADO",
                mensaje
        );
    }
}
