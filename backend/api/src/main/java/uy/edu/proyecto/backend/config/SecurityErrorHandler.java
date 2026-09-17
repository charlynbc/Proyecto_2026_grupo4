package uy.edu.proyecto.backend.config;

import java.io.IOException;

import jakarta.servlet.http.HttpServletRequest;
import jakarta.servlet.http.HttpServletResponse;

import org.springframework.security.core.AuthenticationException;

import org.springframework.security.access.AccessDeniedException;

import org.springframework.security.web.AuthenticationEntryPoint;
import org.springframework.security.web.access.AccessDeniedHandler;

import org.springframework.stereotype.Component;

@Component
public class SecurityErrorHandler
        implements
        AuthenticationEntryPoint,
        AccessDeniedHandler {


    @Override
    public void commence(
            HttpServletRequest request,
            HttpServletResponse response,
            AuthenticationException exception
    ) throws IOException {

        response.setStatus(401);

        response.setContentType(
                "application/json"
        );

        response
                .getWriter()
                .write(
                        """
                        {
                          "code":"NO_AUTENTICADO",
                          "message":"Se requiere autenticacion"
                        }
                        """
                );
    }


    @Override
    public void handle(
            HttpServletRequest request,
            HttpServletResponse response,
            AccessDeniedException exception
    ) throws IOException {

        response.setStatus(403);

        response.setContentType(
                "application/json"
        );

        response
                .getWriter()
                .write(
                        """
                        {
                          "code":"ACCESO_DENEGADO",
                          "message":"No tenes permisos para realizar esta operacion"
                        }
                        """
                );
    }
}
