/// El ID de una consulta como lo muestra Mis consultas: el número de la
/// consulta con ceros a la izquierda hasta completar 6 dígitos (`9001` se ve
/// `009001`). Un número de más de 6 dígitos queda como está.
String formatAppointmentId(int id) => id.toString().padLeft(6, '0');
