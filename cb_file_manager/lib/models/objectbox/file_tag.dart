import 'package:objectbox/objectbox.dart';
import '../../objectbox.g.dart';

/// Entity class for storing file tags in ObjectBox
@Entity()
class FileTag {
  /// Primary key ID
  @Id()
  int id = 0;

  /// Path to the file
  @Index()
  String filePath;

  /// Tag value
  @Index()
  String tag;

  /// Creates a new file tag
  FileTag({
    required this.filePath,
    required this.tag,
  });
}
