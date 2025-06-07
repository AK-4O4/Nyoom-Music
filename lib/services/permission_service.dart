import 'dart:io';
import 'package:flutter/material.dart';
import 'package:permission_handler/permission_handler.dart';

class PermissionService {
  static final PermissionService _instance = PermissionService._internal();
  factory PermissionService() => _instance;
  PermissionService._internal();

  Future<bool> requestMediaPermissions(BuildContext context) async {
    try {
      print('Requesting media permissions...');

      // For Android 13+ (API 33+)
      if (await Permission.audio.isGranted) {
        print('Audio permission already granted');
        return true;
      }

      // Request the new audio permission
      final audioStatus = await Permission.audio.request();
      print('Audio permission result: ${audioStatus.isGranted}');

      // For older Android versions
      if (!audioStatus.isGranted) {
        final storageStatus = await Permission.storage.request();
        print('Storage permission result: ${storageStatus.isGranted}');
        return storageStatus.isGranted;
      }

      return audioStatus.isGranted;
    } catch (e) {
      print('Error requesting media permissions: $e');
      return false;
    }
  }

  Future<bool> requestNotificationPermission(BuildContext context) async {
    try {
      print('Requesting notification permission...');

      if (await Permission.notification.isGranted) {
        print('Notification permission already granted');
        return true;
      }

      final status = await Permission.notification.request();
      print('Notification permission result: ${status.isGranted}');
      return status.isGranted;
    } catch (e) {
      print('Error requesting notification permission: $e');
      return false;
    }
  }

  Future<bool> requestAllPermissions(BuildContext context) async {
    try {
      print('Starting permission requests...');

      // Request media permissions first
      final mediaGranted = await requestMediaPermissions(context);
      if (!mediaGranted) {
        print('Media permissions denied');
        return false;
      }

      // Request notification permission for media controls
      final notificationGranted = await requestNotificationPermission(context);
      if (!notificationGranted) {
        print('Notification permission denied');
        return false;
      }

      print('All permissions granted successfully');
      return true;
    } catch (e) {
      print('Error in requestAllPermissions: $e');
      return false;
    }
  }

  Future<bool> checkAndRequestStoragePermission() async {
    print('Checking storage permission...');

    if (Platform.isAndroid) {
      bool hasPermission = false;

      // For Android 13+ (API 33+)
      if (await Permission.audio.isGranted) {
        print('Audio permission already granted');
        hasPermission = true;
      } else {
        print('Requesting audio permission...');
        final audioStatus = await Permission.audio.request();
        print('Audio permission request result: $audioStatus');
        hasPermission = audioStatus.isGranted;
      }

      // For older Android versions
      if (!hasPermission) {
        final storageStatus = await Permission.storage.status;
        print('Initial storage permission status: $storageStatus');

        if (!storageStatus.isGranted) {
          print('Storage permission not granted, requesting...');
          final result = await Permission.storage.request();
          print('Storage permission request result: $result');
          hasPermission = result.isGranted;
        } else {
          hasPermission = true;
        }
      }

      return hasPermission;
    }

    // For non-Android platforms, return true
    return true;
  }

  Future<bool> checkStoragePermission() async {
    if (Platform.isAndroid) {
      final status = await Permission.storage.status;
      final mediaStatus = await Permission.audio.status;
      return status.isGranted && mediaStatus.isGranted;
    }
    return true;
  }
}
