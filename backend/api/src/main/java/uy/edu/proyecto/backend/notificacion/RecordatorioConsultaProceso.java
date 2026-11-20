package uy.edu.proyecto.backend.notificacion;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.scheduling.annotation.Scheduled;
import org.springframework.stereotype.Component;

import uy.edu.proyecto.backend.agenda.ConsultaRepository.ConsultaParaRecordatorio;

/**
 * Genera los recordatorios de consulta (RNF-25) cada cierto tiempo. Se apaga con
 * la misma propiedad que el poller de envios
 * (app.notificaciones.procesos-programados.habilitados), para que backend-dev,
 * que comparte la base, no compita por las mismas consultas. El intervalo sale de
 * app.notificaciones.recordatorios.intervalo-ms (60000 ms por defecto).
 *
 * Pendiente: la regla R-MDAT-21 pide comprobar que la consulta siga AGENDADA
 * justo antes de enviar el recordatorio. No se hace todavia porque falta un
 * estado nuevo en envio_notificacion: los actuales (PENDIENTE, ENVIADO y
 * FALLIDO) no sirven para un envio descartado sin error. Hasta entonces, el
 * recordatorio se genera solo cuando ya corresponde enviarlo, asi que la
 * ventana de riesgo es la que hay entre la generacion y el envio.
 */
@Component
@ConditionalOnProperty(
        name = "app.notificaciones.procesos-programados.habilitados",
        havingValue = "true",
        matchIfMissing = true)
public class RecordatorioConsultaProceso {

    private static final Logger log =
            LoggerFactory.getLogger(RecordatorioConsultaProceso.class);

    private final RecordatorioConsultaService servicio;

    public RecordatorioConsultaProceso(RecordatorioConsultaService servicio) {
        this.servicio = servicio;
    }

    @Scheduled(fixedDelayString = "${app.notificaciones.recordatorios.intervalo-ms:60000}")
    public void generarRecordatorios() {
        Iterable<ConsultaParaRecordatorio> consultas;
        try {
            consultas = servicio.consultasPorRecordar();
        } catch (RuntimeException exception) {
            log.error(
                    "No se pudieron buscar las consultas para recordar; se reintenta en el próximo ciclo; tipo de error: {}",
                    exception.getClass().getSimpleName()
            );
            return;
        }
        for (ConsultaParaRecordatorio consulta : consultas) {
            try {
                servicio.generar(consulta);
            } catch (RuntimeException exception) {
                log.error(
                        "No se pudo generar el recordatorio de la consulta {}; se reintenta en el próximo ciclo; tipo de error: {}",
                        consulta.consultaId(),
                        exception.getClass().getSimpleName()
                );
            }
        }
    }
}
