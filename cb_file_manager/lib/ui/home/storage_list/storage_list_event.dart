
import 'package:equatable/equatable.dart';
import 'package:simple_permissions/simple_permissions.dart';

abstract class StorageListEvent extends Equatable {
  const StorageListEvent();

  @override
  List<Object> get props => [];
}

class StorageListInit extends StorageListEvent {
  const StorageListInit();
}