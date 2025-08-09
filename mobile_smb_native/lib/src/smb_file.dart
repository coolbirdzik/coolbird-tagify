/// Represents a file or directory in an SMB share
class SmbFile {
  /// The name of the file or directory
  final String name;
  
  /// The full path of the file or directory
  final String path;
  
  /// Whether this is a directory
  final bool isDirectory;
  
  /// File size in bytes (0 for directories)
  final int size;
  
  /// Last modified timestamp
  final DateTime? lastModified;
  
  /// Whether the file is hidden
  final bool isHidden;
  
  /// File permissions (if available)
  final String? permissions;

  const SmbFile({
    required this.name,
    required this.path,
    required this.isDirectory,
    required this.size,
    this.lastModified,
    this.isHidden = false,
    this.permissions,
  });

  /// Creates an SmbFile from a map (typically from platform channel)
  factory SmbFile.fromMap(Map<String, dynamic> map) {
    return SmbFile(
      name: map['name'] as String,
      path: map['path'] as String,
      isDirectory: map['isDirectory'] as bool,
      size: map['size'] as int,
      lastModified: map['lastModified'] != null 
          ? DateTime.fromMillisecondsSinceEpoch(map['lastModified'] as int)
          : null,
      isHidden: map['isHidden'] as bool? ?? false,
      permissions: map['permissions'] as String?,
    );
  }

  /// Converts this SmbFile to a map
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'path': path,
      'isDirectory': isDirectory,
      'size': size,
      'lastModified': lastModified?.millisecondsSinceEpoch,
      'isHidden': isHidden,
      'permissions': permissions,
    };
  }

  @override
  String toString() {
    return 'SmbFile(name: $name, path: $path, isDirectory: $isDirectory, size: $size)';
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SmbFile &&
        other.name == name &&
        other.path == path &&
        other.isDirectory == isDirectory &&
        other.size == size;
  }

  @override
  int get hashCode {
    return name.hashCode ^
        path.hashCode ^
        isDirectory.hashCode ^
        size.hashCode;
  }
}