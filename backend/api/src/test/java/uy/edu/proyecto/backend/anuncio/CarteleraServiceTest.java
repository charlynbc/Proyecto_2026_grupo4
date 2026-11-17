package uy.edu.proyecto.backend.anuncio;

import java.time.OffsetDateTime;
import java.util.List;
import org.junit.jupiter.api.Test;
import org.springframework.http.HttpStatus;
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

    private static final OffsetDateTime PUBLICADO=OffsetDateTime.parse("2026-11-01T10:00:00-03:00");
    private static final List<AnuncioDTO.Imagen> IMAGENES=List.of(new AnuncioDTO.Imagen(101,0,"https://storage.example/101"));

    private void anuncio(long id,String estado,OffsetDateTime desde,OffsetDateTime hasta,Integer posicion) {
        when(repo.administracion(id)).thenReturn(new AnuncioDTO.Administracion(id,"Vacunacion",PUBLICADO,desde,hasta,estado,posicion));
        when(anuncios.detalleCualquiera(id)).thenReturn(new AnuncioDTO.Detalle(id,"Vacunacion","Resumen corto","**Texto** largo",PUBLICADO,IMAGENES));
    }
    @Test void detalleDeUnaVigenteTrae() {
        var hasta=OffsetDateTime.parse("2026-12-01T00:00:00-03:00");
        anuncio(7,"VIGENTE",null,hasta,2);
        var d=service.detalle(7);
        assertEquals(7,d.id());
        assertEquals("Vacunacion",d.titulo());
        assertEquals("Resumen corto",d.resumen());
        assertEquals("**Texto** largo",d.texto());
        assertEquals(PUBLICADO,d.publicadoEn());
        assertNull(d.vigenteDesde());
        assertEquals(hasta,d.vigenteHasta());
        assertEquals("VIGENTE",d.estado());
        assertEquals(2,d.posicion());
        assertEquals(IMAGENES,d.imagenes());
    }
    @Test void detalleDeUnaProgramadaTrae() {
        var desde=OffsetDateTime.parse("2027-01-10T00:00:00-03:00");
        var hasta=OffsetDateTime.parse("2027-02-10T00:00:00-03:00");
        anuncio(8,"PROGRAMADO",desde,hasta,null);
        var d=service.detalle(8);
        assertEquals("PROGRAMADO",d.estado());
        assertEquals(desde,d.vigenteDesde());
        assertEquals(hasta,d.vigenteHasta());
        assertNull(d.posicion());
        assertEquals("**Texto** largo",d.texto());
        assertEquals(IMAGENES,d.imagenes());
    }
    @Test void detalleDeUnaVencidaTrae() {
        var hasta=OffsetDateTime.parse("2026-11-10T00:00:00-03:00");
        anuncio(9,"VENCIDO",null,hasta,null);
        var d=service.detalle(9);
        assertEquals("VENCIDO",d.estado());
        assertNull(d.vigenteDesde());
        assertEquals(hasta,d.vigenteHasta());
        assertEquals("Resumen corto",d.resumen());
        assertEquals("**Texto** largo",d.texto());
        assertEquals(IMAGENES,d.imagenes());
    }
    @Test void detalleInexistenteEs404() {
        when(repo.administracion(99)).thenReturn(null);
        var ex=assertThrows(ApiException.class,()->service.detalle(99));
        assertEquals(HttpStatus.NOT_FOUND,ex.getStatus());
        assertEquals("NO_ENCONTRADO",ex.getCode());
        verify(anuncios,never()).detalleCualquiera(anyLong());
    }
}
