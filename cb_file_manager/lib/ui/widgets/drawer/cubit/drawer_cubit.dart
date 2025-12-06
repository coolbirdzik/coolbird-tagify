import 'dart:io';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:equatable/equatable.dart';
import 'package:cb_file_manager/helpers/core/filesystem_utils.dart';

// State
class DrawerState extends Equatable {
  final List<Directory> storageLocations;
  final bool isLoading;
  final String? error;

  const DrawerState({
    this.storageLocations = const [],
    this.isLoading = false,
    this.error,
  });

  DrawerState copyWith({
    List<Directory>? storageLocations,
    bool? isLoading,
    String? error,
  }) {
    return DrawerState(
      storageLocations: storageLocations ?? this.storageLocations,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  @override
  List<Object?> get props => [storageLocations, isLoading, error];
}

// Cubit
class DrawerCubit extends Cubit<DrawerState> {
  DrawerCubit() : super(const DrawerState());

  Future<void> loadStorageLocations() async {
    emit(state.copyWith(isLoading: true, error: null));
    try {
      final locations = await getAllStorageLocations();
      emit(state.copyWith(
        storageLocations: locations,
        isLoading: false,
      ));
    } catch (e) {
      emit(state.copyWith(
        isLoading: false,
        error: e.toString(),
      ));
    }
  }
}
