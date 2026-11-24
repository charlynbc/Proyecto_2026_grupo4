package uy.edu.proyecto.backend.notificacion;

import java.util.List;
import java.util.Optional;
import java.util.concurrent.CopyOnWriteArrayList;

import org.junit.jupiter.api.BeforeEach;
import org.junit.jupiter.api.Test;
import org.junit.jupiter.api.extension.ExtendWith;
import org.mockito.Mockito;
import org.springframework.beans.factory.annotation.Autowired;
import org.springframework.context.ApplicationEventPublisher;
import org.springframework.context.annotation.Bean;
import org.springframework.context.annotation.Configuration;
import org.springframework.test.context.junit.jupiter.SpringExtension;
import org.springframework.test.context.ContextConfiguration;
import org.springframework.transaction.TransactionDefinition;
import org.springframework.transaction.annotation.EnableTransactionManagement;
import org.springframework.transaction.annotation.Transactional;
import org.springframework.transaction.support.AbstractPlatformTransactionManager;
import org.springframework.transaction.support.DefaultTransactionStatus;

import uy.edu.proyecto.backend.correo.CorreoException;
import uy.edu.proyecto.backend.correo.CorreoSender;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository;
import uy.edu.proyecto.backend.turno.TurnoFechasRepository.EnvioNotificacion;
import uy.edu.proyecto.backend.turno.TurnoFechasService.EnviosNotificacionSolicitados;

import static org.junit.jupiter.api.Assertions.assertDoesNotThrow;
import static org.junit.jupiter.api.Assertions.assertEquals;
import static org.junit.jupiter.api.Assertions.assertFalse;
import static org.junit.jupiter.api.Assertions.assertTrue;
import static org.mockito.ArgumentMatchers.any;
import static org.mockito.Mockito.doThrow;
import static org.mockito.Mockito.verify;
import static org.mockito.Mockito.when;

/**
 * RNF-24: una falla en el envio de una notificacion no impide ni revierte la
 * operacion que la origino. Usa el listener AFTER_COMMIT, el dispatcher y una
 * operacion transaccional reales, con un gestor de transacciones de prueba que
 * anota cada begin, commit y rollback (sin base de datos).
 */
@ExtendWith(SpringExtension.class)
@ContextConfiguration(classes = EntregaNoRevierteOperacionTest.Configuracion.class)
class EntregaNoRevierteOperacionTest {

    @Autowired
    private OperacionDePrueba operacion;

    @Autowired
    private GestorDeTransaccionesDePrueba gestor;

    @Autowired
    private TurnoFechasRepository repository;

    @Autowired
    private CorreoSender correoSender;

    @BeforeEach
    void limpiar() {
        Mockito.reset(repository, correoSender);
        gestor.eventos.clear();
    }

    private static EnvioNotificacion envioDeCorreo(long id) {
        return new EnvioNotificacion(
                id, 700L + id, "CANCELACION", "CORREO", "socio@example.com", null,
                "Tu consulta fue cancelada.",
                java.time.LocalDate.of(2026, 10, 21),
                java.time.LocalTime.of(9, 0),
                java.time.LocalTime.of(9, 20),
                "Cardiología",
                "Socio",
                null
        );
    }

    @Test
    void unaFallaCualquieraDelCorreoNoRevierteLaOperacionNiLlegaAQuienOpera() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.of(envioDeCorreo(601L)));
        doThrow(new UnsupportedOperationException("proveedor caido"))
                .when(correoSender).enviar(any());
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        String resultado = assertDoesNotThrow(() -> operacion.operar(List.of(601L)));

        assertEquals("operacion confirmada", resultado);
        verify(repository).marcarEnvio(601L, "FALLIDO");
        assertEquals(List.of("begin", "commit", "begin", "commit"), gestor.eventos);
    }

    @Test
    void unaFallaDelProveedorDeCorreoConocidaTampocoRevierteLaOperacion() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.of(envioDeCorreo(601L)));
        doThrow(new CorreoException("sin proveedor")).when(correoSender).enviar(any());
        when(repository.marcarEnvio(601L, "FALLIDO")).thenReturn(1);

        String resultado = assertDoesNotThrow(() -> operacion.operar(List.of(601L)));

        assertEquals("operacion confirmada", resultado);
        verify(repository).marcarEnvio(601L, "FALLIDO");
        assertFalse(gestor.eventos.contains("rollback"));
    }

    @Test
    void siNoSePuedeAnotarElEstadoLaOperacionIgualQuedaConfirmada() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.of(envioDeCorreo(601L)));
        when(repository.marcarEnvio(601L, "ENVIADO")).thenReturn(0);

        String resultado = assertDoesNotThrow(() -> operacion.operar(List.of(601L)));

        assertEquals("operacion confirmada", resultado);
        assertEquals("begin", gestor.eventos.getFirst());
        assertEquals("commit", gestor.eventos.get(1));
    }

    @Test
    void unEnvioQueFallaNoImpideEntregarLosSiguientes() {
        when(repository.buscarEnvio(601L)).thenThrow(new IllegalStateException("base caida"));
        when(repository.buscarEnvio(602L)).thenReturn(Optional.of(envioDeCorreo(602L)));
        when(repository.marcarEnvio(602L, "ENVIADO")).thenReturn(1);

        assertDoesNotThrow(() -> operacion.operar(List.of(601L, 602L)));

        verify(repository).marcarEnvio(602L, "ENVIADO");
    }

    @Test
    void sinFallasLaOperacionYLaEntregaSeConfirman() {
        when(repository.buscarEnvio(601L)).thenReturn(Optional.of(envioDeCorreo(601L)));
        when(repository.marcarEnvio(601L, "ENVIADO")).thenReturn(1);

        assertDoesNotThrow(() -> operacion.operar(List.of(601L)));

        assertTrue(gestor.eventos.stream().noneMatch("rollback"::equals));
        verify(correoSender).enviar(any());
    }

    /** Operacion de negocio: publica el pedido de entrega dentro de su transaccion. */
    static class OperacionDePrueba {

        private final ApplicationEventPublisher events;

        OperacionDePrueba(ApplicationEventPublisher events) {
            this.events = events;
        }

        @Transactional
        public String operar(List<Long> envioIds) {
            events.publishEvent(new EnviosNotificacionSolicitados(List.copyOf(envioIds)));
            return "operacion confirmada";
        }
    }

    /** Gestor sin base de datos: anota begin, commit y rollback, con soporte de REQUIRES_NEW. */
    static class GestorDeTransaccionesDePrueba extends AbstractPlatformTransactionManager {

        final List<String> eventos = new CopyOnWriteArrayList<>();
        private final ThreadLocal<Boolean> activa = ThreadLocal.withInitial(() -> false);

        @Override
        protected Object doGetTransaction() {
            return activa.get();
        }

        @Override
        protected boolean isExistingTransaction(Object transaction) {
            return Boolean.TRUE.equals(transaction);
        }

        @Override
        protected void doBegin(Object transaction, TransactionDefinition definition) {
            activa.set(true);
            eventos.add("begin");
        }

        @Override
        protected Object doSuspend(Object transaction) {
            activa.set(false);
            return transaction;
        }

        @Override
        protected void doResume(Object transaction, Object suspendedResources) {
            activa.set(true);
        }

        @Override
        protected void doCommit(DefaultTransactionStatus status) {
            eventos.add("commit");
        }

        @Override
        protected void doRollback(DefaultTransactionStatus status) {
            eventos.add("rollback");
        }

        @Override
        protected void doCleanupAfterCompletion(Object transaction) {
            activa.set(false);
        }
    }

    @Configuration
    @EnableTransactionManagement
    static class Configuracion {

        @Bean
        GestorDeTransaccionesDePrueba transactionManager() {
            return new GestorDeTransaccionesDePrueba();
        }

        @Bean
        TurnoFechasRepository turnoFechasRepository() {
            return Mockito.mock(TurnoFechasRepository.class);
        }

        @Bean
        CorreoSender correoSender() {
            return Mockito.mock(CorreoSender.class);
        }

        @Bean
        PushSender pushSender() {
            return Mockito.mock(PushSender.class);
        }

        @Bean
        EnvioNotificacionDispatcher dispatcher(
                TurnoFechasRepository repository,
                CorreoSender correoSender,
                PushSender pushSender
        ) {
            return new EnvioNotificacionDispatcher(
                    repository, correoSender, pushSender,
                    java.time.Clock.system(java.time.ZoneId.of("America/Montevideo")));
        }

        @Bean
        EnvioNotificacionListener listener(EnvioNotificacionDispatcher dispatcher) {
            return new EnvioNotificacionListener(dispatcher);
        }

        @Bean
        OperacionDePrueba operacion(ApplicationEventPublisher events) {
            return new OperacionDePrueba(events);
        }
    }
}
