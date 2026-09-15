package uy.edu.proyecto.backend.notificacion;

import java.util.Optional;
import java.util.concurrent.ConcurrentHashMap;

import org.springframework.stereotype.Component;

@Component
public class FirebaseRegistrationStore {

    private final ConcurrentHashMap<Long, String>
            fidPorUsuario =
            new ConcurrentHashMap<>();

    public void guardar(
            Long usuarioId,
            String fid
    ) {

        fidPorUsuario.put(
                usuarioId,
                fid
        );
    }

    public Optional<String> buscar(
            Long usuarioId
    ) {

        return Optional.ofNullable(
                fidPorUsuario.get(usuarioId)
        );
    }
}
