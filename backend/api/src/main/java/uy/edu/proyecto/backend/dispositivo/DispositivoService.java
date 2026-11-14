package uy.edu.proyecto.backend.dispositivo;

import org.springframework.http.HttpStatus;
import org.springframework.stereotype.Service;

import uy.edu.proyecto.backend.exception.ApiException;

@Service
public class DispositivoService {

    static final int LARGO_MAXIMO_TOKEN = 4096;

    private final DispositivoRepository repository;

    public DispositivoService(DispositivoRepository repository) {
        this.repository = repository;
    }

    public DispositivoRegistro registrar(Long socioId, String token) {
        return repository.registrar(socioId, tokenValido(token));
    }

    public void darDeBaja(Long socioId, String token) {
        repository.deshabilitar(socioId, tokenValido(token));
    }

    /** Se recorta; despues de recortado no puede quedar vacio ni pasar de 4096 caracteres. */
    private static String tokenValido(String token) {
        String recortado = token == null ? "" : token.strip();
        if (recortado.isEmpty()) {
            throw validacion(
                    "Falta el identificador del dispositivo para las notificaciones.");
        }
        if (recortado.length() > LARGO_MAXIMO_TOKEN) {
            throw validacion(
                    "El identificador del dispositivo para las notificaciones es demasiado largo "
                            + "(máximo " + LARGO_MAXIMO_TOKEN + " caracteres).");
        }
        return recortado;
    }

    private static ApiException validacion(String mensaje) {
        return new ApiException(HttpStatus.BAD_REQUEST, "VALIDACION", mensaje);
    }
}
