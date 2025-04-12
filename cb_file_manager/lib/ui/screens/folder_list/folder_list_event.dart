import 'package:equatable/equatable.dart';
import 'folder_list_state.dart'; // Import for ViewMode and SortOption enums

abstract class FolderListEvent extends Equatable {
  const FolderListEvent();

  @override
  List<Object?> get props => [];
}

class FolderListInit extends FolderListEvent {
  const FolderListInit();
}

class FolderListLoad extends FolderListEvent {
  final String path;

  const FolderListLoad(this.path);

  @override
  List<Object> get props => [path];
}

class FolderListFilter extends FolderListEvent {
  final String? fileType;

  const FolderListFilter(this.fileType);

  @override
  List<Object?> get props => [fileType];
}

class AddTagToFile extends FolderListEvent {
  final String filePath;
  final String tag;

  const AddTagToFile(this.filePath, this.tag);

  @override
  List<Object> get props => [filePath, tag];
}

class RemoveTagFromFile extends FolderListEvent {
  final String filePath;
  final String tag;

  const RemoveTagFromFile(this.filePath, this.tag);

  @override
  List<Object> get props => [filePath, tag];
}

class SearchByTag extends FolderListEvent {
  final String tag;

  const SearchByTag(this.tag);

  @override
  List<Object> get props => [tag];
}

class SearchByTagGlobally extends FolderListEvent {
  final String tag;

  const SearchByTagGlobally(this.tag);

  @override
  List<Object> get props => [tag];
}

class SearchByFileName extends FolderListEvent {
  final String query;
  final bool recursive;

  const SearchByFileName(this.query, {this.recursive = false});

  @override
  List<Object> get props => [query, recursive];
}

class SearchMediaFiles extends FolderListEvent {
  final MediaSearchType mediaType;
  final bool recursive;

  const SearchMediaFiles(this.mediaType, {this.recursive = false});

  @override
  List<Object> get props => [mediaType, recursive];
}

class LoadTagsFromFile extends FolderListEvent {
  final String filePath;

  const LoadTagsFromFile(this.filePath);

  @override
  List<Object> get props => [filePath];
}

class LoadAllTags extends FolderListEvent {
  final String directory;

  const LoadAllTags(this.directory);

  @override
  List<Object> get props => [directory];
}

class SetViewMode extends FolderListEvent {
  final ViewMode viewMode;

  const SetViewMode(this.viewMode);

  @override
  List<Object> get props => [viewMode];
}

class SetSortOption extends FolderListEvent {
  final SortOption sortOption;

  const SetSortOption(this.sortOption);

  @override
  List<Object> get props => [sortOption];
}

class SetGridZoom extends FolderListEvent {
  final int zoomLevel;

  const SetGridZoom(this.zoomLevel);

  @override
  List<Object> get props => [zoomLevel];
}

class FolderListDeleteFiles extends FolderListEvent {
  final List<String> filePaths;

  const FolderListDeleteFiles(this.filePaths);

  @override
  List<Object> get props => [filePaths];
}

class FolderListBatchAddTag extends FolderListEvent {
  final List<String> filePaths;
  final String tag;

  const FolderListBatchAddTag(this.filePaths, this.tag);

  @override
  List<Object> get props => [filePaths, tag];
}

class FolderListDeleteTagGlobally extends FolderListEvent {
  final String tag;

  const FolderListDeleteTagGlobally(this.tag);

  @override
  List<Object> get props => [tag];
}

// Enum to represent media types for search
enum MediaSearchType { images, videos, audio, all }
