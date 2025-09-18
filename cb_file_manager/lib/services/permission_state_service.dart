import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionStateService {
  PermissionStateService._();

  static final PermissionStateService instance = PermissionStateService._();

  Future<bool> hasStorageOrPhotosPermission() async {
    if (Platform.isAndroid) {
      try {
        final videos = await Permission.videos.isGranted;
        final photos = await Permission.photos.isGranted;
        final audio = await Permission.audio.isGranted;
        final storage = await Permission.storage.isGranted;
        final manage = await Permission.manageExternalStorage.isGranted;
        return videos || photos || audio || storage || manage;
      } catch (e) {
        debugPrint('Error checking Android storage/media permissions: $e');
        return false;
      }
    }

    if (Platform.isIOS) {
      try {
        final photos = await Permission.photos.isGranted;
        return photos;
      } catch (e) {
        debugPrint('Error checking iOS photos permission: $e');
        return false;
      }
    }

    // Desktop/web default allow
    return true;
  }

  Future<bool> hasLocalNetworkPermission() async {
    // Not directly supported by permission_handler; treat as granted.
    // iOS Local Network permission is declared via Info.plist and prompted by sockets.
    return true;
  }

  Future<bool> hasNotificationsPermission() async {
    try {
      final status = await Permission.notification.isGranted;
      return status;
    } catch (_) {
      return false;
    }
  }

  Future<bool> requestStorageOrPhotos() async {
    // Request ONE permission per tap to avoid multiple sequential system dialogs
    if (Platform.isAndroid) {
      try {
        // Prefer Photos (Android 13+). On older Android this may map to storage handling.
        final status = await Permission.photos.request();
        if (status.isGranted || status.isLimited) return true;
        // Do not auto-chain to other permissions. User can try again or open settings.
        return false;
      } catch (e) {
        debugPrint('Error requesting Android media permission: $e');
        return false;
      }
    }
    if (Platform.isIOS) {
      try {
        final status = await Permission.photos.request();
        return status.isGranted || status.isLimited;
      } catch (e) {
        debugPrint('Error requesting iOS photos permission: $e');
        return false;
      }
    }
    return true;
  }

  Future<bool> requestLocalNetwork() async {
    // No direct runtime request available; networking attempt will trigger prompt on iOS.
    return true;
  }

  Future<bool> requestNotifications() async {
    try {
      final status = await Permission.notification.request();
      return status.isGranted;
    } catch (_) {
      return false;
    }
  }
}
