import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'schedule_repository.g.dart';

// Legacy Schedule Class Dummy
class CourseSchedule {
  final int id;
  final String title;
  final String trainer;
  final int weekday;
  final int startHour;
  final int startMinute;
  final int durationMinutes;
  final String location;

  CourseSchedule({
    required this.id,
    required this.title,
    required this.trainer,
    required this.weekday,
    required this.startHour,
    required this.startMinute,
    required this.durationMinutes,
    required this.location,
  });
}

class CourseScheduleWithDetails {
  final CourseSchedule schedule;
  final String trainerName;
  final String courseTypeName;
  final String locationName;

  CourseScheduleWithDetails({
    required this.schedule,
    required this.trainerName,
    required this.courseTypeName,
    required this.locationName,
  });
}

@riverpod
Stream<List<CourseScheduleWithDetails>> scheduleStream(Ref ref) async* {
  yield [];
}

class ScheduleRepository {
  Future<void> addSchedule(dynamic companion) async {}
  Future<void> updateSchedule(CourseSchedule schedule) async {}
  Future<void> deleteSchedule(int id) async {}
}

@riverpod
ScheduleRepository scheduleRepository(Ref ref) {
  return ScheduleRepository();
}
