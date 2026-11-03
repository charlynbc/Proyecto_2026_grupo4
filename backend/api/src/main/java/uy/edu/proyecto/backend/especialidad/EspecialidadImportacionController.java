package uy.edu.proyecto.backend.especialidad;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import uy.edu.proyecto.backend.csv.CsvArchivo;

/**
 * Endpoints de la carga masiva de especialidades (RF-30). Acceso exclusivo
 * del rol ADMINISTRADOR (SecurityConfig). El archivo viaja como
 * multipart/form-data en el campo "archivo" y no se almacena.
 */
@RestController
@RequestMapping("/api/especialidades/importaciones")
public class EspecialidadImportacionController {

    private final EspecialidadImportacionService service;

    public EspecialidadImportacionController(
            EspecialidadImportacionService service
    ) {
        this.service = service;
    }

    @PostMapping(
            value = "/previsualizar",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public PrevisualizacionEspecialidades previsualizar(
            @RequestParam(name = "archivo", required = false)
            MultipartFile archivo
    ) {
        return service.previsualizar(CsvArchivo.leerUtf8(archivo));
    }

    @PostMapping(
            value = "/confirmar",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResultadoImportacionEspecialidades confirmar(
            @RequestParam(name = "archivo", required = false)
            MultipartFile archivo
    ) {
        return service.confirmar(CsvArchivo.leerUtf8(archivo));
    }
}
