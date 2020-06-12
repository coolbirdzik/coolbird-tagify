
import 'dart:io';

import 'package:equatable/equatable.dart';

class StorageListState extends Equatable {
  final Directory _currentPath;
  final List<dynamic> folders = [];
  final List<dynamic> subFolders = [];

  StorageListState(String currentPath) : this._currentPath = new Directory(currentPath);

  @override
  List<Object> get props => [_currentPath];

}