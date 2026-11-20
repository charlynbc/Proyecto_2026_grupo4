package uy.edu.proyecto.backend.integracion;

import java.time.LocalDate;
import java.time.LocalDateTime;
import java.time.OffsetDateTime;

import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.test.context.TestPropertySource;
import org.springframework.test.context.bean.override.mockito.MockitoBean;

import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.notificacion.EnvioNotificacionPoller;
import uy.edu.proyecto.backend.notificacion.PushSender;
import uy.edu.proyecto.backend.notificacion.RecordatorioConsultaProceso;
import uy.edu.proyecto.backend.notificacion.RecordatorioConsultaService;

/**
 * Datos y ayudas comunes de los IT del recordatorio de consulta (RNF-25).
 *
 * El agendador de fondo va apagado (app.scheduling.enabled=false): los beans del
 * proceso y del poller siguen, pero solo corren cuando el test los llama, asi no
 * compiten con el sembrado de datos ni con el reloj fijado.
 */
@TestPropertySource(properties = "app.scheduling.enabled=false")
abstract class RecordatorioITBase extends BaseIntegracionIT {

    @MockitoBean
    CorreoSender correoSender;

    @MockitoBean
    PushSender pushSender;

    @Autowired
    RecordatorioConsultaProceso proceso;

    @Autowired
    RecordatorioConsultaService servicio;

    @Autowired
    EnvioNotificacionPoller poller;

    /** El turno sembrado empieza a las 10:00 de ese dia (numero 1). */
    static LocalDate diaDelTurno() {
        return hoy().plusDays(5);
    }

    /** Siembra una consulta del socio 1 en el numero 1 del turno y fija cuando se agendo. */
    long consultaAgendadaEn(LocalDateTime agendadaEnMontevideo) {
        long numero = numeroId(sembrarTurno(diaDelTurno(), 2), 1);
        long consulta = sembrarConsulta(idSocio1, numero);
        OffsetDateTime agendadaEn = agendadaEnMontevideo.atZone(ZONA).toOffsetDateTime();
        jdbc.update("UPDATE consulta SET agendada_en = ? WHERE id_consulta = ?",
                agendadaEn, consulta);
        return consulta;
    }

    int recordatorios() {
        return jdbc.queryForObject(
                "SELECT count(*) FROM notificacion WHERE tipo = 'RECORDATORIO'", Integer.class);
    }

    static String fechaUruguaya(LocalDate fecha) {
        return "%02d/%02d/%d".formatted(fecha.getDayOfMonth(), fecha.getMonthValue(), fecha.getYear());
    }
}
