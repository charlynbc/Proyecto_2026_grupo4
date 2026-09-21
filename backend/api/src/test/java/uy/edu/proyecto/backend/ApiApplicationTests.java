package uy.edu.proyecto.backend;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

@SpringBootTest
@TestPropertySource(properties = "app.firebase.enabled=false")
class ApiApplicationTests {

	@Test
	void contextLoads() {
	}

}
