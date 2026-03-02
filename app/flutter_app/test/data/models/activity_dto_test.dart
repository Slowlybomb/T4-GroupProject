import 'package:flutter_test/flutter_test.dart';
import 'package:gondolier/data/models/activity_dto.dart';

void main() {
  group('ActivityDto', () {
    test('parses nullable fields safely and maps to ActivityModel', () {
      final dto = ActivityDto.fromJson({
        'id': 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa',
        'user_id': '11111111-1111-1111-1111-111111111111',
        'title': 'Morning row',
        'notes': null,
        'start_time': '2026-01-01T10:00:00Z',
        'duration_seconds': 3720,
        'distance_m': 10000,
        'avg_split_500m_seconds': 120,
        'avg_stroke_spm': 26,
        'visibility': 'public',
        'team_id': null,
        'route_geojson': null,
        'likes': 4,
        'comments': 1,
        'created_at': '2026-01-01T11:00:00Z',
      });

      final model = dto.toActivityModel();

      expect(dto.id, 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa');
      expect(dto.notes, isNull);
      expect(model.title, 'Morning row');
      expect(model.distance, '10.0 km');
      expect(model.duration, '1h 2m');
      expect(model.avgSplit, '2:00');
      expect(model.strokeRate, '26 s/m');
      expect(model.likes, 4);
    });

    test('throws FormatException when required fields are missing', () {
      expect(
        () => ActivityDto.fromJson({
          'id': '',
          'user_id': '11111111-1111-1111-1111-111111111111',
          'start_time': '2026-01-01T10:00:00Z',
          'visibility': 'public',
          'created_at': '2026-01-01T11:00:00Z',
        }),
        throwsFormatException,
      );
    });
  });
}
