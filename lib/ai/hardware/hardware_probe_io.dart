import 'dart:convert';
import 'dart:io';

import 'ai_hardware.dart';
import 'mobile_hardware_probe_stub.dart'
    if (dart.library.ui) 'mobile_hardware_probe.dart';

Future<String?> _run(String executable, List<String> args) async {
  try {
    final process = await Process.start(executable, args);
    final output = process.stdout.transform(utf8.decoder).join();
    final errors = process.stderr.drain<void>();
    try {
      final code = await process.exitCode.timeout(const Duration(seconds: 3));
      await errors;
      final value = await output;
      return code == 0 ? value.trim() : null;
    } catch (_) {
      process.kill();
      await Future.wait([output, errors]);
      return null;
    }
  } catch (_) {
    return null;
  }
}

Future<String> _read(String path) async {
  try {
    return await File(path).readAsString();
  } catch (_) {
    return '';
  }
}

Future<AiHardwareReport> detect(String path) async {
  int? total, available, storage, vram;
  String cpu = 'Unknown CPU';
  String? gpu;
  bool? supported;
  final notes = <String>[
    'Recommendations use CPU RAM; GPU offload is not enabled.',
  ];
  if (Platform.isLinux || Platform.isAndroid) {
    final values = await Future.wait([
      _read('/proc/meminfo'),
      _read('/proc/cpuinfo'),
      _run('df', ['-Pk', path]),
      if (Platform.isLinux) _run('lspci', []),
      if (Platform.isLinux)
        _run('nvidia-smi', [
          '--query-gpu=name,memory.total',
          '--format=csv,noheader,nounits',
        ]),
    ]);
    int? memory(String key) {
      final match = RegExp(
        '^$key:\\s+(\\d+) kB',
        multiLine: true,
      ).firstMatch(values[0] ?? '');
      return match == null ? null : int.parse(match[1]!) * 1024;
    }

    total = memory('MemTotal');
    available = memory('MemAvailable');
    final info = values[1] ?? '';
    cpu =
        RegExp(
          r'^(?:model name|Hardware)\s*:\s*(.+)$',
          multiLine: true,
        ).firstMatch(info)?[1] ??
        cpu;
    if (info.contains('GenuineIntel') || info.contains('AuthenticAMD')) {
      supported = RegExp(r'\bavx2\b').hasMatch(info);
      if (supported == false) {
        notes.add('Pinned x86 CPU runtime requires AVX2; this CPU lacks it.');
      }
    }
    final rows = values[2]?.split('\n');
    if (rows != null && rows.length > 1) {
      final fields = rows.last.trim().split(RegExp(r'\s+'));
      if (fields.length >= 4) {
        final freeKiB = int.tryParse(fields[3]);
        storage = freeKiB == null ? null : freeKiB * 1024;
      }
    }
    if (Platform.isLinux) {
      gpu = (values[3] ?? '')
          .split('\n')
          .where(
            (line) =>
                RegExp('VGA|3D controller|Display controller').hasMatch(line),
          )
          .join('\n');
      final nvidia = values[4]?.split('\n').first.split(',');
      if (nvidia != null && nvidia.length == 2) {
        gpu = nvidia.first.trim();
        final memoryMiB = int.tryParse(nvidia.last.trim());
        vram = memoryMiB == null ? null : memoryMiB * 1024 * 1024;
      }
    }
  } else if (Platform.isMacOS) {
    total = int.tryParse(await _run('sysctl', ['-n', 'hw.memsize']) ?? '');
    cpu = await _run('sysctl', ['-n', 'machdep.cpu.brand_string']) ?? cpu;
    final vm = await _run('vm_stat', []);
    final page = int.tryParse(
      RegExp(r'page size of (\d+) bytes').firstMatch(vm ?? '')?[1] ?? '',
    );
    final free = int.tryParse(
      RegExp(r'Pages free:\s+(\d+)').firstMatch(vm ?? '')?[1] ?? '',
    );
    if (page != null && free != null) available = page * free;
    final df = await _run('df', ['-Pk', path]);
    final fields = df?.split('\n').last.trim().split(RegExp(r'\s+'));
    if (fields != null && fields.length > 3) {
      storage = int.tryParse(fields[3]) == null
          ? null
          : int.parse(fields[3]) * 1024;
    }
    gpu = await _run('system_profiler', [
      'SPDisplaysDataType',
      '-detailLevel',
      'mini',
    ]);
  } else if (Platform.isWindows) {
    final raw = await _run('powershell.exe', [
      '-NoProfile',
      '-NonInteractive',
      '-Command',
      r'$o=Get-CimInstance Win32_OperatingSystem; $c=Get-CimInstance Win32_Processor | Select-Object -First 1; $g=@(Get-CimInstance Win32_VideoController | Select-Object Name,AdapterRAM); @{total=$o.TotalVisibleMemorySize; available=$o.FreePhysicalMemory; cpu=$c.Name; gpu=$g} | ConvertTo-Json -Depth 4 -Compress',
    ]);
    try {
      final data = jsonDecode(raw!) as Map<String, dynamic>;
      total = (data['total'] as num).toInt() * 1024;
      available = (data['available'] as num).toInt() * 1024;
      cpu = data['cpu'] as String;
      final cards = data['gpu'] as List;
      gpu = cards.map((c) => c['Name']).join(', ');
      // AdapterRAM is a legacy 32-bit field; do not present it as reliable VRAM.
    } catch (_) {
      notes.add('Windows hardware counters unavailable.');
    }
    // Resolve the actual destination volume, including mounted volumes.
    final escaped = path.replaceAll("'", "''");
    storage = int.tryParse(
      await _run('powershell.exe', [
            '-NoProfile',
            '-NonInteractive',
            '-Command',
            "(Get-Volume -FilePath '$escaped').SizeRemaining",
          ]) ??
          '',
    );
  }
  if (Platform.isAndroid || Platform.isIOS) {
    final native = await readMobileAiHardware(path);
    total = (native['totalMemoryBytes'] as num?)?.toInt() ?? total;
    available = (native['availableMemoryBytes'] as num?)?.toInt() ?? available;
    storage = (native['freeStorageBytes'] as num?)?.toInt() ?? storage;
    cpu = native['cpu'] as String? ?? cpu;
    gpu = native['gpu'] as String? ?? gpu;
    if (native.isEmpty) {
      notes.add('Native mobile hardware counters unavailable.');
    }
  }
  if (gpu == '') gpu = null;
  if (available == null) notes.add('Available RAM unknown.');
  if (storage == null) notes.add('Destination free storage unknown.');
  notes.add('Native model loading is the final compatibility check.');
  return AiHardwareReport(
    platform: Platform.operatingSystem,
    cpu: cpu,
    logicalCores: Platform.numberOfProcessors,
    totalMemoryBytes: total,
    availableMemoryBytes: available,
    freeStorageBytes: storage,
    gpu: gpu,
    vramBytes: vram,
    runtimeSupported: supported,
    notes: notes,
  );
}
