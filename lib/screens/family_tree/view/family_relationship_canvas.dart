import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../core/design/app_tokens.dart';
import '../models/family_tree_models.dart';

part 'parts/family_relationship_canvas_state.dart';
part 'parts/family_relationship_canvas_layout.dart';
part 'parts/family_relationship_canvas_family_edges_painter.dart';

/// In-place interactive family graph. Every member is rendered once, even if
/// they are connected to multiple families by marriage or through ancestry.
/// Re-rooting changes the viewport layout, never duplicates the member data.
class FamilyRelationshipCanvas extends StatefulWidget {
  const FamilyRelationshipCanvas({
    super.key,
    required this.members,
    required this.relationships,
    required this.focusedMemberId,
    required this.onFocus,
    required this.onDetails,
    required this.onAddRelative,
    this.fullscreen = false,
    this.initial3D = false,
  });

  final List<FamilyMember> members;
  final List<FamilyRelationship> relationships;
  final int? focusedMemberId;
  final ValueChanged<int> onFocus;
  final ValueChanged<FamilyMember> onDetails;
  final void Function(FamilyMember member, String role) onAddRelative;
  final bool fullscreen;
  final bool initial3D;

  @override
  State<FamilyRelationshipCanvas> createState() => _FamilyRelationshipCanvasState();
}

