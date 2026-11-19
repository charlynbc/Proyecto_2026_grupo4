package uy.edu.proyecto.backend.agenda;

/**
 * Cuerpo opcional de la cancelación del funcionario (RF-19). Sin cuerpo, o con
 * {@code aPedidoDelSocio} ausente, la cancelación es a pedido del socio. El
 * {@code motivo} solo cuenta cuando {@code aPedidoDelSocio} es {@code false}.
 */
public record CancelacionFuncionarioRequest(Boolean aPedidoDelSocio, String motivo) {

    public boolean esAPedidoDelSocio() {
        return aPedidoDelSocio == null || aPedidoDelSocio;
    }
}
