import 'package:flutter_test/flutter_test.dart';
import 'package:nastroi_app/data/people_repository.dart';
import 'package:nastroi_app/models/person.dart';
import 'package:shared_preferences/shared_preferences.dart';

Person person(String id, SourceType sourceType) => Person(
  id: id,
  publicId: id,
  name: id,
  gender: GenderType.male,
  avatarVariant: 0,
  mood: MoodType.calm,
  helpfulActions: const [],
  avoidActions: const [],
  sourceType: sourceType,
);

void main() {
  test('friend request placeholders are not persisted', () async {
    SharedPreferences.setMockInitialValues({});
    final repository = PeopleRepository(userId: 'test');
    await repository.savePeople([
      person('real', SourceType.imported),
      person('request_1', SourceType.friendRequestIncoming),
      person('request_2', SourceType.friendRequestPending),
    ]);

    final loaded = await repository.loadPeople();
    expect(loaded.map((item) => item.id), ['real']);
  });
}
