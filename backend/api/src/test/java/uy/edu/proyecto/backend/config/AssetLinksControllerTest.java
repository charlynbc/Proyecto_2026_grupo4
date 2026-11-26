package uy.edu.proyecto.backend.config;

import static org.springframework.test.web.servlet.request.MockMvcRequestBuilders.get;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.content;
import static org.springframework.test.web.servlet.result.MockMvcResultMatchers.status;

import org.junit.jupiter.api.Test;
import org.springframework.http.MediaType;
import org.springframework.test.web.servlet.MockMvc;
import org.springframework.test.web.servlet.setup.MockMvcBuilders;

/**
 * El cuerpo de /.well-known/assetlinks.json y el parseo de la lista de huellas.
 * Sin seguridad ni Spring: el controlador se arma a mano con el paquete y el
 * texto de las huellas. Todos los cuerpos esperados estan escritos a mano.
 */
class AssetLinksControllerTest {

    private static final String PAQUETE = "uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica";

    private static final String HUELLA_A =
            "01:AC:05:8D:AC:C7:69:7C:34:98:6D:2D:8A:68:D6:D7:51:F7:F4:B3:0C:69:CB:11:0C:0C:88:8D:23:20:4F:0C";

    private static final String HUELLA_B =
            "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

    private static final String HUELLA_B_MINUSCULAS =
            "aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99:aa:bb:cc:dd:ee:ff:00:11:22:33:44:55:66:77:88:99";

    /** Treinta y un pares en vez de treinta y dos. */
    private static final String HUELLA_CORTA =
            "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88";

    /** Treinta y tres pares. */
    private static final String HUELLA_LARGA =
            "AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA";

    /** Una G no es hexadecimal. */
    private static final String HUELLA_NO_HEX =
            "GG:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99:AA:BB:CC:DD:EE:FF:00:11:22:33:44:55:66:77:88:99";

    /** Los mismos 64 digitos pero sin los dos puntos. */
    private static final String HUELLA_SIN_DOS_PUNTOS =
            "AABBCCDDEEFF00112233445566778899AABBCCDDEEFF00112233445566778899";

    private static final String ANTES =
            "[{\"relation\":[\"delegate_permission/common.handle_all_urls\"],"
                    + "\"target\":{\"namespace\":\"android_app\","
                    + "\"package_name\":\"uy.edu.fing.tecnoinf.mvd.a2026_sem2_grupo4.agenda_medica\","
                    + "\"sha256_cert_fingerprints\":[";

    private static final String DESPUES = "]}}]";

    private static final String HUELLA_A_JSON = "\"" + HUELLA_A + "\"";

    private static final String HUELLA_B_JSON = "\"" + HUELLA_B + "\"";

    private MockMvc con(String huellas) {
        return MockMvcBuilders.standaloneSetup(new AssetLinksController(PAQUETE, huellas)).build();
    }

    private void esperar(String huellas, String cuerpo) throws Exception {
        con(huellas).perform(get("/.well-known/assetlinks.json"))
                .andExpect(status().isOk())
                .andExpect(content().contentTypeCompatibleWith(MediaType.APPLICATION_JSON))
                .andExpect(content().string(cuerpo));
    }

    @Test
    void unaHuellaDaLaDeclaracionExacta() throws Exception {
        esperar(HUELLA_A, ANTES + HUELLA_A_JSON + DESPUES);
    }

    @Test
    void dosHuellasSeparadasPorComaYEspaciosSalenEnOrden() throws Exception {
        esperar(HUELLA_A + " ,  " + HUELLA_B, ANTES + HUELLA_A_JSON + "," + HUELLA_B_JSON + DESPUES);
    }

    @Test
    void losEspaciosDeLosExtremosDeCadaHuellaSeRecortan() throws Exception {
        esperar("   " + HUELLA_A + "   ,   " + HUELLA_B + "  ",
                ANTES + HUELLA_A_JSON + "," + HUELLA_B_JSON + DESPUES);
    }

    @Test
    void losElementosVaciosSeDescartan() throws Exception {
        esperar(",," + HUELLA_A + ", ,," + HUELLA_B + ",", ANTES + HUELLA_A_JSON + "," + HUELLA_B_JSON + DESPUES);
    }

    @Test
    void lasHuellasRepetidasSalenUnaVezConservandoElOrden() throws Exception {
        esperar(HUELLA_B + "," + HUELLA_A + "," + HUELLA_B + "," + HUELLA_A,
                ANTES + HUELLA_B_JSON + "," + HUELLA_A_JSON + DESPUES);
    }

    @Test
    void unaHuellaEnMinusculasSeNormalizaAMayusculas() throws Exception {
        esperar(HUELLA_B_MINUSCULAS, ANTES + HUELLA_B_JSON + DESPUES);
    }

    @Test
    void unaHuellaEnMinusculasYOtraIgualEnMayusculasSonLaMisma() throws Exception {
        esperar(HUELLA_B_MINUSCULAS + "," + HUELLA_B, ANTES + HUELLA_B_JSON + DESPUES);
    }

    @Test
    void laHuellaConMenosParesSeDescartaYLasValidasQuedan() throws Exception {
        esperar(HUELLA_CORTA + "," + HUELLA_A, ANTES + HUELLA_A_JSON + DESPUES);
    }

    @Test
    void laHuellaConMasParesSeDescarta() throws Exception {
        esperar(HUELLA_A + "," + HUELLA_LARGA, ANTES + HUELLA_A_JSON + DESPUES);
    }

    @Test
    void laHuellaNoHexadecimalSeDescarta() throws Exception {
        esperar(HUELLA_NO_HEX + "," + HUELLA_B, ANTES + HUELLA_B_JSON + DESPUES);
    }

    @Test
    void laHuellaSinDosPuntosSeDescarta() throws Exception {
        esperar(HUELLA_SIN_DOS_PUNTOS + "," + HUELLA_A, ANTES + HUELLA_A_JSON + DESPUES);
    }

    @Test
    void sinHuellasLaListaEsVaciaYElEstadoEs200() throws Exception {
        esperar("", "[]");
    }

    @Test
    void conSoloEspaciosYComasLaListaEsVacia() throws Exception {
        esperar(" , ,, ", "[]");
    }

    @Test
    void conTodasLasHuellasInvalidasLaListaEsVacia() throws Exception {
        esperar(HUELLA_CORTA + "," + HUELLA_NO_HEX, "[]");
    }
}
