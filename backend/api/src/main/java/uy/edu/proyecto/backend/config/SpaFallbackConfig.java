package uy.edu.proyecto.backend.config;

import org.springframework.context.annotation.Configuration;
import org.springframework.web.servlet.config.annotation.ViewControllerRegistry;
import org.springframework.web.servlet.config.annotation.WebMvcConfigurer;

/**
 * La app Flutter web usa rutas sin # (por ejemplo /primer-ingreso?token=...): el
 * navegador pide esa URL al servidor, que responde el index.html y deja que la
 * app resuelva la ruta. Solo se reenvian las rutas de la app, no todo lo que no
 * existe: lo demas (la API, los archivos que faltan) sigue dando su 401 o 404.
 *
 * Es la lista de rutas de primer nivel de app_router.dart: las pantallas de
 * acceso, la cuenta y el prefijo de cada rol (socio, funcionario, medico, admin).
 */
@Configuration
public class SpaFallbackConfig implements WebMvcConfigurer {

    /** Rutas de la app que se responden con el index.html, todas por GET y sin sesion. */
    public static final String[] RUTAS_DE_LA_APP = {
            "/login",
            "/primer-ingreso",
            "/primer-ingreso/**",
            "/recuperacion",
            "/recuperacion/**",
            "/cambio-correo",
            "/cuenta",
            "/cuenta/**",
            "/socio/**",
            "/funcionario/**",
            "/medico/**",
            "/admin/**"
    };

    @Override
    public void addViewControllers(ViewControllerRegistry registry) {
        for (String ruta : RUTAS_DE_LA_APP) {
            registry.addViewController(ruta).setViewName("forward:/index.html");
        }
    }
}
