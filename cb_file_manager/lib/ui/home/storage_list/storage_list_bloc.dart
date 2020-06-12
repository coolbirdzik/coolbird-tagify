
import 'package:cb_file_manager/ui/home/storage_list/storage_list_event.dart';
import 'package:cb_file_manager/ui/home/storage_list/storage_list_state.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

class StorageListBloc extends Bloc<StorageListEvent, StorageListState> {

  @override
  StorageListState get initialState => StorageListState("/");

  @override
  Stream<StorageListState> mapEventToState(StorageListEvent event) {
    // TODO: implement mapEventToState
    throw UnimplementedError();
  }

}