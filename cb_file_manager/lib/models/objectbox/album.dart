import 'package:objectbox/objectbox.dart';
import '../../objectbox.g.dart';

/// Entity class for storing custom albums in ObjectBox
@Entity()
class Album {
  /// Primary key ID
  @Id()
  int id = 0;

  /// Album name
  @Index()
  String name;

  /// Album description (optional)
  String? description;

  /// Album cover image path (optional)
  String? coverImagePath;

  /// Creation timestamp
  DateTime createdAt;

  /// Last modified timestamp
  DateTime modifiedAt;

  /// Album color theme (hex color code, optional)
  String? colorTheme;

  /// Whether this is a system album or user-created
  bool isSystemAlbum;

  /// Creates a new album
  Album({
    required this.name,
    this.description,
    this.coverImagePath,
    DateTime? createdAt,
    DateTime? modifiedAt,
    this.colorTheme,
    this.isSystemAlbum = false,
  }) : createdAt = createdAt ?? DateTime.now(),
       modifiedAt = modifiedAt ?? DateTime.now();

  /// Updates the modified timestamp
  void updateModifiedTime() {
    modifiedAt = DateTime.now();
  }

  /// Creates a copy of this album with updated fields
  Album copyWith({
    String? name,
    String? description,
    String? coverImagePath,
    DateTime? createdAt,
    DateTime? modifiedAt,
    String? colorTheme,
    bool? isSystemAlbum,
  }) {
    return Album(
      name: name ?? this.name,
      description: description ?? this.description,
      coverImagePath: coverImagePath ?? this.coverImagePath,
      createdAt: createdAt ?? this.createdAt,
      modifiedAt: modifiedAt ?? this.modifiedAt,
      colorTheme: colorTheme ?? this.colorTheme,
      isSystemAlbum: isSystemAlbum ?? this.isSystemAlbum,
    )..id = id;
  }

  @override
  String toString() {
    return 'Album{id: $id, name: $name, description: $description, '
           'createdAt: $createdAt, modifiedAt: $modifiedAt, '
           'isSystemAlbum: $isSystemAlbum}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is Album &&
           other.id == id &&
           other.name == name &&
           other.description == description &&
           other.coverImagePath == coverImagePath &&
           other.createdAt == createdAt &&
           other.modifiedAt == modifiedAt &&
           other.colorTheme == colorTheme &&
           other.isSystemAlbum == isSystemAlbum;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      name,
      description,
      coverImagePath,
      createdAt,
      modifiedAt,
      colorTheme,
      isSystemAlbum,
    );
  }
}
