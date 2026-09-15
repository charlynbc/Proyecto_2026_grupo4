package uy.edu.proyecto.backend.notificacion;

import java.util.Map;

import jakarta.validation.Valid;

import org.springframework.http.ResponseEntity;
import org.springframework.security.core.annotation.AuthenticationPrincipal;
import org.springframework.security.oauth2.jwt.Jwt;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
@RequestMapping("/api/notificaciones")
public class FirebaseRegistrationController {

    private final FirebaseRegistrationStore store;

    public FirebaseRegistrationController(
            FirebaseRegistrationStore store
    ) {
        this.store = store;
    }

    @PostMapping("/registro")
    public ResponseEntity<Map<String, String>> registrar(
            @AuthenticationPrincipal Jwt jwt,

            @Valid
            @RequestBody
            FirebaseRegistroRequest request
    ) {

        Long usuarioId =
                Long.valueOf(
                        jwt.getSubject()
                );

        store.guardar(
                usuarioId,
                request.fid()
        );

        return ResponseEntity.ok(
                Map.of(
                        "mensaje",
                        "Navegador registrado para notificaciones"
                )
        );
    }
}
