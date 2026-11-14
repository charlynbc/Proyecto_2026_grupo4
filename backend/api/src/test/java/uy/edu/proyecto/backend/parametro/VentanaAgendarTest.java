package uy.edu.proyecto.backend.parametro;

import java.time.OffsetDateTime;

import org.junit.jupiter.api.Test;

import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;

// Regla unica de la ventana de agendar: instantes, no fechas.
class VentanaAgendarTest {

    private static final OffsetDateTime AHORA =
            OffsetDateTime.parse("2026-10-20T08:00:00-03:00");

    @Test
    void conValoresPorDefectoVaDeDosHorasATreintaDias() {
        VentanaAgendar ventana = ParametroService.porDefecto().ventanaAgendar(AHORA);

        assertEquals(OffsetDateTime.parse("2026-10-20T10:00:00-03:00"), ventana.minimoInicio());
        assertEquals(OffsetDateTime.parse("2026-11-19T08:00:00-03:00"), ventana.maximoInicio());
    }

    @Test
    void conCuatroHorasYDiezDiasCambiaAmbosExtremos() {
        VentanaAgendar ventana = ParametrosDePrueba.nuevo().agendar(4, 10).construir()
                .ventanaAgendar(AHORA);

        assertEquals(OffsetDateTime.parse("2026-10-20T12:00:00-03:00"), ventana.minimoInicio());
        assertEquals(OffsetDateTime.parse("2026-10-30T08:00:00-03:00"), ventana.maximoInicio());
    }

    @Test
    void unNumeroQueEmpiezaExactamenteEnElMinimoEsValido() {
        VentanaAgendar ventana = ParametroService.porDefecto().ventanaAgendar(AHORA);

        assertTrue(ventana.contiene(OffsetDateTime.parse("2026-10-20T10:00:00-03:00")));
    }

    @Test
    void unNumeroUnSegundoAntesDelMinimoNoEsValido() {
        VentanaAgendar ventana = ParametroService.porDefecto().ventanaAgendar(AHORA);

        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-10-20T09:59:59-03:00")));
    }

    @Test
    void unNumeroQueEmpiezaExactamenteEnElMaximoEsValido() {
        VentanaAgendar ventana = ParametroService.porDefecto().ventanaAgendar(AHORA);

        assertTrue(ventana.contiene(OffsetDateTime.parse("2026-11-19T08:00:00-03:00")));
    }

    @Test
    void unNumeroUnSegundoDespuesDelMaximoNoEsValido() {
        VentanaAgendar ventana = ParametroService.porDefecto().ventanaAgendar(AHORA);

        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-11-19T08:00:01-03:00")));
    }

    @Test
    void losBordesTambienValenConOtrosValores() {
        VentanaAgendar ventana = ParametrosDePrueba.nuevo().agendar(4, 10).construir()
                .ventanaAgendar(AHORA);

        assertTrue(ventana.contiene(OffsetDateTime.parse("2026-10-20T12:00:00-03:00")));
        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-10-20T11:59:59-03:00")));
        assertTrue(ventana.contiene(OffsetDateTime.parse("2026-10-30T08:00:00-03:00")));
        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-10-30T08:00:01-03:00")));
        // Con los valores por defecto estos dos instantes serian validos.
        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-10-20T10:00:00-03:00")));
        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-11-15T08:00:00-03:00")));
    }

    @Test
    void elMaximoEsUnInstanteYNoElFinDeUnaFecha() {
        // Ahora a las 08:00: un numero a las 18:00 del dia treinta ya excede la ventana.
        VentanaAgendar ventana = ParametroService.porDefecto().ventanaAgendar(AHORA);

        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-11-19T18:00:00-03:00")));
    }

    @Test
    void comparaInstantesAunqueVenganEnOtroDesfase() {
        VentanaAgendar ventana = ParametroService.porDefecto().ventanaAgendar(AHORA);

        assertTrue(ventana.contiene(OffsetDateTime.parse("2026-10-20T13:00:00Z")));
        assertFalse(ventana.contiene(OffsetDateTime.parse("2026-10-20T12:59:59Z")));
    }
}
