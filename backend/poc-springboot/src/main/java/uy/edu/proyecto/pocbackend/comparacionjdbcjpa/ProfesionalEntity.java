package uy.edu.proyecto.pocbackend.comparacionjdbcjpa;

import jakarta.persistence.Entity;
import jakarta.persistence.GeneratedValue;
import jakarta.persistence.GenerationType;
import jakarta.persistence.Id;
import jakarta.persistence.Table;

/**
 * Opcion B: entidad JPA equivalente a "POC".profesional, para la comparacion
 * JDBC vs JPA de la fase 4.
 *
 * NO esta activa: en application.properties se excluyo JpaRepositoriesAutoConfiguration
 * y HibernateJpaAutoConfiguration porque no hay datasource real configurado.
 * Esta clase y el repository de al lado quedan como referencia de codigo.
 */
@Entity
@Table(name = "profesional", schema = "POC")
public class ProfesionalEntity {

    @Id
    @GeneratedValue(strategy = GenerationType.IDENTITY)
    private Long id;

    private String nombre;

    protected ProfesionalEntity() {
        // constructor vacio requerido por JPA
    }

    public ProfesionalEntity(String nombre) {
        this.nombre = nombre;
    }

    public Long getId() {
        return id;
    }

    public String getNombre() {
        return nombre;
    }
}
