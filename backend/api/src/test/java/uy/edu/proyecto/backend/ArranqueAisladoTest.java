package uy.edu.proyecto.backend;

import static org.junit.jupiter.api.Assertions.assertNotNull;
import static org.junit.jupiter.api.Assertions.assertThrows;

import org.junit.jupiter.api.Test;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

import uy.edu.proyecto.backend.correo.CorreoException;
import uy.edu.proyecto.backend.correo.CorreoMensaje;
import uy.edu.proyecto.backend.correo.CorreoSender;

/** Arranque con configuracion aislada: sin bases reales ni proveedor de correo. */
@SpringBootTest
@TestPropertySource(properties = {
        "app.firebase.enabled=false",
        "spring.datasource.url=jdbc:postgresql://127.0.0.1:1/aislada",
        "spring.datasource.username=test",
        "spring.datasource.password=test",
        "app.jwt.secret-base64=MDEyMzQ1Njc4OWFiY2RlZjAxMjM0NTY3ODlhYmNkZWY=",
        "app.mail.provider=none"
})
class ArranqueAisladoTest {

    @Autowired
    private CorreoSender correoSender;

    @Test
    void arrancaSinCorreoConfiguradoYSinProveedorSimulado() {
        assertNotNull(correoSender);
        assertThrows(
                CorreoException.class,
                () -> correoSender.enviar(new CorreoMensaje("a@example.org", "x", "y"))
        );
    }
}
