package uy.edu.proyecto.backend.config;

import java.util.Collection;
import java.util.List;

import org.springframework.beans.factory.annotation.Value;

import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;

import org.springframework.http.HttpMethod;

import org.springframework.security.config.Customizer;

import org.springframework.security.config.annotation.web.builders.HttpSecurity;

import org.springframework.security.config.http.SessionCreationPolicy;

import org.springframework.security.core.GrantedAuthority;

import org.springframework.security.core.authority.SimpleGrantedAuthority;

import org.springframework.security.oauth2.server.resource.authentication.JwtAuthenticationConverter;

import org.springframework.security.web.SecurityFilterChain;

import org.springframework.web.cors.CorsConfiguration;

import org.springframework.web.cors.UrlBasedCorsConfigurationSource;

@Configuration
public class SecurityConfig {

    private final SecurityErrorHandler
            securityErrorHandler;


    public SecurityConfig(
            SecurityErrorHandler securityErrorHandler
    ) {
        this.securityErrorHandler =
                securityErrorHandler;
    }


    @Bean
    public SecurityFilterChain securityFilterChain(
            HttpSecurity http,

            JwtAuthenticationConverter
                    jwtAuthenticationConverter
    ) throws Exception {

        http

                .cors(
                        Customizer
                                .withDefaults()
                )

                .csrf(
                        csrf ->
                                csrf.disable()
                )

                .sessionManagement(
                        session ->
                                session
                                        .sessionCreationPolicy(
                                                SessionCreationPolicy
                                                        .STATELESS
                                        )
                )

                .authorizeHttpRequests(
                        auth ->
                                auth

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/auth/login",
                                                "/api/auth/refresh",
                                                "/api/auth/primer-ingreso/solicitar",
                                                "/api/auth/primer-ingreso/completar"
                                        )
                                        .permitAll()

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/auth/logout"
                                        )
                                        .authenticated()

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/especialidades"
                                        )
                                        .hasRole(
                                                "ADMINISTRADOR"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/consultorios"
                                        )
                                        .hasRole(
                                                "ADMINISTRADOR"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/consultorios/importaciones/**"
                                        )
                                        .hasRole(
                                                "ADMINISTRADOR"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/usuarios"
                                        )
                                        .hasRole(
                                                "ADMINISTRADOR"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/turnos-semanales"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/turnos/suspensiones/previsualizar",
                                                "/api/turnos/suspensiones",
                                                "/api/turnos/rehabilitaciones"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/disponibilidad"
                                        )
                                        .hasRole(
                                                "SOCIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/medicos"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/usuarios"
                                        )
                                        .hasRole(
                                                "ADMINISTRADOR"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/estadisticas",
                                                "/api/estadisticas/**"
                                        )
                                        .hasRole(
                                                "ADMINISTRADOR"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/historia-clinica",
                                                "/api/historia-clinica/**"
                                        )
                                        .hasRole(
                                                "SOCIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/turnos",
                                                "/api/turnos-semanales/**"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/agendas"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/avisos-llegada/consultas-hoy"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/avisos-llegada"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/funcionario/consultas/*/cancelar"
                                        )
                                        .hasRole(
                                                "FUNCIONARIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/consultas",
                                                "/api/consultas/*/cancelar"
                                        )
                                        .hasRole(
                                                "SOCIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/consultas",
                                                "/api/consultas/*"
                                        )
                                        .hasRole(
                                                "SOCIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/socios/me/pases/disponibles"
                                        )
                                        .hasRole(
                                                "SOCIO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/api/medico/turnos",
                                                "/api/medico/turnos/**"
                                        )
                                        .hasRole(
                                                "MEDICO"
                                        )

                                        .requestMatchers(
                                                HttpMethod.POST,
                                                "/api/medico/consultas/**"
                                        )
                                        .hasRole(
                                                "MEDICO"
                                        )

                                        .requestMatchers(
                                                "/api/admin/**"
                                        )
                                        .hasRole(
                                                "ADMINISTRADOR"
                                        )

                                        .requestMatchers(
                                                "/api",
                                                "/api/**"
                                        )
                                        .authenticated()

                                        .requestMatchers(
                                                HttpMethod.GET,
                                                "/",
                                                "/index.html",
                                                "/favicon.png",
                                                "/firebase-messaging-sw.js",
                                                "/flutter.js",
                                                "/flutter_bootstrap.js",
                                                "/flutter_service_worker.js",
                                                "/main.dart.js",
                                                "/manifest.json",
                                                "/version.json",
                                                "/assets/**",
                                                "/canvaskit/**",
                                                "/icons/**"
                                        )
                                        .permitAll()

                                        .anyRequest()
                                        .authenticated()
                )

                .exceptionHandling(
                        errors ->
                                errors

                                        .authenticationEntryPoint(
                                                securityErrorHandler
                                        )

                                        .accessDeniedHandler(
                                                securityErrorHandler
                                        )
                )

                .oauth2ResourceServer(
                        oauth2 ->
                                oauth2.jwt(
                                        jwt ->
                                                jwt
                                                        .jwtAuthenticationConverter(
                                                                jwtAuthenticationConverter
                                                        )
                                )
                );


        return http.build();
    }


    @Bean
    public UrlBasedCorsConfigurationSource
    corsConfigurationSource(

            @Value(
                "${app.cors.allowed-origin}"
            )
            String allowedOrigin
    ) {

        CorsConfiguration config =
                new CorsConfiguration();


        config.setAllowedOrigins(
                List.of(
                        allowedOrigin
                )
        );


        config.setAllowedMethods(
                List.of(
                        "GET",
                        "POST",
                        "PATCH",
                        "DELETE",
                        "OPTIONS"
                )
        );


        config.setAllowedHeaders(
                List.of(
                        "Authorization",
                        "Content-Type"
                )
        );


        config.setAllowCredentials(
                true
        );


        UrlBasedCorsConfigurationSource source =
                new UrlBasedCorsConfigurationSource();


        source.registerCorsConfiguration(
                "/**",
                config
        );


        return source;
    }


    @Bean
    public JwtAuthenticationConverter
    jwtAuthenticationConverter() {

        JwtAuthenticationConverter converter =
                new JwtAuthenticationConverter();


        converter.setJwtGrantedAuthoritiesConverter(
                jwt -> {

                    String role =
                            jwt.getClaimAsString(
                                    "role"
                            );


                    if (
                        role == null
                        || role.isBlank()
                    ) {

                        return List.of();
                    }


                    Collection<GrantedAuthority>
                            authorities =
                            List.of(
                                    new SimpleGrantedAuthority(
                                            "ROLE_"
                                            + role
                                    )
                            );


                    return authorities;
                }
        );


        return converter;
    }
}
