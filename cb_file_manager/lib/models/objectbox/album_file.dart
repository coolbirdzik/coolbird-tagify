import 'package:objectbox/objectbox.dart';
import '../../objectbox.g.dart';

/// Entity class for storing album-file associations in ObjectBox
@Entity()
class AlbumFile {
  /// Primary key ID
  @Id()
  int id = 0;

  /// Album ID reference
  @Index()
  int albumId;

  /// Path to the file
  @Index()
  String filePath;

  /// Order/position of the file within the album
  int orderIndex;

  /// Timestamp when file was added to album
  DateTime addedAt;

  /// Optional custom caption for this file in the album
  String? caption;

  /// Whether this file is marked as album cover
  bool isCover;

  /// Creates a new album-file association
  AlbumFile({
    required this.albumId,
    required this.filePath,
    this.orderIndex = 0,
    DateTime? addedAt,
    this.caption,
    this.isCover = false,
  }) : addedAt = addedAt ?? DateTime.now();

  /// Creates a copy of this album file with updated fields
  AlbumFile copyWith({
    int? albumId,
    String? filePath,
    int? orderIndex,
    DateTime? addedAt,
    String? caption,
    bool? isCover,
  }) {
    return AlbumFile(
      albumId: albumId ?? this.albumId,
      filePath: filePath ?? this.filePath,
      orderIndex: orderIndex ?? this.orderIndex,
      addedAt: addedAt ?? this.addedAt,
      caption: caption ?? this.caption,
      isCover: isCover ?? this.isCover,
    )..id = id;
  }

  @override
  String toString() {
    return 'AlbumFile{id: $id, albumId: $albumId, filePath: $filePath, '
           'orderIndex: $orderIndex, addedAt: $addedAt, '
           'caption: $caption, isCover: $isCover}';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is AlbumFile &&
           other.id == id &&
           other.albumId == albumId &&
           other.filePath == filePath &&
           other.orderIndex == orderIndex &&
           other.addedAt == addedAt &&
           other.caption == caption &&
           other.isCover == isCover;
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      albumId,
      filePath,
      orderIndex,
      addedAt,
      caption,
      isCover,
    );
  }
}
