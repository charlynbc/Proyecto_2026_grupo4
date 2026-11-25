package uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica

import android.app.NotificationChannel
import android.app.NotificationManager
import android.os.Bundle
import io.flutter.embedding.android.FlutterActivity

class MainActivity : FlutterActivity() {

    override fun onCreate(savedInstanceState: Bundle?) {
        super.onCreate(savedInstanceState)
        createNotificationChannel()
    }

    // El canal de los avisos push. Crearlo es idempotente: si ya existe, no cambia.
    // minSdk es 26, asi que los canales siempre existen y no hace falta chequear la version.
    private fun createNotificationChannel() {
        val channel = NotificationChannel(
            CHANNEL_ID,
            "Avisos de consultas",
            NotificationManager.IMPORTANCE_HIGH,
        ).apply {
            description = "Avisos sobre tus consultas e historia clínica"
            enableVibration(true)
        }
        getSystemService(NotificationManager::class.java).createNotificationChannel(channel)
    }

    companion object {
        // Tiene que coincidir con el canal que manda el backend en cada aviso push
        // (docs/api/railway-correo.md, seccion de avisos push en Android) y con la
        // meta-data default_notification_channel_id del manifiesto.
        const val CHANNEL_ID = "avisos_consultas"
    }
}
