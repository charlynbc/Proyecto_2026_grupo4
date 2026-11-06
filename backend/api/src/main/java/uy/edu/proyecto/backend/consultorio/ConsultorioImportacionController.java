package uy.edu.proyecto.backend.consultorio;

import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

import uy.edu.proyecto.backend.csv.CsvArchivo;

/**
 * Endpoints de la carga masiva de consultorios (RF-34). Acceso exclusivo
 * del rol ADMINISTRADOR (SecurityConfig). El archivo viaja como
 * multipart/form-data en el campo "archivo" y no se almacena.
 */
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
    public PrevisualizacionConsultorios previsualizar(
            @RequestParam(name = "archivo", required = false)
            MultipartFile archivo
    ) {
        return service.previsualizar(CsvArchivo.leerUtf8(archivo));
    }

    @PostMapping(
            value = "/confirmar",
            consumes = MediaType.MULTIPART_FORM_DATA_VALUE
    )
    public ResultadoImportacionConsultorios confirmar(
            @RequestParam(name = "archivo", required = false)
            MultipartFile archivo
    ) {
        return service.confirmar(CsvArchivo.leerUtf8(archivo));
    }
}
