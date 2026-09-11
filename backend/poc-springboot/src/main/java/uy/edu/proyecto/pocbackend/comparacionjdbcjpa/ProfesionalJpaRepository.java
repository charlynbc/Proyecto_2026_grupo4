package uy.edu.proyecto.pocbackend.comparacionjdbcjpa;

import org.springframework.data.jpa.repository.JpaRepository;

import java.util.List;

/**
 * Repository JPA para ProfesionalEntity (fase 4, comparacion JDBC vs JPA).
 * No se usa en runtime todavia: ver ProfesionalEntity para el motivo.
 *
 * A diferencia del DAO JDBC, aca no hace falta escribir el SQL: Spring Data
 * lo genera solo a partir del nombre del metodo.
 */
public interface ProfesionalJpaRepository extends JpaRepository<ProfesionalEntity, Long> {

    List<ProfesionalEntity> findAllByOrderByNombreAsc();
}

