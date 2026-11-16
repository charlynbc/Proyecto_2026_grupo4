package uy.edu.proyecto.backend.config;

import java.io.IOException;

import com.google.auth.oauth2.GoogleCredentials;
import com.google.firebase.FirebaseApp;
import com.google.firebase.FirebaseOptions;

import org.springframework.beans.factory.annotation.Value;
import org.springframework.boot.autoconfigure.condition.ConditionalOnProperty;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

@Configuration
@ConditionalOnProperty(
    name = "app.firebase.enabled",
    havingValue = "true",
    matchIfMissing = true
)
public class FirebaseConfig {

    /**
     * Si FIREBASE_SERVICE_ACCOUNT_JSON tiene valor (JSON o base64) se usa esa clave;
     * si no, GOOGLE_APPLICATION_CREDENTIALS. El valor es secreto y no se registra.
     */
    @Bean
    public FirebaseApp firebaseApp(
            @Value("${FIREBASE_SERVICE_ACCOUNT_JSON:}") String cuentaDeServicio
    ) throws IOException {

        if (!FirebaseApp.getApps().isEmpty()) {
            return FirebaseApp.getInstance();
        }

        GoogleCredentials credentials = FirebaseCredenciales.desde(
                cuentaDeServicio,
                GoogleCredentials::getApplicationDefault
        );

        FirebaseOptions options =
                FirebaseOptions.builder()
                        .setCredentials(credentials)
                        .build();

        return FirebaseApp.initializeApp(options);
    }
}
