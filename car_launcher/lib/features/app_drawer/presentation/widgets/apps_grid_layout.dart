import 'package:flutter/material.dart';

/// Car-friendly responsive grid — cell size drives icon/label, not the reverse.
class AppsGridLayout {
  const AppsGridLayout({
    required this.columns,
    required this.rows,
    required this.iconSize,
    required this.labelFontSize,
    required this.horizontalPadding,
    required this.crossAxisSpacing,
    required this.mainAxisSpacing,
    required this.childAspectRatio,
    required this.cellHeight,
  });

  final int columns;
  final int rows;
  final double iconSize;
  final double labelFontSize;
  final double horizontalPadding;
  final double crossAxisSpacing;
  final double mainAxisSpacing;
  final double childAspectRatio;
  final double cellHeight;

  int get itemsPerPage => columns * rows;

  String get layoutKey =>
      '$columns-$rows-${iconSize.toInt()}-${cellHeight.toInt()}';

  static AppsGridLayout resolve({
    required double width,
    required double height,
    required Orientation orientation,
    double reservedBottom = 36,
  }) {
    const minCellWidth = 118.0;
    const maxCellWidth = 168.0;
    const minIconSize = 52.0;
    const maxIconSize = 80.0;
    const iconLabelGap = 8.0;
    const tileVerticalPadding = 12.0;
    const labelLineHeight = 1.2;
    const labelLines = 2;
    const minCellHeight = 108.0;

    final isWide = width >= 900;
    final isMedium = width >= 600;

    final horizontalPadding = isWide ? 40.0 : isMedium ? 28.0 : 20.0;
    final crossAxisSpacing = isWide ? 28.0 : isMedium ? 22.0 : 16.0;
    final mainAxisSpacing = isWide ? 22.0 : isMedium ? 18.0 : 14.0;

    final gridWidth = (width - horizontalPadding * 2).clamp(0.0, width);
    final gridHeight = (height - reservedBottom).clamp(0.0, height);

    var columns = ((gridWidth + crossAxisSpacing) / (minCellWidth + crossAxisSpacing))
        .floor();

    if (orientation == Orientation.portrait) {
      columns = columns.clamp(3, 4);
    } else {
      columns = columns.clamp(4, 5);
    }

    var cellWidth =
        (gridWidth - (columns - 1) * crossAxisSpacing) / columns;

    if (cellWidth > maxCellWidth) {
      columns = ((gridWidth + crossAxisSpacing) / (maxCellWidth + crossAxisSpacing))
          .ceil();
      if (orientation == Orientation.portrait) {
        columns = columns.clamp(3, 5);
      } else {
        columns = columns.clamp(4, 6);
      }
      cellWidth =
          (gridWidth - (columns - 1) * crossAxisSpacing) / columns;
    }

    var maxRows = orientation == Orientation.portrait
        ? 5
        : height < 420
            ? 3
            : height < 600
                ? 3
                : 4;

    var rows = maxRows;
    late double cellHeight;
    late double iconSize;
    late double labelFontSize;

    while (rows >= 2) {
      cellHeight =
          (gridHeight - (rows - 1) * mainAxisSpacing) / rows;
      if (cellHeight < minCellHeight) {
        rows--;
        continue;
      }

      labelFontSize = cellHeight >= 150
          ? 14.0
          : cellHeight >= 130
              ? 13.0
              : 12.0;

      final labelBlockHeight = labelFontSize * labelLineHeight * labelLines;
      final iconBudget = cellHeight -
          tileVerticalPadding -
          iconLabelGap -
          labelBlockHeight;

      if (iconBudget >= minIconSize) {
        // Reserve a few px for font metric rounding vs. grid cell height.
        iconSize = (iconBudget - 4).clamp(minIconSize, maxIconSize);
        break;
      }
      rows--;
    }

    if (rows < 2) {
      rows = 2;
      cellHeight =
          (gridHeight - (rows - 1) * mainAxisSpacing) / rows;
      labelFontSize = 12.0;
      final labelBlockHeight = labelFontSize * labelLineHeight * labelLines;
      iconSize = (cellHeight -
              tileVerticalPadding -
              iconLabelGap -
              labelBlockHeight -
              4)
          .clamp(40.0, maxIconSize);
    }

    final childAspectRatio = cellWidth / (cellHeight + 3);

    return AppsGridLayout(
      columns: columns,
      rows: rows,
      iconSize: iconSize,
      labelFontSize: labelFontSize,
      horizontalPadding: horizontalPadding,
      crossAxisSpacing: crossAxisSpacing,
      mainAxisSpacing: mainAxisSpacing,
      childAspectRatio: childAspectRatio,
      cellHeight: cellHeight,
    );
  }
}
