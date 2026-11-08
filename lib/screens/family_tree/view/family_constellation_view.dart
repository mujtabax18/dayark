import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:webview_all/webview_all.dart';

import '../models/family_tree_models.dart';
import '../models/life_archive_models.dart';

/// An offline HTML/Canvas spatial network embedded inside Flutter.
///
/// All edits go through existing DayArk sheets / repository; the web page is
/// strictly a presentation layer and does not persist or fetch user data.
class FamilyConstellationView extends StatefulWidget {
  const FamilyConstellationView({
    super.key,
    required this.members,
    required this.relationships,
    required this.connections,
    required this.events,
    this.modalOpen = false,
    required this.focusedMemberId,
    required this.onFocus,
    required this.onDetails,
    required this.onAddRelative,
    required this.onAddPerson,
    required this.onAddEvent,
    required this.onEventDetails,
    required this.onAddAlbumForEvent,
    required this.onConnect,
  });

  final List<FamilyMember> members;
  final List<FamilyRelationship> relationships;
  final List<LifeConnection> connections;
  final List<LifeEvent> events;
  /// Temporarily replaces the native view with a raster preview, so Flutter
  /// dialogs and sheets always appear in front on Linux and Windows.
  final bool modalOpen;
  final int? focusedMemberId;
  final ValueChanged<int> onFocus;
  final ValueChanged<FamilyMember> onDetails;
  final void Function(FamilyMember, String) onAddRelative;
  final VoidCallback onAddPerson;
  final VoidCallback onAddEvent;
  final ValueChanged<LifeEvent> onEventDetails;
  final ValueChanged<LifeEvent> onAddAlbumForEvent;
  final ValueChanged<FamilyMember> onConnect;

  @override
  State<FamilyConstellationView> createState() => FamilyConstellationViewState();
}

class FamilyConstellationViewState extends State<FamilyConstellationView>
    with AutomaticKeepAliveClientMixin {
  static const _htmlAsset = 'assets/family_tree/relationship_universe.html';
  final Map<String, String?> _thumbnails = {};
  late final WebViewController _controller;

  bool _ready = false;
  String? _error;
  int _snapshotGeneration = 0;
  Uint8List? _modalPreview;
  Map<String, dynamic>? _savedViewState;
  Completer<void>? _previewRequest;

  /// Capture the live graph BEFORE Flutter removes the native WebView layer.
  /// The graph camera and highlighted person are not reset by this capture.
  Future<void> prepareForModal() async {
    if (!_ready || !mounted || widget.modalOpen) return;
    _modalPreview = null;
    _savedViewState = null;
    final pending = Completer<void>();
    _previewRequest = pending;
    try {
      await _controller.runJavaScript(
        'window.DayArkGraph && window.DayArkGraph.captureForSheet();',
      );
      // Never prevent opening a sheet if the platform does not deliver a
      // JavaScript channel callback (e.g. while the view is being detached).
      await pending.future.timeout(const Duration(milliseconds: 700));
    } catch (_) {
      // The sheet still opens with the solid dark background as fallback.
    } finally {
      if (identical(_previewRequest, pending)) _previewRequest = null;
    }
  }

  @override
  bool get wantKeepAlive => true;

  @override
  void initState() {
    super.initState();
    _controller = WebViewController();
    _initialize();
  }

  Future<void> _initialize() async {
    try {
      await _controller.setJavaScriptMode(JavaScriptMode.unrestricted);
      await _controller.addJavaScriptChannel(
        'DayArkBridge',
        onMessageReceived: (message) => _onWebMessage(message.message),
      );
      await _controller.setNavigationDelegate(NavigationDelegate(
        onPageStarted: (_) {
          _ready = false;
          ++_snapshotGeneration;
        },
        onPageFinished: (_) => _onPageReady(),
      ));
      await _controller.loadFlutterAsset(_htmlAsset);
    } catch (error) {
      if (mounted) setState(() => _error = 'Cannot open family constellation: $error');
    }
  }

  void _onPageReady() {
    if (!mounted || _ready) return;
    _ready = true;
    _sendSnapshot();
  }

  LifeEvent? _eventFor(Object? id) {
    if (id is! int) return null;
    for (final event in widget.events) {
      if (event.id == id) return event;
    }
    return null;
  }

  FamilyMember? _memberFor(Object? id) {
    if (id is! int) return null;
    for (final person in widget.members) {
      if (person.id == id) return person;
    }
    return null;
  }

  void _onWebMessage(String message) {
    if (!mounted) return;
    try {
      final raw = jsonDecode(message);
      if (raw is! Map<String, dynamic>) return;
      switch (raw['action']) {
        case 'ready':
          // Also handle a fresh JS context after a desktop native view gets
          // reattached without a navigation-start event.
          if (_ready) {
            _sendSnapshot();
          } else {
            _onPageReady();
          }
          break;
        case 'sheetPreview':
          final view = raw['view'];
          if (view is Map<String, dynamic>) _savedViewState = view;
          final image = raw['image'];
          if (image is String &&
              image.startsWith('data:image/jpeg;base64,') &&
              image.length < 2000000) {
            try {
              _modalPreview = base64Decode(image.substring(image.indexOf(',') + 1));
            } on FormatException {
              _modalPreview = null;
            }
          }
          final pending = _previewRequest;
          if (pending != null && !pending.isCompleted) pending.complete();
          break;
        case 'focus':
          final member = _memberFor(raw['id']);
          if (member != null && member.id != widget.focusedMemberId) {
            widget.onFocus(member.id);
          }
          break;
        case 'details':
          final member = _memberFor(raw['id']);
          if (member != null) widget.onDetails(member);
          break;
        case 'addRelative':
          final member = _memberFor(raw['id']);
          if (member != null) {
            final role = raw['role'] is String ? raw['role'] as String : 'child';
            widget.onAddRelative(member, role);
          }
          break;
        case 'connect':
          final member = _memberFor(raw['id']);
          if (member != null) widget.onConnect(member);
          break;
        case 'eventDetails':
          final event = _eventFor(raw['id']);
          if (event != null) widget.onEventDetails(event);
          break;
        case 'albumForEvent':
          final event = _eventFor(raw['id']);
          if (event != null) widget.onAddAlbumForEvent(event);
          break;
        case 'addEvent':
          widget.onAddEvent();
          break;
        case 'addPerson':
          widget.onAddPerson();
          break;
      }
    } on FormatException {
      // Only structured commands from our bundled local HTML are accepted.
    }
  }

  @override
  void didUpdateWidget(covariant FamilyConstellationView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.modalOpen && !widget.modalOpen) {
      // The native view is reattached after the Flutter route has gone away.
      // Deliver any member/relationship edits made inside the sheet.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _sendSnapshot();
      });
    } else if (widget.modalOpen) {
      return; // Keep the live graph frozen until the sheet closes.
    }
    if (!identical(oldWidget.members, widget.members) ||
        !identical(oldWidget.relationships, widget.relationships) ||
        !identical(oldWidget.connections, widget.connections) ||
        !identical(oldWidget.events, widget.events)) {
      _thumbnails.clear();
      _sendSnapshot();
    } else if (oldWidget.focusedMemberId != widget.focusedMemberId &&
        widget.focusedMemberId != null && _ready) {
      // Changing focus from People / related-person sheets retains the 3D camera.
      _controller.runJavaScript(
        'window.DayArkGraph && window.DayArkGraph.focus(${widget.focusedMemberId});',
      );
    }
  }

  Future<void> _sendSnapshot() async {
    if (!_ready || !mounted || widget.modalOpen) return;
    final generation = ++_snapshotGeneration;
    final members = widget.members;
    final relationships = widget.relationships;
    final connections = widget.connections;
    final events = widget.events;
    final focus = widget.focusedMemberId;

    final memberData = <Map<String, Object?>>[];
    for (var start = 0; start < members.length; start += 6) {
      final end = start + 6 > members.length ? members.length : start + 6;
      final batch = await Future.wait(members.sublist(start, end).map((member) async {
        return <String, Object?>{
          'id': member.id,
          'name': member.fullName,
          'gender': member.gender,
          'occupation': member.occupation,
          'photo': await _thumbnail(member.profileImagePath),
        };
      }));
      if (!mounted || generation != _snapshotGeneration) return;
      memberData.addAll(batch);
    }
    if (!mounted || !_ready || widget.modalOpen || generation != _snapshotGeneration) return;

    final data = <String, Object?>{
      'members': memberData,
      'relationships': [
        for (final link in relationships)
          <String, Object?>{
            'from': link.fromMemberId,
            'to': link.toMemberId,
            'type': link.type,
          },
      ],
      'connections': [
        for (final c in connections)
          <String, Object?>{
            'from': c.fromMemberId, 'to': c.toMemberId,
            'type': c.type, 'label': c.displayLabel,
          },
      ],
      'events': [
        for (final event in events)
          <String, Object?>{
            'id': event.id, 'name': event.title, 'type': event.type,
            'participants': event.participantIds,
          },
      ],
      'focusedId': focus,
    };
    try {
      // JSON is serialized, not interpolated as unescaped names or notes.
      await _controller.runJavaScript(
        'window.DayArkGraph && window.DayArkGraph.setData(${jsonEncode(data)});',
      );
      // If the native view was recreated, restore orbit, pan, zoom, and mode.
      // When the original JavaScript context survived, this is idempotent.
      final view = _savedViewState;
      if (view != null && generation == _snapshotGeneration) {
        await _controller.runJavaScript(
          'window.DayArkGraph && window.DayArkGraph.restoreState(${jsonEncode(view)});',
        );
        _savedViewState = null;
      }
    } catch (error) {
      if (mounted && generation == _snapshotGeneration) {
        setState(() => _error = 'Unable to update family view: $error');
      }
    }
  }

  /// Downsample local profile photos before crossing the Dart / JS bridge.
  /// Pictures never leave the device, and repeated updates reuse thumbnails.
  Future<String?> _thumbnail(String? path) async {
    if (path == null || path.isEmpty) return null;
    if (_thumbnails.containsKey(path)) return _thumbnails[path];
    try {
      final file = File(path);
      if (!await file.exists()) return _thumbnails[path] = null;
      final bytes = await file.readAsBytes();
      final codec = await ui.instantiateImageCodec(
        bytes,
        targetWidth: 96,
        targetHeight: 96,
        allowUpscaling: false,
      );
      try {
        final frame = await codec.getNextFrame();
        try {
          final png = await frame.image.toByteData(format: ui.ImageByteFormat.png);
          if (png == null) return _thumbnails[path] = null;
          return _thumbnails[path] = 'data:image/png;base64,${base64Encode(png.buffer.asUint8List())}';
        } finally {
          frame.image.dispose();
        }
      } finally {
        codec.dispose();
      }
    } catch (_) {
      return _thumbnails[path] = null;
    }
  }

  @override
  void dispose() {
    ++_snapshotGeneration;
    final pending = _previewRequest;
    if (pending != null && !pending.isCompleted) pending.complete();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: SelectableText(_error!, textAlign: TextAlign.center),
        ),
      );
    }
    // A GTK/WebView2 platform view is a native layer; Flutter's
    // showModalBottomSheet cannot reliably paint above it. Removing that
    // layer during the modal guarantees the sheet and keyboard are visible.
    // The controller stays alive, so orbit/zoom state is preserved on return.
    if (widget.modalOpen) {
      return ColoredBox(
        color: const Color(0xFF071323),
        child: _modalPreview == null
            ? const SizedBox.expand()
            : SizedBox.expand(
                child: Image.memory(
                  _modalPreview!,
                  fit: BoxFit.fill,
                  gaplessPlayback: true,
                  filterQuality: FilterQuality.medium,
                ),
              ),
      );
    }
    return ColoredBox(
      color: const Color(0xFF071323),
      child: WebViewWidget(controller: _controller),
    );
  }
}
