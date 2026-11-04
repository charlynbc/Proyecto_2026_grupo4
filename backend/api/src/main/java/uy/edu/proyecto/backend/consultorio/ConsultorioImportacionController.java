package uy.edu.proyecto.backend.consultorio;

import java.io.IOException;
import java.nio.ByteBuffer;
import java.nio.charset.CodingErrorAction;
import java.nio.charset.StandardCharsets;

import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import uy.edu.proyecto.backend.exception.ApiException;

@RestController
@RequestMapping("/api/consultorios/importaciones")
public class ConsultorioImportacionController {

    private final ConsultorioImportacionService service;

    public ConsultorioImportacionController(
            ConsultorioImportacionService service
    ) {
        this.service = service;
    }

    @PostMapping(
            value = "/previsualizar",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ConsultorioCsvPrevisualizador.Resultado previsualizar(
            @RequestParam(name = "archivo", required = false)
            MultipartFile archivo
    ) {
        if (archivo == null || archivo.isEmpty()) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "Debe seleccionar un archivo CSV no vacío"
            );
        }
        if (archivo.getSize() > 1024L * 1024L) {
            throw new ApiException(HttpStatus.BAD_REQUEST, "CSV_INVALIDO",
                    "El archivo supera el tamaño máximo permitido (1 MB)");
        }

        String contenido;
        try {
            contenido = StandardCharsets.UTF_8
                    .newDecoder()
                    .onMalformedInput(CodingErrorAction.REPORT)
                    .onUnmappableCharacter(CodingErrorAction.REPORT)
                    .decode(ByteBuffer.wrap(archivo.getBytes()))
                    .toString();
        } catch (IOException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "No se pudo leer el archivo como UTF-8"
            );
        }

        try {
            return service.previsualizar(contenido);
        } catch (IllegalArgumentException exception) {
            throw new ApiException(
                    HttpStatus.BAD_REQUEST,
                    "CSV_INVALIDO",
                    "El archivo CSV está vacío o tiene un formato inválido"
            );
        }
    }
}
