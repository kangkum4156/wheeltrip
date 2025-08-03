library const_data;

// 로그인된 유저의 정보 전역 변수
String? user_email;
String? user_name;
String? user_phone;
String? user_mode;
String? user_counterEmail;
dynamic user_location; // null 또는 좌표
List<Map<String, dynamic>> user_savedPlaces = [];