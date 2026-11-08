import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qr_flutter/qr_flutter.dart';

import '../../services/device_sync/device_sync_service.dart';
import '../../services/device_sync/local_sync_tls.dart';
import '../../utlis/app_router.dart';
import '../navigation/widgets/desktop_navigation_scope.dart';

void _backToSettings(BuildContext context) {
  final desktopScope = DesktopNavigationScope.maybeOf(context);
  if (MediaQuery.sizeOf(context).width >= 1100 && desktopScope != null) {
    desktopScope.onOpenRoute(RoutesStr.settings);
    return;
  }

  final navigator = Navigator.of(context);
  if (navigator.canPop()) {
    navigator.pop();
    return;
  }

  openResponsiveModule(context, RoutesStr.settings);
}

class DeviceSyncScreen extends ConsumerWidget {
  const DeviceSyncScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final s = ref.watch(deviceSyncProvider);
    final service = ref.read(deviceSyncProvider.notifier);
    final showBackLabel = MediaQuery.sizeOf(context).width >= 600;

    return Scaffold(
      appBar: AppBar(
        leadingWidth: showBackLabel ? 168 : 56,
        leading: showBackLabel
            ? TextButton.icon(
                onPressed: () => _backToSettings(context),
                icon: const Icon(Icons.arrow_back_rounded),
                label: const Text('Back to Settings'),
              )
            : IconButton(
                tooltip: 'Back to Settings',
                onPressed: () => _backToSettings(context),
                icon: const Icon(Icons.arrow_back_rounded),
              ),
        title: const Text('Local device sync'),
        actions: [
          IconButton(
            tooltip: 'Sync now',
            onPressed: (s.syncing || s.firstSyncing || s.backupBusy)
                ? null
                : service.syncNow,
            icon: s.syncing
                ? const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.sync_rounded),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: service.refresh,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            _hero(context, s, service),
            const SizedBox(height: 16),
            _stats(context, s),
            if (s.role != SyncRole.standalone) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: Text(
                  'The initial database snapshot is the baseline. Pending shows unsent changes; Sent, Received and Conflicts count only later activity.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ],
            if (s.firstSyncing || s.backupBusy || s.activity != null) ...[
              const SizedBox(height: 12),
              _activityCard(context, s),
            ],
            if (s.error != null) ...[
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(
                    s.error!,
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            Text(
              'Pair another device',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            Text(
              'Both devices must be on the same local network. Secure synchronization always uses HTTPS on TCP ${LocalSyncTls.syncPort}. If a Linux/Windows firewall is enabled, allow inbound TCP ${LocalSyncTls.syncPort} from your trusted LAN. On the first connection, the primary sends a compressed snapshot and saves a local safety backup. After initialization, only new inserts, updates and deletes are synchronized automatically.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                FilledButton.icon(
                  onPressed:
                      s.pairingUrl != null ||
                          s.role == SyncRole.secondary ||
                          s.firstSyncing ||
                          s.backupBusy
                      ? null
                      : service.createPairing,
                  icon: const Icon(Icons.qr_code_2_rounded),
                  label: const Text('Create pairing code'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      s.pairingUrl != null ||
                          s.role == SyncRole.primary ||
                          s.firstSyncing ||
                          s.backupBusy
                      ? null
                      : service.createSecondaryQr,
                  icon: const Icon(Icons.desktop_windows_rounded),
                  label: const Text('Generate Secondary Device QR'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      s.pairingUrl != null ||
                          s.firstSyncing ||
                          s.backupBusy
                      ? null
                      : () => _openScanner(context, service),
                  icon: const Icon(Icons.qr_code_scanner_rounded),
                  label: const Text('Scan QR'),
                ),
                OutlinedButton.icon(
                  onPressed:
                      s.pairingUrl != null ||
                          s.role == SyncRole.primary ||
                          s.firstSyncing ||
                          s.backupBusy
                      ? null
                      : () => _joinDialog(context, service),
                  icon: const Icon(Icons.link_rounded),
                  label: const Text('Connect with URL'),
                ),
              ],
            ),
            if (s.pairingUrl != null) ...[
              const SizedBox(height: 12),
              _pairingCard(context, s, service),
            ],
            const SizedBox(height: 22),
            Text(
              'Connected devices',
              style: Theme.of(context).textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 8),
            if (s.devices.any((device) => !device.tlsPinned))
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(14),
                  child: Text(
                    'Security upgrade: one or more existing device links need to be paired again using the new QR code. Synchronization is blocked for unverified links; your local data has not been deleted.',
                  ),
                ),
              ),
            if (s.devices.isEmpty)
              const Card(
                child: Padding(
                  padding: EdgeInsets.all(18),
                  child: Text('No connected devices yet.'),
                ),
              ),
            ...s.devices.map(
              (d) => Card(
                child: ListTile(
                  leading: CircleAvatar(
                    child: Icon(
                      d.isPrimary ? Icons.star_rounded : Icons.devices_rounded,
                    ),
                  ),
                  title: Text(d.name),
                  subtitle: Text(
                    '${_deviceStatus(s, d)} • ${d.tlsPinned ? 'TLS secured' : 'Secure re-pairing required'}',
                  ),
                  trailing: s.role == SyncRole.primary && !d.isPrimary
                      ? IconButton(
                          tooltip: 'Log out device',
                          onPressed: () => _confirmLogout(context, service, d),
                          icon: const Icon(Icons.logout_rounded),
                        )
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 20),
            _runtimeCard(context, s, service),
          ],
        ),
      ),
    );
  }

  Widget _activityCard(BuildContext context, DeviceSyncState s) {
    final isBusy = s.firstSyncing || s.backupBusy || s.syncing;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (isBusy) ...[
                  const SizedBox.square(
                    dimension: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                  const SizedBox(width: 10),
                ],
                Expanded(
                  child: Text(
                    s.firstSyncing
                        ? 'First sync in progress'
                        : s.backupBusy
                        ? 'Local backup operation'
                        : 'Sync activity',
                    style: Theme.of(context).textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              s.activity ??
                  (s.firstSyncing
                      ? 'Transferring and loading the primary snapshot. Keep both devices on the same local network.'
                      : 'Working…'),
            ),
            if (isBusy) ...[
              const SizedBox(height: 12),
              const LinearProgressIndicator(),
            ],
          ],
        ),
      ),
    );
  }

  Widget _pairingCard(
    BuildContext context,
    DeviceSyncState s,
    DeviceSyncService service,
  ) {
    final url = s.pairingUrl!;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final qr = Container(
              width: 210,
              height: 210,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
              ),
              child: QrImageView(
                data: url,
                version: QrVersions.auto,
                backgroundColor: Colors.white,
              ),
            );

            final details = Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'One-time code: ${s.pairingCode}',
                  style: Theme.of(context).textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w800),
                ),
                const SizedBox(height: 8),
                Text(
                  s.pairingUrl!.startsWith('dayark://secondary?')
                      ? 'Scan this QR with your primary mobile device. The secondary will connect automatically.'
                      : 'Scan this QR from the secondary device. Re-pairing creates a fresh relationship token.',
                ),
                const SizedBox(height: 10),
                SelectableText(url),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.tonalIcon(
                      onPressed: () async {
                        await Clipboard.setData(ClipboardData(text: url));
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Pairing URL copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy_rounded),
                      label: const Text('Copy URL'),
                    ),
                    OutlinedButton.icon(
                      onPressed: s.syncing || s.firstSyncing || s.backupBusy
                          ? null
                          : service.cancelPairing,
                      icon: const Icon(Icons.close_rounded),
                      label: const Text('Cancel pairing code'),
                    ),
                  ],
                ),
              ],
            );

            if (constraints.maxWidth >= 650) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  qr,
                  const SizedBox(width: 18),
                  Expanded(child: details),
                ],
              );
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(child: qr),
                const SizedBox(height: 16),
                details,
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _runtimeCard(
    BuildContext context,
    DeviceSyncState s,
    DeviceSyncService service,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Sync engine',
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 6),
            Text(
              s.running
                  ? 'Running at app level. On startup and about every 15 seconds while the app process is active, it performs a lightweight LAN check and synchronizes only pending changes.'
                  : 'Stopped. New writes remain local and can be synchronized after you start the engine again.',
            ),
            const SizedBox(height: 8),
            const Text(
              'When the app is minimized, the service continues while the operating system keeps the Flutter process alive. If Android/iOS suspends the process, the durable queue resumes automatically when the app becomes active again. Continuous iOS LAN listening cannot be guaranteed after OS suspension.',
            ),
            if (s.lastSync != null) ...[
              const SizedBox(height: 8),
              Text('Last sync ${_ago(s.lastSync!)}'),
            ],
            const SizedBox(height: 12),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                if (!s.running)
                  FilledButton.tonalIcon(
                    onPressed: s.firstSyncing || s.backupBusy
                        ? null
                        : service.startNetworking,
                    icon: const Icon(Icons.play_arrow_rounded),
                    label: const Text('Start local sync'),
                  )
                else
                  FilledButton.tonalIcon(
                    onPressed: s.firstSyncing || s.backupBusy
                        ? null
                        : service.stopNetworking,
                    icon: const Icon(Icons.pause_rounded),
                    label: const Text('Stop local sync'),
                  ),
                OutlinedButton.icon(
                  onPressed: (s.syncing || s.firstSyncing || s.backupBusy)
                      ? null
                      : service.syncNow,
                  icon: const Icon(Icons.sync_rounded),
                  label: Text(s.syncing ? 'Syncing…' : 'Sync now'),
                ),
                TextButton.icon(
                  onPressed: s.firstSyncing || s.backupBusy
                      ? null
                      : () => service.disconnect(forgetPeers: true),
                  icon: const Icon(Icons.logout_rounded),
                  label: const Text('Logout / forget devices'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _hero(
    BuildContext context,
    DeviceSyncState s,
    DeviceSyncService service,
  ) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Row(
          children: [
            CircleAvatar(
              radius: 26,
              child: Icon(
                s.role == SyncRole.primary
                    ? Icons.hub_rounded
                    : Icons.devices_other_rounded,
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    s.deviceName,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w800),
                  ),
                  Text(
                    '${s.role.name.toUpperCase()} • ${s.running ? (s.syncing ? 'syncing' : 'available on LAN') : 'sync stopped'}',
                  ),
                ],
              ),
            ),
            IconButton(
              tooltip: 'Rename this device',
              onPressed: () => _renameDialog(context, service, s.deviceName),
              icon: const Icon(Icons.edit_outlined),
            ),
          ],
        ),
      ),
    );
  }

  Widget _stats(BuildContext context, DeviceSyncState s) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.maxWidth - 24) / (c.maxWidth > 700 ? 4 : 2);
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _stat(
              context,
              width,
              'Pending',
              '${s.pendingWrites}',
              Icons.schedule_send_rounded,
            ),
            _stat(
              context,
              width,
              'Sent',
              '${s.sentWrites}',
              Icons.cloud_done_outlined,
            ),
            _stat(
              context,
              width,
              'Received',
              '${s.receivedWrites}',
              Icons.download_done_rounded,
            ),
            _stat(
              context,
              width,
              'Conflicts',
              '${s.conflicts}',
              Icons.merge_type_rounded,
            ),
          ],
        );
      },
    );
  }

  Widget _stat(
    BuildContext context,
    double width,
    String label,
    String value,
    IconData icon,
  ) {
    return SizedBox(
      width: width,
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: [
              Icon(icon),
              const SizedBox(width: 10),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    value,
                    style: Theme.of(context).textTheme.titleLarge
                        ?.copyWith(fontWeight: FontWeight.w900),
                  ),
                  Text(label),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Future<void> _openScanner(
    BuildContext context,
    DeviceSyncService service,
  ) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const _PairingQrScannerScreen()),
    );
    if (result != null && result.isNotEmpty) {
      if (result.startsWith('dayark://secondary?')) {
        await service.pairSecondaryFromQr(result);
      } else {
        await service.connectWithUrl(result);
      }
    }
  }

  static Future<void> _joinDialog(
    BuildContext context,
    DeviceSyncService service,
  ) async {
    final controller = TextEditingController();
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Connect to primary device'),
        content: TextField(
          controller: controller,
          minLines: 3,
          maxLines: 6,
          decoration: const InputDecoration(
            labelText: 'Pairing URL',
            hintText: 'dayark://pair?...',
            border: OutlineInputBorder(),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              service.connectWithUrl(controller.text);
            },
            child: const Text('Connect'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  static Future<void> _renameDialog(
    BuildContext context,
    DeviceSyncService service,
    String current,
  ) async {
    final controller = TextEditingController(text: current);
    await showDialog<void>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Device name'),
        content: TextField(controller: controller, autofocus: true),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(context);
              service.setDeviceName(controller.text);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
    controller.dispose();
  }

  static Future<void> _confirmLogout(
    BuildContext context,
    DeviceSyncService service,
    SyncDevice device,
  ) async {
    final ok =
        await showDialog<bool>(
          context: context,
          builder: (_) => AlertDialog(
            title: Text('Log out ${device.name}?'),
            content: const Text(
              'This device will be removed from the connected list immediately. If it is reachable, it will be logged out now and its synchronized local data will be cleared. If it is offline, the same cleanup happens on its next startup or sync check.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('Cancel'),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('Log out device'),
              ),
            ],
          ),
        ) ??
        false;
    if (ok) await service.logoutDevice(device.id);
  }

  static String _deviceStatus(DeviceSyncState state, SyncDevice device) {
    if (!state.running) return 'Disconnected • sync engine stopped';
    final seen = device.lastSeen;
    if (seen == null) return 'Waiting for first connection';
    final age = DateTime.now().difference(seen.toLocal());
    if (age < const Duration(seconds: 25)) {
      return 'Connected • last seen ${_ago(seen)}';
    }
    return 'Offline • last seen ${_ago(seen)}';
  }

  static String _ago(DateTime value) {
    final d = DateTime.now().difference(value.toLocal());
    if (d.inSeconds < 60) return 'just now';
    if (d.inMinutes < 60) return '${d.inMinutes}m ago';
    if (d.inHours < 24) return '${d.inHours}h ago';
    return '${d.inDays}d ago';
  }
}

class _PairingQrScannerScreen extends StatefulWidget {
  const _PairingQrScannerScreen();

  @override
  State<_PairingQrScannerScreen> createState() =>
      _PairingQrScannerScreenState();
}

class _PairingQrScannerScreenState extends State<_PairingQrScannerScreen> {
  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
  );
  bool _handled = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Scan pairing QR'),
        actions: [
          IconButton(
            tooltip: 'Torch',
            onPressed: _controller.toggleTorch,
            icon: const Icon(Icons.flashlight_on_outlined),
          ),
          IconButton(
            tooltip: 'Switch camera',
            onPressed: _controller.switchCamera,
            icon: const Icon(Icons.cameraswitch_rounded),
          ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: (capture) {
              if (_handled) return;
              for (final barcode in capture.barcodes) {
                final value = barcode.rawValue;
                if (value == null ||
                    !(value.startsWith('dayark://pair?') ||
                        value.startsWith('dayark://secondary?'))) {
                  continue;
                }
                _handled = true;
                _controller.stop();
                Navigator.of(context).pop(value);
                return;
              }
            },
          ),
          Center(
            child: IgnorePointer(
              child: Container(
                width: 260,
                height: 260,
                decoration: BoxDecoration(
                  border: Border.all(
                    color: Theme.of(context).colorScheme.primary,
                    width: 3,
                  ),
                  borderRadius: BorderRadius.circular(24),
                ),
              ),
            ),
          ),
          const Positioned(
            left: 24,
            right: 24,
            bottom: 36,
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(14),
                child: Text(
                  'Scan the QR shown on the primary device. Both devices must be connected to the same LAN/Wi-Fi.',
                  textAlign: TextAlign.center,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
