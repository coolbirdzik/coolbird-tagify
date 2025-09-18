import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../services/permission_state_service.dart';

class PermissionExplainerScreen extends StatefulWidget {
  const PermissionExplainerScreen({Key? key}) : super(key: key);

  @override
  State<PermissionExplainerScreen> createState() =>
      _PermissionExplainerScreenState();
}

class _PermissionExplainerScreenState extends State<PermissionExplainerScreen> {
  bool _checking = true;
  bool _hasStorage = false;
  bool _hasLocalNet = true; // default true except iOS
  bool _notifGranted = false;

  @override
  void initState() {
    super.initState();
    _refreshStates();
  }

  Future<void> _refreshStates() async {
    setState(() => _checking = true);
    final svc = PermissionStateService.instance;
    final s = await svc.hasStorageOrPhotosPermission();
    final n = await svc.hasNotificationsPermission();
    final ln = await svc.hasLocalNetworkPermission();
    setState(() {
      _hasStorage = s;
      _notifGranted = n;
      _hasLocalNet = ln;
      _checking = false;
    });
  }

  bool get _mandatorySatisfied {
    final storageOk = _hasStorage;
    final localOk = Platform.isIOS ? _hasLocalNet : true;
    return storageOk && localOk;
  }

  Future<void> _requestStorage() async {
    final ok = await PermissionStateService.instance.requestStorageOrPhotos();
    if (!ok) {
      await _openSettings();
    }
    await _refreshStates();
  }

  Future<void> _requestLocalNet() async {
    final ok = await PermissionStateService.instance.requestLocalNetwork();
    if (!ok) {
      await _openSettings();
    }
    await _refreshStates();
  }

  Future<void> _requestNotif() async {
    await PermissionStateService.instance.requestNotifications();
    await _refreshStates();
  }

  Future<void> _openSettings() async {
    final uri =
        Platform.isIOS ? Uri.parse('app-settings:') : Uri.parse('package:');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cards = <Widget>[
      _PermissionCard(
        title: 'Quyền lưu trữ/ảnh',
        description:
            'Ứng dụng cần quyền truy cập Ảnh/Tệp để hiển thị và phát nội dung cục bộ.',
        granted: _hasStorage,
        onRequest: _requestStorage,
      ),
      if (Platform.isIOS)
        _PermissionCard(
          title: 'Mạng cục bộ',
          description:
              'Cho phép truy cập mạng nội bộ để duyệt SMB/NAS trong cùng mạng.',
          granted: _hasLocalNet,
          onRequest: _requestLocalNet,
        ),
      _PermissionCard(
        title: 'Thông báo (tùy chọn)',
        description: 'Bật thông báo để nhận cập nhật phát và tác vụ nền.',
        granted: _notifGranted,
        onRequest: _requestNotif,
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Cấp quyền để tiếp tục')),
      body: _checking
          ? const Center(child: CircularProgressIndicator())
          : Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Để sử dụng ứng dụng mượt mà, vui lòng cấp các quyền sau đây. Bạn có thể bỏ qua và cấp sau trong Cài đặt.',
                    style: TextStyle(fontSize: 16),
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView.separated(
                      itemCount: cards.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 12),
                      itemBuilder: (_, i) => cards[i],
                    ),
                  ),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: _mandatorySatisfied
                              ? () => Navigator.of(context).maybePop()
                              : null,
                          child: const Text('Vào app'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.of(context).maybePop(),
                          child: const Text('Bỏ qua, vào app'),
                        ),
                      ),
                    ],
                  )
                ],
              ),
            ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  final String title;
  final String description;
  final bool granted;
  final VoidCallback onRequest;

  const _PermissionCard({
    Key? key,
    required this.title,
    required this.description,
    required this.granted,
    required this.onRequest,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(
              granted ? Icons.check_circle : Icons.error_outline,
              color: granted ? Colors.green : Colors.orange,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 6),
                  Text(description),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(
              onPressed: onRequest,
              child: Text(granted ? 'Đã cấp' : 'Cấp quyền'),
            )
          ],
        ),
      ),
    );
  }
}
