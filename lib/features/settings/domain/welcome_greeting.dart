/// Picks a Vietnamese welcome greeting for the given hour of day (0-23).
///
/// Boundaries follow common Vietnamese usage: sáng ends when trưa's midday
/// meal window starts, tối extends late since a car launcher greets whoever
/// starts the vehicle at night rather than assuming they're asleep.
String welcomeGreetingForHour(int hour) {
  if (hour >= 5 && hour < 11) {
    return 'Chào buổi sáng! Chúc bạn một ngày mới tốt lành và lái xe an toàn.';
  }
  if (hour >= 11 && hour < 13) {
    return 'Chào buổi trưa! Chúc bạn một chuyến đi thuận lợi.';
  }
  if (hour >= 13 && hour < 18) {
    return 'Chào buổi chiều! Chúc bạn lái xe an toàn.';
  }
  if (hour >= 18 && hour < 23) {
    return 'Chào buổi tối! Chúc bạn thượng lộ bình an.';
  }
  return 'Đã khuya rồi, chúc bạn lái xe cẩn thận.';
}
