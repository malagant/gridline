import 'package:flutter/material.dart';
import 'package:gridline_native/gridline_native.dart';

import 'theme.dart';
import 'tracker_model.dart';

/// Das Pattern als Raster: Zeilen sind Steps, Spalten sind Spuren.
class PatternGrid extends StatefulWidget {
  const PatternGrid({super.key, required this.model, this.compact = false});

  final TrackerModel model;
  final bool compact;

  @override
  State<PatternGrid> createState() => _PatternGridState();
}

class _PatternGridState extends State<PatternGrid> {
  final vertical = ScrollController();
  final horizontal = ScrollController();
  int _lastCursor = 0;
  int _lastPlayhead = -1;

  static const rowNumberWidth = 44.0;
  double get cellWidth => widget.compact ? 132 : 150;
  double get rowHeight => widget.compact ? 26 : 22;

  @override
  void dispose() {
    vertical.dispose();
    horizontal.dispose();
    super.dispose();
  }

  void _follow(int row) {
    if (!vertical.hasClients) return;
    final top = row * rowHeight;
    final view = vertical.position.viewportDimension;
    final offset = vertical.offset;
    if (top < offset || top + rowHeight > offset + view) {
      vertical.jumpTo((top - view / 3).clamp(0.0, vertical.position.maxScrollExtent));
    }
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.model;
    final p = m.pattern;
    if (m.cursorStep != _lastCursor) {
      _lastCursor = m.cursorStep;
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow(m.cursorStep));
    } else if (m.isPlaying && m.playhead != _lastPlayhead && m.playhead >= 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _follow(m.playhead));
    }
    _lastPlayhead = m.playhead;

    final width = rowNumberWidth + cellWidth * p.trackCount;
    return Scrollbar(
      controller: horizontal,
      child: SingleChildScrollView(
        controller: horizontal,
        scrollDirection: Axis.horizontal,
        child: SizedBox(
          width: width,
          child: Column(
            children: [
              _header(m),
              Expanded(
                child: ListView.builder(
                  controller: vertical,
                  itemCount: p.length,
                  itemExtent: rowHeight,
                  itemBuilder: (_, step) => _row(m, p, step),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _header(TrackerModel m) {
    return Container(
      color: GridTheme.panel,
      height: 28,
      child: Row(
        children: [
          const SizedBox(width: rowNumberWidth),
          for (var t = 0; t < m.pattern.trackCount; t++)
            SizedBox(
              width: cellWidth,
              child: Center(
                child: Text('SPUR ${t + 1}',
                    style: GridTheme.monoBold.copyWith(color: t == m.cursorTrack ? GridTheme.accent : GridTheme.dim)),
              ),
            ),
        ],
      ),
    );
  }

  Widget _row(TrackerModel m, PatternView p, int step) {
    final Color bg;
    if (step == m.playhead) {
      bg = GridTheme.playhead;
    } else if (step % 16 == 0) {
      bg = GridTheme.barRow;
    } else if (step % 4 == 0) {
      bg = GridTheme.beatRow;
    } else {
      bg = Colors.transparent;
    }
    return ColoredBox(
      color: bg,
      child: Row(
        children: [
          SizedBox(
            width: rowNumberWidth,
            child: Center(
              child: Text(step.toString().padLeft(3, '0'),
                  style: GridTheme.mono.copyWith(color: step % 4 == 0 ? GridTheme.text : GridTheme.dim)),
            ),
          ),
          for (var t = 0; t < p.trackCount; t++)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => m.select(t, step),
              child: _CellView(
                cell: p.tracks[t][step],
                width: cellWidth,
                isCursor: t == m.cursorTrack && step == m.cursorStep,
              ),
            ),
        ],
      ),
    );
  }
}

class _CellView extends StatelessWidget {
  const _CellView({required this.cell, required this.width, required this.isCursor});

  final Cell cell;
  final double width;
  final bool isCursor;

  @override
  Widget build(BuildContext context) {
    TextSpan part(String s, bool active, Color color) =>
        TextSpan(text: '$s ', style: TextStyle(color: active ? color : GridTheme.dim));
    return Container(
      width: width,
      margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
      decoration: BoxDecoration(
        border: Border.all(color: isCursor ? GridTheme.cursor : Colors.transparent, width: 1.5),
        borderRadius: BorderRadius.circular(3),
      ),
      alignment: Alignment.center,
      child: Text.rich(
        TextSpan(style: GridTheme.mono, children: [
          part(cell.note, cell.hasNote, GridTheme.text),
          part(cell.instrument, cell.hasInstrument, GridTheme.accent),
          part(cell.volume, cell.hasVolume, GridTheme.text),
          part(cell.fx, cell.hasFx, GridTheme.cursor),
        ]),
        maxLines: 1,
        softWrap: false,
      ),
    );
  }
}
