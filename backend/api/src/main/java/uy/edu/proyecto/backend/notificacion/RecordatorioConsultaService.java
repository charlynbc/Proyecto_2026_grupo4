package uy.edu.proyecto.backend.notificacion;

import java.time.Clock;
import java.time.OffsetDateTime;
import java.util.List;
import java.util.Optional;

import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Propagation;
import org.springframework.transaction.annotation.Transactional;

import uy.edu.proyecto.backend.agenda.ConsultaRepository;
import uy.edu.proyecto.backend.agenda.ConsultaRepository.ConsultaParaRecordatorio;
import uy.edu.proyecto.backend.parametro.ParametroService;

/** Recordatorio de consulta al socio (RNF-25). */
@Service
public class RecordatorioConsultaService {

    private final ConsultaRepository repository;
    private final NotificacionEnvios envios;
    private final ParametroService parametros;
    private final Clock clock;

    public RecordatorioConsultaService(
            ConsultaRepository repository,
            NotificacionEnvios envios,
            ParametroService parametros,
            Clock clock
    ) {
        this.repository = repository;
        this.envios = envios;
        this.parametros = parametros;
        this.clock = clock;
    }

    /** Las consultas que ya entraron en la ventana y todavia no tienen recordatorio. */
    public List<ConsultaParaRecordatorio> consultasPorRecordar() {
        return repository.buscarConsultasParaRecordatorio(
                OffsetDateTime.now(clock), parametros.recordatorioAntelacionHoras());
    }

    /**
     * Guarda el recordatorio de la consulta y pide sus envios (correo y push), todo
     * en su propia transaccion: si una consulta falla, las demas no se afectan.
     * Devuelve false si ya habia un recordatorio, y en ese caso no pide nada.
     */
    @Transactional(propagation = Propagation.REQUIRES_NEW)
    public boolean generar(ConsultaParaRecordatorio consulta) {
        String contenido = NotificacionTextos.cuerpoRecordatorio(
                consulta.especialidad(),
                consulta.medicoNombre(),
                consulta.medicoApellido(),
                consulta.fecha(),
                consulta.horaInicio(),
                consulta.consultorioNombre(),
                consulta.consultorioUbicacion());
        Optional<Long> notificacionId = repository.crearNotificacionRecordatorio(
                consulta.consultaId(), contenido, consulta.programadaPara());
        if (notificacionId.isEmpty()) {
            return false;
        }
        envios.solicitar(notificacionId.get(), consulta.socioId());
        return true;
    }
}
