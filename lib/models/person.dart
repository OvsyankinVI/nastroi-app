import 'dart:convert';

enum MoodType { calm, happy, sad, irritated, tired, needsCare }

enum RelationType { me, partner, friend, parent, child, colleague, other }

enum SourceType { local, imported, friendRequestIncoming, friendRequestPending }

enum GenderType { male, female }

const Object _personFieldNotSet = Object();

class CycleStage {
  final String title;
  final MoodType mood;
  final int durationDays;
  final List<String> helpfulActions;
  final List<String> avoidActions;

  const CycleStage({
    required this.title,
    required this.mood,
    required this.durationDays,
    required this.helpfulActions,
    required this.avoidActions,
  });

  CycleStage copyWith({
    String? title,
    MoodType? mood,
    int? durationDays,
    List<String>? helpfulActions,
    List<String>? avoidActions,
  }) {
    return CycleStage(
      title: title ?? this.title,
      mood: mood ?? this.mood,
      durationDays: durationDays ?? this.durationDays,
      helpfulActions: helpfulActions ?? this.helpfulActions,
      avoidActions: avoidActions ?? this.avoidActions,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'mood': mood.name,
      'durationDays': durationDays,
      'helpfulActions': helpfulActions,
      'avoidActions': avoidActions,
    };
  }

  factory CycleStage.fromMap(Map<String, dynamic> map) {
    return CycleStage(
      title: map['title'] ?? '',
      mood: MoodType.values.firstWhere(
        (m) => m.name == map['mood'],
        orElse: () => MoodType.calm,
      ),
      durationDays: map['durationDays'] ?? 1,
      helpfulActions: List<String>.from(map['helpfulActions'] ?? []),
      avoidActions: List<String>.from(map['avoidActions'] ?? []),
    );
  }
}

class Person {
  final String id;
  final String publicId;
  final String name;
  final GenderType gender;
  final int avatarVariant;
  final MoodType mood;
  final List<String> helpfulActions;
  final List<String> avoidActions;
  final bool isPinned;
  final RelationType relationType;
  final SourceType sourceType;
  final String? customRelationLabel;

  final bool lifeCycleEnabled;
  final List<CycleStage> cycleStages;
  final String? cycleStartDateIso;

  final MoodType? manualMoodOverride;
  final String? manualMoodOverrideDateIso;

  const Person({
    required this.id,
    required this.publicId,
    required this.name,
    required this.gender,
    required this.avatarVariant,
    required this.mood,
    required this.helpfulActions,
    required this.avoidActions,
    this.isPinned = false,
    this.relationType = RelationType.other,
    this.sourceType = SourceType.local,
    this.customRelationLabel,
    this.lifeCycleEnabled = false,
    this.cycleStages = const [],
    this.cycleStartDateIso,
    this.manualMoodOverride,
    this.manualMoodOverrideDateIso,
  });

  Person copyWith({
    String? id,
    String? publicId,
    String? name,
    GenderType? gender,
    int? avatarVariant,
    MoodType? mood,
    List<String>? helpfulActions,
    List<String>? avoidActions,
    bool? isPinned,
    RelationType? relationType,
    SourceType? sourceType,
    Object? customRelationLabel = _personFieldNotSet,
    bool? lifeCycleEnabled,
    List<CycleStage>? cycleStages,
    Object? cycleStartDateIso = _personFieldNotSet,
    Object? manualMoodOverride = _personFieldNotSet,
    Object? manualMoodOverrideDateIso = _personFieldNotSet,
  }) {
    return Person(
      id: id ?? this.id,
      publicId: publicId ?? this.publicId,
      name: name ?? this.name,
      gender: gender ?? this.gender,
      avatarVariant: avatarVariant ?? this.avatarVariant,
      mood: mood ?? this.mood,
      helpfulActions: helpfulActions ?? this.helpfulActions,
      avoidActions: avoidActions ?? this.avoidActions,
      isPinned: isPinned ?? this.isPinned,
      relationType: relationType ?? this.relationType,
      sourceType: sourceType ?? this.sourceType,
      customRelationLabel: identical(customRelationLabel, _personFieldNotSet)
          ? this.customRelationLabel
          : customRelationLabel as String?,
      lifeCycleEnabled: lifeCycleEnabled ?? this.lifeCycleEnabled,
      cycleStages: cycleStages ?? this.cycleStages,
      cycleStartDateIso: identical(cycleStartDateIso, _personFieldNotSet)
          ? this.cycleStartDateIso
          : cycleStartDateIso as String?,
      manualMoodOverride: identical(manualMoodOverride, _personFieldNotSet)
          ? this.manualMoodOverride
          : manualMoodOverride as MoodType?,
      manualMoodOverrideDateIso:
          identical(manualMoodOverrideDateIso, _personFieldNotSet)
          ? this.manualMoodOverrideDateIso
          : manualMoodOverrideDateIso as String?,
    );
  }

  String get relationDisplayName {
    switch (relationType) {
      case RelationType.me:
        return 'Я';
      case RelationType.partner:
        return 'Партнёр';
      case RelationType.friend:
        return 'Друг';
      case RelationType.parent:
        return 'Родитель';
      case RelationType.child:
        return 'Ребёнок';
      case RelationType.colleague:
        return 'Коллега';
      case RelationType.other:
        final custom = customRelationLabel?.trim();
        if (custom != null && custom.isNotEmpty) {
          return custom;
        }
        return 'Другое';
    }
  }

  static DateTime _dateOnly(DateTime date) {
    return DateTime(date.year, date.month, date.day);
  }

  static String dateOnlyIso(DateTime date) {
    return _dateOnly(date).toIso8601String();
  }

  CycleStage? activeCycleStageForDate(DateTime date) {
    if (!lifeCycleEnabled || cycleStages.isEmpty) return null;

    final totalDays = cycleStages.fold<int>(
      0,
      (sum, stage) => sum + stage.durationDays,
    );

    if (totalDays <= 0) return null;

    final startDate = cycleStartDateIso != null
        ? DateTime.tryParse(cycleStartDateIso!)
        : null;

    final normalizedStart = _dateOnly(startDate ?? date);
    final normalizedDate = _dateOnly(date);

    final diff = normalizedDate.difference(normalizedStart).inDays;
    final safeDiff = diff < 0 ? 0 : diff;
    final dayIndex = safeDiff % totalDays;

    int passed = 0;
    for (final stage in cycleStages) {
      passed += stage.durationDays;
      if (dayIndex < passed) {
        return stage;
      }
    }

    return cycleStages.last;
  }

  Person applyLifeCycleForDate(DateTime date) {
    var updated = this;

    final stage = activeCycleStageForDate(date);
    if (stage != null) {
      updated = updated.copyWith(
        mood: stage.mood,
        helpfulActions: stage.helpfulActions,
        avoidActions: stage.avoidActions,
      );
    }

    if (manualMoodOverride != null && manualMoodOverrideDateIso != null) {
      final overrideDate = DateTime.tryParse(manualMoodOverrideDateIso!);
      if (overrideDate != null && _dateOnly(overrideDate) == _dateOnly(date)) {
        updated = updated.copyWith(mood: manualMoodOverride);
      }
    }

    return updated;
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'publicId': publicId,
      'name': name,
      'gender': gender.name,
      'avatarVariant': avatarVariant,
      'mood': mood.name,
      'helpfulActions': helpfulActions,
      'avoidActions': avoidActions,
      'isPinned': isPinned,
      'relationType': relationType.name,
      'sourceType': sourceType.name,
      'customRelationLabel': customRelationLabel,
      'lifeCycleEnabled': lifeCycleEnabled,
      'cycleStages': cycleStages.map((stage) => stage.toMap()).toList(),
      'cycleStartDateIso': cycleStartDateIso,
      'manualMoodOverride': manualMoodOverride?.name,
      'manualMoodOverrideDateIso': manualMoodOverrideDateIso,
    };
  }

  factory Person.fromMap(Map<String, dynamic> map) {
    return Person(
      id: map['id'] ?? '',
      publicId: map['publicId'] ?? map['id'] ?? '',
      name: map['name'] ?? '',
      gender: GenderType.values.firstWhere(
        (g) => g.name == map['gender'],
        orElse: () => GenderType.male,
      ),
      avatarVariant: map['avatarVariant'] is int ? map['avatarVariant'] : 0,
      mood: MoodType.values.firstWhere(
        (m) => m.name == map['mood'],
        orElse: () => MoodType.calm,
      ),
      helpfulActions: List<String>.from(map['helpfulActions'] ?? []),
      avoidActions: List<String>.from(map['avoidActions'] ?? []),
      isPinned: map['isPinned'] ?? false,
      relationType: RelationType.values.firstWhere(
        (r) => r.name == map['relationType'],
        orElse: () =>
            (map['id'] == 'me' ? RelationType.me : RelationType.other),
      ),
      sourceType: SourceType.values.firstWhere(
        (s) => s.name == map['sourceType'],
        orElse: () => SourceType.local,
      ),
      customRelationLabel: map['customRelationLabel'],
      lifeCycleEnabled: map['lifeCycleEnabled'] ?? false,
      cycleStages: (map['cycleStages'] as List<dynamic>? ?? [])
          .map((stage) => CycleStage.fromMap(Map<String, dynamic>.from(stage)))
          .toList(),
      cycleStartDateIso: map['cycleStartDateIso'],
      manualMoodOverride: map['manualMoodOverride'] != null
          ? MoodType.values.firstWhere(
              (m) => m.name == map['manualMoodOverride'],
              orElse: () => MoodType.calm,
            )
          : null,
      manualMoodOverrideDateIso: map['manualMoodOverrideDateIso'],
    );
  }

  String toJson() => jsonEncode(toMap());

  factory Person.fromJson(String source) {
    return Person.fromMap(jsonDecode(source) as Map<String, dynamic>);
  }

  String toExportCode() {
    final exportMap = {
      'publicId': publicId,
      'name': name,
      'gender': gender.name,
      'avatarVariant': avatarVariant,
      'mood': mood.name,
      'helpfulActions': helpfulActions,
      'avoidActions': avoidActions,
      'relationType': relationType.name,
      'customRelationLabel': customRelationLabel,
      'lifeCycleEnabled': lifeCycleEnabled,
      'cycleStages': cycleStages.map((stage) => stage.toMap()).toList(),
      'cycleStartDateIso': cycleStartDateIso,
    };

    final json = jsonEncode(exportMap);
    return base64Encode(utf8.encode(json));
  }

  factory Person.fromExportCode(String code) {
    final decodedJson = utf8.decode(base64Decode(code));
    final map = jsonDecode(decodedJson) as Map<String, dynamic>;

    return Person(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      publicId: map['publicId'] ?? '',
      name: map['name'] ?? '',
      gender: GenderType.values.firstWhere(
        (g) => g.name == map['gender'],
        orElse: () => GenderType.male,
      ),
      avatarVariant: map['avatarVariant'] is int ? map['avatarVariant'] : 0,
      mood: MoodType.values.firstWhere(
        (m) => m.name == map['mood'],
        orElse: () => MoodType.calm,
      ),
      helpfulActions: List<String>.from(map['helpfulActions'] ?? []),
      avoidActions: List<String>.from(map['avoidActions'] ?? []),
      relationType: RelationType.values.firstWhere(
        (r) => r.name == map['relationType'],
        orElse: () => RelationType.other,
      ),
      customRelationLabel: map['customRelationLabel'],
      sourceType: SourceType.imported,
      isPinned: false,
      lifeCycleEnabled: map['lifeCycleEnabled'] ?? false,
      cycleStages: (map['cycleStages'] as List<dynamic>? ?? [])
          .map((stage) => CycleStage.fromMap(Map<String, dynamic>.from(stage)))
          .toList(),
      cycleStartDateIso: map['cycleStartDateIso'],
    );
  }
}
