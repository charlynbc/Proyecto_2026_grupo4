/// El rango que admite el calendario de las fechas de turnos (los filtros y la
/// vigencia del alta): amplio y sin restringirse al futuro, porque se consultan
/// turnos pasados y el servidor es quien decide qué altas acepta.
final DateTime kShiftDatePickerFirstDate = DateTime.utc(2000, 1, 1);
final DateTime kShiftDatePickerLastDate = DateTime.utc(2100, 12, 31);
