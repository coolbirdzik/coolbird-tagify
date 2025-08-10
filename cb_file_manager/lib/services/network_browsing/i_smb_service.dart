import 'package:cb_file_manager/services/network_browsing/network_service_base.dart';

abstract class ISmbService implements NetworkServiceBase {
  Future<String?> getSmbDirectLink(String tabPath);
}
