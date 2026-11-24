package uy.edu.proyecto.backend.integracion;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertTrue;

import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;

/**
 * Fila 26 del contrato contra PostgreSQL real: la busqueda por cedula informa la
 * llegada de hoy si ya se registro. Los datos "de hoy" se siembran en la base
 * efimera; los nombres salen del sembrado de BaseIntegracionIT.
 */
class LlegadaEstadoAlBuscarIT extends BaseIntegracionIT {

    private void sembrarConsultaDeHoyDelSocio1() {
        long turno = sembrarTurno(hoy(), 2);
        sembrarConsulta(idSocio1, numeroId(turno, 1));
    }

    @Test
    void sinLlegadaRegistradaLaRespuestaTraeLlegadaNula() {
        sembrarConsultaDeHoyDelSocio1();

        Respuesta respuesta = get(
                "/api/avisos-llegada/consultas-hoy?ci=" + ciSocio1,
                tokenEmpleado(ciFuncionario));

        assertEquals(200, respuesta.estado(), respuesta.cuerpo());
        assertEquals(1, respuesta.json().path("items").size());
        assertTrue(respuesta.json().has("llegada"), "La clave llegada debe estar");
        assertTrue(respuesta.json().get("llegada").isNull());
    }

    @Test
    void despuesDeRegistrarLaLlegadaLaBusquedaLaDevuelveCompleta() {
        sembrarConsultaDeHoyDelSocio1();
        String funcionario = tokenEmpleado(ciFuncionario);
        Respuesta registro = post("/api/avisos-llegada", funcionario,
                "{\"ci\":\"%s\"}".formatted(ciSocio1));
        assertEquals(201, registro.estado(), registro.cuerpo());

        Respuesta busqueda = get(
                "/api/avisos-llegada/consultas-hoy?ci=" + ciSocio1, funcionario);

        assertEquals(200, busqueda.estado(), busqueda.cuerpo());
        var llegada = busqueda.json().path("llegada");
        assertEquals(
                OffsetDateTime.parse(registro.json().path("registradaEn").asString()).toInstant(),
                OffsetDateTime.parse(llegada.path("registradaEn").asString()).toInstant());
        assertEquals(idFuncionario, llegada.path("registradaPor").path("id").asLong());
        assertEquals("Fabio", llegada.path("registradaPor").path("nombre").asString());
        assertEquals("Funcionario", llegada.path("registradaPor").path("apellido").asString());
        assertEquals(1, busqueda.json().path("items").size());
    }

    @Test
    void laLlegadaDeOtroSocioNoAparece() {
        sembrarConsultaDeHoyDelSocio1();
        long turno = sembrarTurno(hoy(), 1);
        sembrarConsulta(idSocio2, numeroId(turno, 1));
        String funcionario = tokenEmpleado(ciFuncionario);
        post("/api/avisos-llegada", funcionario, "{\"ci\":\"%s\"}".formatted(ciSocio1));

        Respuesta busqueda = get(
                "/api/avisos-llegada/consultas-hoy?ci=" + ciSocio2, funcionario);

        assertEquals(200, busqueda.estado(), busqueda.cuerpo());
        assertTrue(busqueda.json().get("llegada").isNull());
    }
}
