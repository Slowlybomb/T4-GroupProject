import '../models/activity_dto.dart';
import '../models/create_activity_request_dto.dart';

abstract class ActivityApiRepository {
  Future<List<ActivityDto>> listActivities();

  Future<ActivityDto> createActivity(CreateActivityRequestDto request);

  Future<ActivityDto> getActivityById(String id);

  Future<ActivityDto> likeActivity(String id);
}
