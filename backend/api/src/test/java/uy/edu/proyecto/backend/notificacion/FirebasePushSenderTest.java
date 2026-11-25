package uy.edu.proyecto.backend.notificacion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertInstanceOf;
import static org.junit.jupiter.api.Assertions.assertSame;
import static org.mockito.Mockito.mock;
import static org.mockito.Mockito.when;

import java.io.IOException;
import java.util.Map;

import com.google.api.client.json.gson.GsonFactory;
import com.google.firebase.messaging.FirebaseMessagingException;
import com.google.firebase.messaging.Message;
import com.google.firebase.messaging.MessagingErrorCode;

import org.junit.jupiter.api.Test;

import tools.jackson.databind.JsonNode;
import tools.jackson.databind.json.JsonMapper;

/**
 * El armado del Message y la traduccion del error de FCM, sin llamar a Firebase.
 * El SDK no expone getters: el Message se serializa a JSON con la misma fabrica
 * del SDK (Gson) y se compara con el JSON esperado, escrito a mano. En el JSON
 * el ttl va en segundos con el sufijo "s".
 */
class FirebasePushSenderTest {

    private static final JsonMapper JSON = JsonMapper.builder().build();

    private static JsonNode json(Message mensaje) throws IOException {
        return JSON.readTree(GsonFactory.getDefaultInstance().toString(mensaje));
    }

    @Test
    void elMensajeDeUnRecordatorioLlevaCanalPrioridadAltaYDosHoras() throws IOException {
        Message mensaje = FirebasePushSender.armarMensaje(
                "token-1",
                "Recordatorio de consulta",
                "Cuerpo del recordatorio",
                Map.of("tipo", "RECORDATORIO", "notificacionId", "701"));

        JsonNode esperado = JSON.readTree("""
                {
                  "token": "token-1",
                  "notification": {"title": "Recordatorio de consulta", "body": "Cuerpo del recordatorio"},
                  "data": {"tipo": "RECORDATORIO", "notificacionId": "701"},
                  "android": {
                    "priority": "high",
                    "ttl": "7200s",
                    "notification": {"channel_id": "avisos_consultas"}
                  }
                }
                """);
        assertEquals(esperado, json(mensaje));
    }

    @Test
    void elMensajeDeUnaAgendaLlevaCanalPrioridadAltaYSieteDias() throws IOException {
        Message mensaje = FirebasePushSender.armarMensaje(
                "token-2",
                "Consulta agendada",
                "Tu consulta quedó agendada.",
                Map.of("tipo", "AGENDA", "notificacionId", "702"));

        JsonNode esperado = JSON.readTree("""
                {
                  "token": "token-2",
                  "notification": {"title": "Consulta agendada", "body": "Tu consulta quedó agendada."},
                  "data": {"tipo": "AGENDA", "notificacionId": "702"},
                  "android": {
                    "priority": "high",
                    "ttl": "604800s",
                    "notification": {"channel_id": "avisos_consultas"}
                  }
                }
                """);
        assertEquals(esperado, json(mensaje));
    }

    @Test
    void sinTipoEnLosDatosElMensajeUsaLaPoliticaGeneral() throws IOException {
        Message mensaje = FirebasePushSender.armarMensaje("token-3", "Titulo", "Cuerpo", Map.of());

        JsonNode android = json(mensaje).path("android");
        assertEquals("high", android.path("priority").asString());
        assertEquals("604800s", android.path("ttl").asString());
        assertEquals("avisos_consultas", android.path("notification").path("channel_id").asString());
    }

    @Test
    void elCodigoUnregisteredSeTraduceALaVarianteDeTokenNoRegistrado() {
        FirebaseMessagingException error = mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.UNREGISTERED);

        PushException traducida = FirebasePushSender.traducir(error);

        assertInstanceOf(PushTokenNoRegistradoException.class, traducida);
        assertSame(error, traducida.getCause());
        assertEquals("El dispositivo ya no está registrado en el proveedor del aviso push", traducida.getMessage());
    }

    @Test
    void otroCodigoComoQuotaExceededSigueSiendoElPushExceptionComun() {
        FirebaseMessagingException error = mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.QUOTA_EXCEEDED);

        PushException traducida = FirebasePushSender.traducir(error);

        assertEquals(PushException.class, traducida.getClass());
        assertSame(error, traducida.getCause());
        assertEquals("El proveedor rechazó el aviso push", traducida.getMessage());
    }

    @Test
    void invalidArgumentNoSeTrataComoTokenNoRegistrado() {
        FirebaseMessagingException error = mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(MessagingErrorCode.INVALID_ARGUMENT);

        assertEquals(PushException.class, FirebasePushSender.traducir(error).getClass());
    }

    @Test
    void sinCodigoDeErrorSigueSiendoElPushExceptionComun() {
        FirebaseMessagingException error = mock(FirebaseMessagingException.class);
        when(error.getMessagingErrorCode()).thenReturn(null);

        PushException traducida = FirebasePushSender.traducir(error);

        assertEquals(PushException.class, traducida.getClass());
        assertFalse(traducida instanceof PushTokenNoRegistradoException);
    }
}
