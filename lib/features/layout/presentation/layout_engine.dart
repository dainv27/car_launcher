import 'package:flutter/material.dart';
import 'package:car_launcher/features/layout/domain/layout_model.dart';
import 'package:car_launcher/features/layout/presentation/widgets/single_layout.dart';

/// LayoutEngine — renders the appropriate layout widget based on LayoutModel
class LayoutEngine extends StatelessWidget {
  const LayoutEngine({super.key, required this.model});
  final LayoutModel model;

  @override
  Widget build(BuildContext context) {
    switch (model.type) {
      case LayoutType.dashboard_01:
        return SingleLayout(model: model);
    }
  }
}
