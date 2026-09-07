package uy.edu.proyecto.pocbackend;

import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

@RestController
public class HolaController {

    @GetMapping("/hola")
    public String hola() {
        return "POC backend funcionando";
    }
}

/*@RestController

le dice a Spring:

esta clase va a recibir peticiones HTTP.

Esto:

@GetMapping("/hola")

significa:

cuando alguien haga un GET /hola, ejecutá este método.

Y esto:

return "POC backend funcionando";

es la respuesta que va a devolver la API.*/