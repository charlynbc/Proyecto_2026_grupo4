package uy.edu.proyecto.backend.atencion;

import java.time.Clock;
import java.time.LocalDate;
import java.util.List;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.exception.ApiException;

// RF-22: el médico consulta la historia clínica completa de un paciente, sin modificarla,
// mientras tenga con él una consulta AGENDADA cuyo día todavía no terminó.
@Service
public class HistoriaClinicaMedicoService {

    private final HistoriaClinicaMedicoRepository repository;
    private final HistoriaClinicaRepository historiaClinica;
    private final Clock clock;

    public HistoriaClinicaMedicoService(HistoriaClinicaMedicoRepository repository,
            HistoriaClinicaRepository historiaClinica, Clock clock) {
        this.repository = repository;
        this.historiaClinica = historiaClinica;
        this.clock = clock;
    }

    @Transactional(readOnly = true)
    public List<HistoriaClinicaDTO> listar(Long medicoId, Long socioId) {
        if (medicoId == null || medicoId <= 0) {
            throw new ApiException(HttpStatus.UNAUTHORIZED, "TOKEN_INVALIDO",
                    "La sesión no es válida");
        }
        if (socioId == null || socioId <= 0) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION",
                    "El identificador del paciente debe ser positivo");
        }
        String ciMedico = repository.ciMedico(medicoId)
                .orElseThrow(() -> new ApiException(HttpStatus.FORBIDDEN, "ACCESO_DENEGADO",
                        "La cuenta no puede consultar historias clínicas"));
        String ciPaciente = repository.ciPaciente(socioId)
                .orElseThrow(this::noEncontrado);
        if (ciMedico.equals(ciPaciente)) {
            throw new ApiException(HttpStatus.FORBIDDEN, "CONFLICTO_DE_INTERES",
                    "El médico no puede consultar por esta vía su propia historia clínica");
        }
        if (!repository.tieneConsultaHabilitante(medicoId, socioId, LocalDate.now(clock))) {
            throw noEncontrado();
        }
        return historiaClinica.listar(socioId, null, null, null, null, null,
                "fecha_atencion", "desc");
    }

    // Sin relación asistencial vigente no se revela si existe historia clínica (RNF-10).
    private ApiException noEncontrado() {
        return new ApiException(HttpStatus.NOT_FOUND, "NO_ENCONTRADO",
                "No existe el paciente indicado o no tiene una consulta que habilite el acceso");
    }
}
