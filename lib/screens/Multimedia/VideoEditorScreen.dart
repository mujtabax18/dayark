import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:path/path.dart' as p;
import 'package:metersystem/services/runtime/app_storage_paths.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:video_player/video_player.dart';

import '../../controller/mediaController.dart';
import '../../models/MediaFile.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({
    super.key,
    required this.media,
  });

  final MediaFile media;

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  VideoPlayerController? _preview;
  StreamSubscription<ProgressModel>? _progressSubscription;

  bool _loading = true;
  bool _exporting = false;
  bool _mute = false;
  bool _reverse = false;
  bool _flipX = false;
  bool _flipY = false;
  int _rotateTurns = 0;
  double _speed = 1;
  double _progress = 0;
  double _durationSeconds = 1;
  RangeValues _trim = const RangeValues(0, 1);
  int _bitrate = 8000000;
  String? _error;
  String? _activeTaskId;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final file = File(widget.media.currentPath);
    if (!await file.exists()) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'The source video is missing.';
        });
      }
      return;
    }

    try {
      final controller = VideoPlayerController.file(file);
      await controller.initialize();
      await controller.setLooping(true);
      final seconds = controller.value.duration.inMilliseconds / 1000;
      if (!mounted) {
        await controller.dispose();
        return;
      }
      setState(() {
        _preview = controller;
        _durationSeconds = seconds <= 0 ? 1 : seconds;
        _trim = RangeValues(0, seconds <= 0 ? 1 : seconds);
        _loading = false;
      });
    } catch (error) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not prepare the video: $error';
        });
      }
    }
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    _preview?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_exporting,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Video editor'),
          actions: [
            TextButton.icon(
              onPressed: _exporting || _loading || _error != null
                  ? null
                  : _export,
              icon: const Icon(Icons.save_outlined),
              label: const Text('Export'),
            ),
          ],
        ),
        body: _buildBody(),
      ),
    );
  }

  Widget _buildBody() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Text(_error!, textAlign: TextAlign.center),
        ),
      );
    }

    final controller = _preview!;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(18),
          child: ColoredBox(
            color: Colors.black,
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Transform(
                    alignment: Alignment.center,
                    transform: Matrix4.diagonal3Values(
                      _flipX ? -1 : 1,
                      _flipY ? -1 : 1,
                      1,
                    )..rotateZ(_rotateTurns * 1.5707963267948966),
                    child: VideoPlayer(controller),
                  ),
                  ValueListenableBuilder<VideoPlayerValue>(
                    valueListenable: controller,
                    builder: (_, value, __) => IconButton.filledTonal(
                      iconSize: 38,
                      onPressed: _exporting
                          ? null
                          : () async {
                              if (value.isPlaying) {
                                await controller.pause();
                              } else {
                                final position = await controller.position;
                                final end = Duration(
                                  milliseconds: (_trim.end * 1000).round(),
                                );
                                if (position == null || position >= end) {
                                  await controller.seekTo(Duration(
                                    milliseconds: (_trim.start * 1000).round(),
                                  ));
                                }
                                await controller.play();
                              }
                              if (mounted) setState(() {});
                            },
                      icon: Icon(
                        value.isPlaying ? Icons.pause : Icons.play_arrow,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 18),
        _SectionCard(
          title: 'Trim',
          subtitle:
              '${_time(_trim.start)} – ${_time(_trim.end)}  •  ${_time((_trim.end - _trim.start) / _speed)} output',
          child: RangeSlider(
            values: _trim,
            min: 0,
            max: _durationSeconds,
            divisions: _durationSeconds >= 2
                ? _durationSeconds.round().clamp(2, 600).toInt()
                : null,
            labels: RangeLabels(_time(_trim.start), _time(_trim.end)),
            onChanged: _exporting
                ? null
                : (values) async {
                    if (values.end - values.start < 0.2) return;
                    setState(() => _trim = values);
                    await controller.seekTo(Duration(
                      milliseconds: (values.start * 1000).round(),
                    ));
                  },
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Speed',
          subtitle: '${_speed.toStringAsFixed(_speed % 1 == 0 ? 0 : 2)}×',
          child: Slider(
            value: _speed,
            min: 0.25,
            max: 3,
            divisions: 11,
            label: '${_speed.toStringAsFixed(2)}×',
            onChanged: _exporting
                ? null
                : (value) async {
                    setState(() => _speed = value);
                    await controller.setPlaybackSpeed(value);
                  },
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Transform and audio',
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FilterChip(
                selected: _mute,
                label: const Text('Mute'),
                avatar: const Icon(Icons.volume_off_outlined, size: 18),
                onSelected: _exporting
                    ? null
                    : (value) => setState(() => _mute = value),
              ),
              FilterChip(
                selected: _reverse,
                label: const Text('Reverse'),
                avatar: const Icon(Icons.fast_rewind, size: 18),
                onSelected: _exporting
                    ? null
                    : (value) => setState(() => _reverse = value),
              ),
              FilterChip(
                selected: _flipX,
                label: const Text('Flip H'),
                avatar: const Icon(Icons.flip, size: 18),
                onSelected: _exporting
                    ? null
                    : (value) => setState(() => _flipX = value),
              ),
              FilterChip(
                selected: _flipY,
                label: const Text('Flip V'),
                avatar: const RotatedBox(
                  quarterTurns: 1,
                  child: Icon(Icons.flip, size: 18),
                ),
                onSelected: _exporting
                    ? null
                    : (value) => setState(() => _flipY = value),
              ),
              ActionChip(
                avatar: const Icon(Icons.rotate_right, size: 18),
                label: Text('Rotate ${_rotateTurns * 90}°'),
                onPressed: _exporting
                    ? null
                    : () => setState(
                          () => _rotateTurns = (_rotateTurns + 1) % 4,
                        ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        _SectionCard(
          title: 'Export quality',
          child: DropdownButtonFormField<int>(
            initialValue: _bitrate,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              isDense: true,
            ),
            items: const [
              DropdownMenuItem(
                value: 12000000,
                child: Text('High – 12 Mbps'),
              ),
              DropdownMenuItem(
                value: 8000000,
                child: Text('Balanced – 8 Mbps'),
              ),
              DropdownMenuItem(
                value: 4000000,
                child: Text('Compact – 4 Mbps'),
              ),
              DropdownMenuItem(
                value: 2000000,
                child: Text('Small – 2 Mbps'),
              ),
            ],
            onChanged: _exporting
                ? null
                : (value) {
                    if (value != null) setState(() => _bitrate = value);
                  },
          ),
        ),
        if (_exporting) ...[
          const SizedBox(height: 20),
          LinearProgressIndicator(value: _progress > 0 ? _progress : null),
          const SizedBox(height: 8),
          Text(
            _progress > 0
                ? 'Rendering ${(100 * _progress).toStringAsFixed(0)}%'
                : 'Preparing video export…',
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 10),
          if (_canCancel)
            OutlinedButton.icon(
              onPressed: _cancelExport,
              icon: const Icon(Icons.close),
              label: const Text('Cancel export'),
            ),
        ],
      ],
    );
  }

  bool get _canCancel =>
      _activeTaskId != null &&
      (Platform.isAndroid || Platform.isIOS || Platform.isMacOS);

  Future<void> _export() async {
    final source = File(widget.media.currentPath);
    if (!await source.exists()) {
      _showMessage('The source video is missing.');
      return;
    }

    await _preview?.pause();
    final taskId = 'media_video_${widget.media.id}_${DateTime.now().microsecondsSinceEpoch}';
    final task = VideoRenderData(
      id: taskId,
      videoSegments: [
        VideoSegment(
          video: EditorVideo.file(source),
          volume: _mute ? 0 : 1,
          playbackSpeed: _speed,
          reverseVideo: _reverse,
        ),
      ],
      startTime: Duration(milliseconds: (_trim.start * 1000).round()),
      endTime: Duration(milliseconds: (_trim.end * 1000).round()),
      outputFormat: VideoOutputFormat.mp4,
      bitrate: _bitrate,
      enableAudio: !_mute,
      maxFrameRate: 30,
      transform: ExportTransform(
        rotateTurns: _rotateTurns,
        flipX: _flipX,
        flipY: _flipY,
      ),
    );

    final temp = await getTemporaryDirectory();
    final output = File(
      p.join(temp.path, 'edited_video_${DateTime.now().microsecondsSinceEpoch}.mp4'),
    );

    setState(() {
      _exporting = true;
      _progress = 0;
      _activeTaskId = taskId;
    });

    await _progressSubscription?.cancel();
    _progressSubscription = ProVideoEditor.instance
        .progressStreamById(taskId)
        .listen((event) {
      if (mounted) {
        setState(() => _progress = event.progress.clamp(0, 1).toDouble());
      }
    });

    try {
      await ProVideoEditor.instance.renderVideoToFile(output.path, task);
      final saved = await ref.read(mediaServiceProvider).saveEditedFileVersion(
            media: widget.media,
            outputFile: output,
            action: 'video_edit',
            metadata: {
              'editor': 'pro_video_editor',
              'trim_start_ms': (_trim.start * 1000).round(),
              'trim_end_ms': (_trim.end * 1000).round(),
              'speed': _speed,
              'muted': _mute,
              'reverse': _reverse,
              'flip_x': _flipX,
              'flip_y': _flipY,
              'rotate_turns': _rotateTurns,
              'bitrate': _bitrate,
            },
          );
      refreshMediaLibrary(ref);
      if (mounted) Navigator.of(context).pop(saved);
    } on RenderCanceledException {
      if (mounted) _showMessage('Video export cancelled.');
    } catch (error) {
      if (mounted) _showMessage('Video export failed: $error');
    } finally {
      await _progressSubscription?.cancel();
      _progressSubscription = null;
      if (await output.exists()) await output.delete();
      if (mounted) {
        setState(() {
          _exporting = false;
          _activeTaskId = null;
          _progress = 0;
        });
      }
    }
  }

  Future<void> _cancelExport() async {
    final id = _activeTaskId;
    if (id == null) return;
    try {
      await ProVideoEditor.instance.cancel(id);
    } catch (error) {
      if (mounted) _showMessage('Could not cancel export: $error');
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  String _time(double seconds) {
    final duration = Duration(milliseconds: (seconds * 1000).round());
    final minutes = duration.inMinutes.remainder(60).toString().padLeft(2, '0');
    final secs = duration.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (duration.inHours > 0) {
      return '${duration.inHours}:$minutes:$secs';
    }
    return '${duration.inMinutes}:$secs';
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.child,
    this.subtitle,
  });

  final String title;
  final String? subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
            if (subtitle != null) ...[
              const SizedBox(height: 3),
              Text(
                subtitle!,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
            const SizedBox(height: 10),
            child,
          ],
        ),
      ),
    );
  }
}
