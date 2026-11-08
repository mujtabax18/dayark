part of '../device_sync_service.dart';

enum SyncRole { standalone, primary, secondary }

class LocalSyncBackup {
  const LocalSyncBackup({
    required this.path,
    required this.fileName,
    required this.createdAt,
    required this.sizeBytes,
  });

  final String path;
  final String fileName;
  final DateTime createdAt;
  final int sizeBytes;
}

class SyncDevice {
  const SyncDevice({
    required this.id,
    required this.name,
    required this.host,
    required this.port,
    required this.token,
    required this.isPrimary,
    required this.revoked,
    required this.tlsPinned,
    this.lastSeen,
  });
  final String id, name, host, token;
  final int port;
  final bool isPrimary, revoked, tlsPinned;
  final DateTime? lastSeen;
}

class DeviceSyncState {
  const DeviceSyncState({
    this.role = SyncRole.standalone,
    this.running = false,
    this.syncing = false,
    this.firstSyncing = false,
    this.backupBusy = false,
    this.deviceName = 'This device',
    this.deviceId = '',
    this.pairingUrl,
    this.pairingCode,
    this.pendingWrites = 0,
    this.sentWrites = 0,
    this.receivedWrites = 0,
    this.conflicts = 0,
    this.lastSync,
    this.error,
    this.activity,
    this.devices = const [],
    this.localBackups = const [],
  });
  final SyncRole role;
  final bool running, syncing, firstSyncing, backupBusy;
  final String deviceName, deviceId;
  final String? pairingUrl, pairingCode, error, activity;
  final int pendingWrites, sentWrites, receivedWrites, conflicts;
  final DateTime? lastSync;
  final List<SyncDevice> devices;
  final List<LocalSyncBackup> localBackups;

  DeviceSyncState copyWith({
    SyncRole? role,
    bool? running,
    bool? syncing,
    bool? firstSyncing,
    bool? backupBusy,
    String? deviceName,
    String? deviceId,
    String? pairingUrl,
    String? pairingCode,
    int? pendingWrites,
    int? sentWrites,
    int? receivedWrites,
    int? conflicts,
    DateTime? lastSync,
    String? error,
    String? activity,
    List<SyncDevice>? devices,
    List<LocalSyncBackup>? localBackups,
    bool clearPairing = false,
    bool clearError = false,
    bool clearActivity = false,
  }) => DeviceSyncState(
    role: role ?? this.role,
    running: running ?? this.running,
    syncing: syncing ?? this.syncing,
    firstSyncing: firstSyncing ?? this.firstSyncing,
    backupBusy: backupBusy ?? this.backupBusy,
    deviceName: deviceName ?? this.deviceName,
    deviceId: deviceId ?? this.deviceId,
    pairingUrl: clearPairing ? null : pairingUrl ?? this.pairingUrl,
    pairingCode: clearPairing ? null : pairingCode ?? this.pairingCode,
    pendingWrites: pendingWrites ?? this.pendingWrites,
    sentWrites: sentWrites ?? this.sentWrites,
    receivedWrites: receivedWrites ?? this.receivedWrites,
    conflicts: conflicts ?? this.conflicts,
    lastSync: lastSync ?? this.lastSync,
    error: clearError ? null : error ?? this.error,
    activity: clearActivity ? null : activity ?? this.activity,
    devices: devices ?? this.devices,
    localBackups: localBackups ?? this.localBackups,
  );
}

