package uy.edu.proyecto.backend.config;

import java.util.ArrayList;
import java.util.LinkedHashMap;
import java.util.LinkedHashSet;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.regex.Pattern;

import org.slf4j.Logger;
import org.slf4j.LoggerFactory;
import org.springframework.beans.factory.annotation.Value;
import org.springframework.http.MediaType;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.RestController;

/**
 * Publica /.well-known/assetlinks.json, el archivo con el que Android verifica
 * que la app instalada es la duena del dominio (App Links): los enlaces de los
 * correos abren la app en vez del navegador.
 *
 * El paquete y las huellas SHA-256 de los certificados de firma salen de
 * propiedades (ANDROID_APP_PACKAGE_NAME y ANDROID_APP_FINGERPRINTS), asi se
 * agrega una huella sin recompilar la web. Las huellas son publicas: no son un
 * secreto. Sin ninguna huella valida la respuesta es la lista vacia.
 */
@RestController
public class AssetLinksController {

    private static final Logger LOG = LoggerFactory.getLogger(AssetLinksController.class);

    /** Treinta y dos pares hexadecimales separados por dos puntos. */
    private static final Pattern HUELLA_VALIDA = Pattern.compile("([0-9A-Fa-f]{2}:){31}[0-9A-Fa-f]{2}");

    private final String paquete;
    private final List<String> huellas;

    public AssetLinksController(
            @Value("${app.android.package-name}") String paquete,
            @Value("${app.android.sha256-fingerprints}") String huellas) {
        this.paquete = paquete;
        this.huellas = parsear(huellas);
    }

    @GetMapping(path = "/.well-known/assetlinks.json", produces = MediaType.APPLICATION_JSON_VALUE)
    public List<Map<String, Object>> assetLinks() {
        if (huellas.isEmpty()) {
            return List.of();
        }
        Map<String, Object> objetivo = new LinkedHashMap<>();
        objetivo.put("namespace", "android_app");
        objetivo.put("package_name", paquete);
        objetivo.put("sha256_cert_fingerprints", huellas);

        Map<String, Object> declaracion = new LinkedHashMap<>();
        declaracion.put("relation", List.of("delegate_permission/common.handle_all_urls"));
        declaracion.put("target", objetivo);
        return List.of(declaracion);
    }

    /**
     * Separa por coma, recorta, descarta lo vacio y lo que no tiene formato de
     * huella, pasa a mayusculas y quita repetidas conservando el orden. Del
     * aviso solo sale la cantidad descartada, nunca la huella.
     */
    private static List<String> parsear(String texto) {
        Set<String> validas = new LinkedHashSet<>();
        int descartadas = 0;
        for (String elemento : texto.split(",")) {
            String huella = elemento.trim();
            if (huella.isEmpty()) {
                continue;
            }
            if (HUELLA_VALIDA.matcher(huella).matches()) {
                validas.add(huella.toUpperCase(Locale.ROOT));
            } else {
                descartadas++;
            }
        }
        if (descartadas > 0) {
            LOG.warn("Se descartaron {} huellas de ANDROID_APP_FINGERPRINTS por no tener el formato esperado.", descartadas);
        }
        return new ArrayList<>(validas);
    }
}
