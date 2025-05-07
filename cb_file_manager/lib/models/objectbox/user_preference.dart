import 'package:objectbox/objectbox.dart';

/// Types of preferences that can be stored
enum PreferenceType { string, integer, double, boolean }

/// UserPreference entity for storing preferences in ObjectBox
@Entity()
class UserPreference {
  /// ID of the entity, managed by ObjectBox
  int id;

  /// Key of the preference
  @Index()
  @Unique()
  final String key;

  /// String value
  String? stringValue;

  /// Integer value
  int? intValue;

  /// Double value
  double? doubleValue;

  /// Boolean value
  bool? boolValue;

  /// Type value for database storage
  @Property(type: PropertyType.int)
  int typeValue;

  /// Getter and setter for `type` field
  @Transient()
  PreferenceType get type => PreferenceType.values[typeValue];
  @Transient()
  set type(PreferenceType value) => typeValue = value.index;

  /// Last modified timestamp
  final int timestamp;

  /// Updated default constructor for ObjectBox
  UserPreference({
    this.id = 0,
    required this.key,
    this.stringValue,
    this.intValue,
    this.doubleValue,
    this.boolValue,
    required this.typeValue,
    int? timestamp,
  }) : timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Constructor for string preference
  UserPreference.string({
    this.id = 0,
    required this.key,
    required String value,
    int? timestamp,
  })  : stringValue = value,
        intValue = null,
        doubleValue = null,
        boolValue = null,
        typeValue = PreferenceType.string.index,
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Constructor for integer preference
  UserPreference.integer({
    this.id = 0,
    required this.key,
    required int value,
    int? timestamp,
  })  : stringValue = null,
        intValue = value,
        doubleValue = null,
        boolValue = null,
        typeValue = PreferenceType.integer.index,
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Constructor for double preference
  UserPreference.double({
    this.id = 0,
    required this.key,
    required double value,
    int? timestamp,
  })  : stringValue = null,
        intValue = null,
        doubleValue = value,
        boolValue = null,
        typeValue = PreferenceType.double.index,
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  /// Constructor for boolean preference
  UserPreference.boolean({
    this.id = 0,
    required this.key,
    required bool value,
    int? timestamp,
  })  : stringValue = null,
        intValue = null,
        doubleValue = null,
        boolValue = value,
        typeValue = PreferenceType.boolean.index,
        timestamp = timestamp ?? DateTime.now().millisecondsSinceEpoch;

  @override
  String toString() {
    switch (type) {
      case PreferenceType.string:
        return 'UserPreference{key: $key, value: $stringValue, type: string}';
      case PreferenceType.integer:
        return 'UserPreference{key: $key, value: $intValue, type: integer}';
      case PreferenceType.double:
        return 'UserPreference{key: $key, value: $doubleValue, type: double}';
      case PreferenceType.boolean:
        return 'UserPreference{key: $key, value: $boolValue, type: boolean}';
    }
  }
}
