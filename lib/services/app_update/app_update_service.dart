import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_update_model.dart';

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AppUpdateService {
  AppUpdateService._();

  static final AppUpdateService instance = AppUpdateService._();

  static const String githubOwner = 'mujtabax18';
  static const String githubRepository = 'dayark';
  static const String githubRepositoryUrl =
      'https://github.com/$githubOwner/$githubRepository';
  static const String _latestReleaseApi =
      'https://api.github.com/repos/$githubOwner/$githubRepository/releases/latest';

  final Dio _dio = Dio(
    BaseOptions(
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      headers: const {
        'Accept': 'application/vnd.github+json',
        'X-GitHub-Api-Version': '2026-03-10',
        'User-Agent': 'DayArk-Updater',
      },
    ),
  );

  Future<AppUpdateInfo?> checkForUpdate() async {
    if (!Platform.isAndroid && !Platform.isWindows && !Platform.isLinux) {
      return null;
    }

    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();

    Response<dynamic> response;
    try {
      response = await _dio.get<dynamic>(_latestReleaseApi);
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        return null;
      }
      throw AppUpdateException(_friendlyNetworkError(error));
    }

    final data = response.data;
    if (data is! Map) {
      throw const AppUpdateException(
        'GitHub returned an invalid release response.',
      );
    }

    if (data['draft'] == true || data['prerelease'] == true) {
      return null;
    }

    final tag = (data['tag_name'] ?? '').toString().trim();
    final latestVersion = _normaliseVersion(tag);
    if (latestVersion.isEmpty) {
      throw const AppUpdateException(
        'The latest GitHub release does not have a valid version tag.',
      );
    }

    if (!_isNewerVersion(latestVersion, currentVersion)) {
      return null;
    }

    final assets = data['assets'];
    if (assets is! List || assets.isEmpty) {
      throw AppUpdateException(
        'DayArk $latestVersion is available, but the release has no files attached.',
      );
    }

    final asset = _selectPlatformAsset(assets);
    if (asset == null) {
      throw AppUpdateException(
        'DayArk $latestVersion is available, but no ${_platformPackageLabel()} was found in the release. Upload a package for this operating system.',
      );
    }

    final assetUrl = (asset['browser_download_url'] ?? '').toString().trim();
    if (assetUrl.isEmpty) {
      throw const AppUpdateException(
        'The latest release package does not have a download URL.',
      );
    }

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseName: (data['name'] ?? tag).toString().trim(),
      releaseNotes: (data['body'] ?? '').toString().trim(),
      assetName: (asset['name'] ?? 'DayArk-$latestVersion').toString(),
      assetUrl: assetUrl,
      releaseUrl: (data['html_url'] ?? '').toString().trim(),
      assetSize: _toInt(asset['size']),
      assetDigest: asset['digest']?.toString().trim(),
    );
  }

  Future<void> openGithubRepository() async {
    final uri = Uri.parse(githubRepositoryUrl);
    final opened = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!opened) {
      throw const AppUpdateException(
        'Could not open the DayArk GitHub repository.',
      );
    }
  }

  Future<bool> hasInstallPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.status;
    return status.isGranted;
  }

  Future<bool> requestInstallPermission() async {
    if (!Platform.isAndroid) return false;
    final status = await Permission.requestInstallPackages.request();
    return status.isGranted;
  }

  Future<File> downloadUpdate(
    AppUpdateInfo update, {
    required void Function(int received, int total) onProgress,
  }) async {
    final temp = await getTemporaryDirectory();
    final updateDirectory = Directory(p.join(temp.path, 'dayark_updates'));
    if (!await updateDirectory.exists()) {
      await updateDirectory.create(recursive: true);
    }

    await _removeOldDownloads(updateDirectory);

    final safeName = _safeAssetName(update.assetName, update.latestVersion);
    final target = File(p.join(updateDirectory.path, safeName));
    final partial = File('${target.path}.part');

    if (await partial.exists()) {
      await partial.delete();
    }

    try {
      await _dio.download(
        update.assetUrl,
        partial.path,
        deleteOnError: true,
        onReceiveProgress: onProgress,
        options: Options(
          followRedirects: true,
          receiveTimeout: const Duration(minutes: 5),
          headers: const {
            'Accept': 'application/octet-stream',
            'User-Agent': 'DayArk-Updater',
          },
        ),
      );

      if (!await partial.exists()) {
        throw const AppUpdateException('The downloaded update could not be found.');
      }

      final actualSize = await partial.length();
      if (update.assetSize > 0 && actualSize != update.assetSize) {
        throw AppUpdateException(
          'The update download was incomplete. Expected ${update.assetSize} bytes but received $actualSize bytes.',
        );
      }

      await _verifyDigestIfAvailable(partial, update.assetDigest);
      await _verifyPlatformHeader(partial);

      if (await target.exists()) {
        await target.delete();
      }
      return partial.rename(target.path);
    } catch (error) {
      if (await partial.exists()) {
        await partial.delete();
      }
      if (error is AppUpdateException) rethrow;
      if (error is DioException) {
        throw AppUpdateException(_friendlyNetworkError(error));
      }
      throw AppUpdateException('Could not download the update: $error');
    }
  }

  Future<void> installApk(File apkFile) async {
    if (!Platform.isAndroid) {
      throw const AppUpdateException('APK installation is only available on Android.');
    }
    if (!await apkFile.exists()) {
      throw const AppUpdateException('The downloaded APK no longer exists.');
    }

    final result = await OpenFilex.open(
      apkFile.path,
      type: 'application/vnd.android.package-archive',
    );

    if (result.type != ResultType.done) {
      throw AppUpdateException(
        result.message.trim().isEmpty
            ? 'Android could not open the APK installer.'
            : result.message,
      );
    }
  }

  /// Assets must use predictable names; never run an arbitrary .exe release asset.
  Map<dynamic, dynamic>? _selectPlatformAsset(List<dynamic> assets) {
    final candidates = assets.whereType<Map>().where((asset) {
      final name = (asset['name'] ?? '').toString().toLowerCase();
      final state = (asset['state'] ?? 'uploaded').toString().toLowerCase();
      if (state != 'uploaded' || name.contains('debug')) return false;
      if (!name.contains('dayark') &&
          !(Platform.isAndroid && name == 'app-release.apk')) return false;
      if (Platform.isAndroid) return name.endsWith('.apk');
      if (Platform.isWindows) {
        return name.endsWith('.exe') &&
            (name.contains('setup') || name.contains('installer')) &&
            !name.contains('arm64');
      }
      if (Platform.isLinux) {
        return name.endsWith('.appimage') &&
            (name.contains('x86_64') || name.contains('amd64')) &&
            !name.contains('aarch64') && !name.contains('arm64');
      }
      return false;
    }).toList();
    candidates.sort((a, b) => _assetScore(b).compareTo(_assetScore(a)));
    return candidates.isEmpty ? null : candidates.first;
  }

  int _assetScore(Map<dynamic, dynamic> asset) {
    final name = (asset['name'] ?? '').toString().toLowerCase();
    var score = 0;
    if (name.contains('universal')) score += 40;
    if (name.contains('x86_64') || name.contains('x64') || name.contains('amd64')) score += 30;
    if (name.contains('release')) score += 10;
    if (name.contains('arm64') || name.contains('armeabi') || name.contains('x86-')) score -= 20;
    return score;
  }

  String _platformPackageLabel() {
    if (Platform.isAndroid) return 'Android APK';
    if (Platform.isWindows) return 'Windows DayArk-Setup .exe installer';
    if (Platform.isLinux) return 'Linux x86_64 DayArk .AppImage';
    return 'supported update package';
  }

  Future<void> _verifyPlatformHeader(File file) async {
    final handle = await file.open();
    try {
      final magic = await handle.read(4);
      if (Platform.isWindows &&
          (magic.length < 2 || magic[0] != 0x4d || magic[1] != 0x5a)) {
        throw const AppUpdateException('Downloaded Windows installer is not a valid EXE file.');
      }
      if (Platform.isLinux &&
          (magic.length < 4 || magic[0] != 0x7f || magic[1] != 0x45 ||
              magic[2] != 0x4c || magic[3] != 0x46)) {
        throw const AppUpdateException('Downloaded AppImage is not a valid ELF file.');
      }
    } finally {
      await handle.close();
    }
  }

  /// Windows releases are installed using a normal Inno Setup EXE.
  Future<void> installWindowsSetup(File installer) async {
    if (!Platform.isWindows) {
      throw const AppUpdateException('This installer is for Windows only.');
    }
    if (!await installer.exists()) {
      throw const AppUpdateException('The Windows installer is missing.');
    }
    try {
      await Process.start(installer.path, ['/CLOSEAPPLICATIONS', '/NORESTART'],
          mode: ProcessStartMode.detached);
    } on ProcessException catch (error) {
      throw AppUpdateException('Could not launch the Windows installer: ${error.message}');
    }
  }

  /// Full AppImage download + a separate, local helper to replace it after exit.
  /// Requires running from an AppImage placed in a user-writable folder.
  Future<void> scheduleLinuxAppImageInstall(File download) async {
    if (!Platform.isLinux) {
      throw const AppUpdateException('AppImage installation is for Linux only.');
    }
    final appImageEnv = Platform.environment['APPIMAGE']?.trim() ?? '';
    if (appImageEnv.isEmpty || !p.isAbsolute(appImageEnv)) {
      throw const AppUpdateException(
        'Automatic Linux updates require launching DayArk from its AppImage, '
        'not flutter run, a ZIP bundle, Flatpak or a package-manager installation.',
      );
    }
    final running = File(appImageEnv);
    if (!await running.exists() || !await download.exists()) {
      throw const AppUpdateException('Could not locate the running or downloaded AppImage.');
    }
    final currentPath = await running.resolveSymbolicLinks();
    final currentFolder = Directory(p.dirname(currentPath));
    final testFile = File(p.join(currentFolder.path, '.dayark-update-write-test-$pid'));
    try {
      await testFile.writeAsString('');
      await testFile.delete();
    } on FileSystemException {
      throw const AppUpdateException(
        'DayArk cannot update the AppImage in this folder. Move your AppImage '
        'to a user-writable folder such as ~/Applications, then reopen it.',
      );
    }

    final script = File(p.join(p.dirname(download.path), 'dayark-apply-appimage-update.sh'));
    await script.writeAsString(_linuxInstallerScript, flush: true);
    try {
      await Process.start('/bin/sh', [script.path, currentPath, download.path, '$pid'],
          mode: ProcessStartMode.detached);
    } on ProcessException catch (error) {
      throw AppUpdateException('Could not launch Linux updater: ${error.message}');
    }
  }

  static const String _linuxInstallerScript = r'''#!/bin/sh
set -eu
installed="$1"
downloaded="$2"
app_pid="$3"
i=0
while kill -0 "$app_pid" 2>/dev/null && [ "$i" -lt 180 ]; do
  sleep 1
  i=$((i + 1))
done
if kill -0 "$app_pid" 2>/dev/null; then exit 1; fi
next="${installed}.dayark-update-${app_pid}"
trap 'rm -f -- "$next"' EXIT
cp -- "$downloaded" "$next"
chmod +x -- "$next"
mv -f -- "$next" "$installed"
rm -f -- "$downloaded"
trap - EXIT
"$installed" >/dev/null 2>&1 </dev/null &
''';

  Future<void> _verifyDigestIfAvailable(File file, String? digestValue) async {
    if (digestValue == null || digestValue.isEmpty) return;

    final parts = digestValue.split(':');
    if (parts.length != 2 || parts.first.toLowerCase() != 'sha256') return;

    final expected = parts.last.trim().toLowerCase();
    if (expected.isEmpty) return;

    final actual = (await sha256.bind(file.openRead()).first).toString().toLowerCase();
    if (actual != expected) {
      throw const AppUpdateException(
        'Security check failed: the downloaded file checksum does not match GitHub.',
      );
    }
  }

  Future<void> _removeOldDownloads(Directory directory) async {
    try {
      await for (final entity in directory.list()) {
        if (entity is File &&
            (entity.path.toLowerCase().endsWith('.apk') ||
                entity.path.toLowerCase().endsWith('.exe') ||
                entity.path.toLowerCase().endsWith('.appimage') ||
                entity.path.toLowerCase().endsWith('.part'))) {
          await entity.delete();
        }
      }
    } catch (_) {
      // Old cached update cleanup must never block a new update.
    }
  }

  String _safeAssetName(String original, String version) {
    final cleaned = original.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_');
    final expectedExtension = Platform.isAndroid ? '.apk' :
        Platform.isWindows ? '.exe' : '.AppImage';
    if (cleaned.length > expectedExtension.length &&
        cleaned.toLowerCase().endsWith(expectedExtension.toLowerCase())) {
      return cleaned;
    }
    return 'DayArk-$version$expectedExtension';
  }

  int _toInt(dynamic value) {
    if (value is int) return value;
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  String _friendlyNetworkError(DioException error) {
    if (error.type == DioExceptionType.connectionTimeout ||
        error.type == DioExceptionType.receiveTimeout ||
        error.type == DioExceptionType.sendTimeout) {
      return 'The update check timed out. Please check your internet connection.';
    }
    if (error.type == DioExceptionType.connectionError) {
      return 'Could not connect to GitHub. Please check your internet connection.';
    }
    final code = error.response?.statusCode;
    if (code == 403 || code == 429) {
      return 'GitHub temporarily limited update checks. Please try again later.';
    }
    return 'Could not check for updates from GitHub.';
  }

  String _normaliseVersion(String value) {
    var version = value.trim();
    if (version.startsWith('v') || version.startsWith('V')) {
      version = version.substring(1);
    }
    return version;
  }

  bool _isNewerVersion(String latest, String current) {
    return _ParsedVersion.parse(latest).compareTo(_ParsedVersion.parse(current)) > 0;
  }
}

class _ParsedVersion implements Comparable<_ParsedVersion> {
  const _ParsedVersion(this.parts, this.preRelease);

  final List<int> parts;
  final List<String>? preRelease;

  factory _ParsedVersion.parse(String input) {
    var value = input.trim();
    if (value.startsWith('v') || value.startsWith('V')) {
      value = value.substring(1);
    }
    value = value.split('+').first;

    final dashIndex = value.indexOf('-');
    final core = dashIndex >= 0 ? value.substring(0, dashIndex) : value;
    final pre = dashIndex >= 0 ? value.substring(dashIndex + 1) : null;

    final numericParts = core
        .split('.')
        .map((part) => int.tryParse(part.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0)
        .toList();
    while (numericParts.length < 3) {
      numericParts.add(0);
    }

    final preParts = pre == null || pre.trim().isEmpty
        ? null
        : pre.split('.').where((part) => part.isNotEmpty).toList();

    return _ParsedVersion(numericParts, preParts);
  }

  @override
  int compareTo(_ParsedVersion other) {
    final maxLength = parts.length > other.parts.length ? parts.length : other.parts.length;
    for (var i = 0; i < maxLength; i++) {
      final left = i < parts.length ? parts[i] : 0;
      final right = i < other.parts.length ? other.parts[i] : 0;
      if (left != right) return left.compareTo(right);
    }

    if (preRelease == null && other.preRelease == null) return 0;
    if (preRelease == null) return 1;
    if (other.preRelease == null) return -1;

    final maxPreLength = preRelease!.length > other.preRelease!.length
        ? preRelease!.length
        : other.preRelease!.length;
    for (var i = 0; i < maxPreLength; i++) {
      if (i >= preRelease!.length) return -1;
      if (i >= other.preRelease!.length) return 1;

      final left = preRelease![i];
      final right = other.preRelease![i];
      final leftNumber = int.tryParse(left);
      final rightNumber = int.tryParse(right);

      if (leftNumber != null && rightNumber != null) {
        if (leftNumber != rightNumber) return leftNumber.compareTo(rightNumber);
      } else if (leftNumber != null) {
        return -1;
      } else if (rightNumber != null) {
        return 1;
      } else {
        final comparison = left.compareTo(right);
        if (comparison != 0) return comparison;
      }
    }
    return 0;
  }
}
