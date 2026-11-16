package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import uy.edu.proyecto.backend.exception.ApiException;
import static org.junit.jupiter.api.Assertions.*;
import static org.mockito.Mockito.*;

class CarteleraServiceTest {
    private final CarteleraRepository repo=mock(CarteleraRepository.class);
    private final AnuncioService anuncios=mock(AnuncioService.class);
    private final AlmacenImagenes almacen=mock(AlmacenImagenes.class);
    private final CarteleraService service=new CarteleraService(repo,anuncios,almacen);

    @Test void guardarReemplazaLaSeleccionCompleta() {
        var posiciones=List.of(new AnuncioDTO.Posicion(1,1),new AnuncioDTO.Posicion(3,2));
        when(repo.existe(anyLong())).thenReturn(true);
        when(repo.posiciones()).thenReturn(posiciones);
        assertEquals(posiciones,service.guardar(new AnuncioDTO.Carrusel(posiciones)).posiciones());
        verify(repo).bloquearCambios();
        verify(repo).reemplazar(posiciones);
    }
    @Test void rechazaPosicionesDuplicadas() {
        when(repo.existe(anyLong())).thenReturn(true);
        var p=List.of(new AnuncioDTO.Posicion(1,1),new AnuncioDTO.Posicion(1,2));
        assertThrows(ApiException.class,()->service.guardar(new AnuncioDTO.Carrusel(p)));
        verify(repo,never()).reemplazar(any());
    }
    @Test void exigeFinYOrdenValido() {
        var inicio=OffsetDateTime.parse("2027-01-01T10:00:00-03:00");
        when(repo.publicadoEn(1)).thenReturn(inicio.minusDays(1));
        assertThrows(ApiException.class,()->service.vigencia(1,new AnuncioDTO.Vigencia(inicio,inicio)));
        assertThrows(ApiException.class,()->service.vigencia(1,new AnuncioDTO.Vigencia(inicio,null)));
        verify(repo,never()).vigencia(anyLong(),any());
    }
    @Test void falloDeStorageConservaLaCola() {
        when(repo.tomarPendiente()).thenReturn(new CarteleraRepository.Pendiente(4,"imagen.png"));
        doThrow(new IllegalStateException()).when(almacen).borrar("imagen.png");
        service.limpiarPendiente();
        verify(repo).fallido(4);
        verify(repo,never()).completado(anyLong());
    }
}
