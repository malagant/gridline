import 'package:flutter/material.dart';

import 'theme.dart';
import 'tracker_model.dart';

/// Bildschirm-Klaviatur und Editier-Tasten für Touch-Bedienung.
class TouchKeyboard extends StatelessWidget {
  const TouchKeyboard({super.key, required this.model});

  final TrackerModel model;

  @override
  Widget build(BuildContext context) {
    Widget key(IconData icon, String tip, VoidCallback onTap) =>
        IconButton.outlined(tooltip: tip, onPressed: onTap, icon: Icon(icon, size: 20));
    return Container(
      color: GridTheme.panel,
      padding: const EdgeInsets.all(8),
      child: Column(
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(children: [
              key(Icons.remove, 'Oktave runter', () => model.shiftOctave(-1)),
              SizedBox(width: 64, child: Center(child: Text('OKT ${model.octave}', style: GridTheme.monoBold))),
              key(Icons.add, 'Oktave hoch', () => model.shiftOctave(1)),
              const SizedBox(width: 16),
              key(Icons.chevron_left, 'Spur links', () => model.moveTrack(-1)),
              key(Icons.expand_less, 'Step hoch', () => model.moveStep(-1)),
              key(Icons.expand_more, 'Step runter', () => model.moveStep(1)),
              key(Icons.chevron_right, 'Spur rechts', () => model.moveTrack(1)),
              const SizedBox(width: 16),
              OutlinedButton(onPressed: model.enterNoteOff, child: Text('OFF', style: GridTheme.monoBold)),
              const SizedBox(width: 4),
              key(Icons.backspace_outlined, 'Step löschen', model.clearStep),
            ]),
          ),
          const SizedBox(height: 8),
          SizedBox(height: 110, child: PianoKeys(onNote: model.enterSemitone)),
        ],
      ),
    );
  }
}

/// Eine Oktave plus oberes C. Löst beim Berühren aus, nicht erst beim Loslassen.
class PianoKeys extends StatelessWidget {
  const PianoKeys({super.key, required this.onNote});

  final ValueChanged<int> onNote;

  static const _white = [0, 2, 4, 5, 7, 9, 11, 12];
  static const _names = ['C', 'D', 'E', 'F', 'G', 'A', 'H', 'C'];

  /// (Index der weißen Taste links davon, Halbton)
  static const _black = [(0, 1), (1, 3), (3, 6), (4, 8), (5, 10)];

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (context, c) {
      final w = c.maxWidth / _white.length;
      final bw = w * 0.6;
      return Stack(
        children: [
          Row(children: [
            for (var i = 0; i < _white.length; i++)
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 1),
                  child: _Key(black: false, caption: _names[i], onPress: () => onNote(_white[i])),
                ),
              ),
          ]),
          for (final (index, semitone) in _black)
            Positioned(
              left: (index + 1) * w - bw / 2,
              top: 0,
              width: bw,
              height: c.maxHeight * 0.6,
              child: _Key(black: true, onPress: () => onNote(semitone)),
            ),
        ],
      );
    });
  }
}

class _Key extends StatefulWidget {
  const _Key({required this.black, required this.onPress, this.caption});

  final bool black;
  final String? caption;
  final VoidCallback onPress;

  @override
  State<_Key> createState() => _KeyState();
}

class _KeyState extends State<_Key> {
  bool pressed = false;

  @override
  Widget build(BuildContext context) {
    final color = pressed ? GridTheme.accent : (widget.black ? const Color(0xFF1F1F1F) : const Color(0xFFD1D1D1));
    return Listener(
      onPointerDown: (_) {
        setState(() => pressed = true);
        widget.onPress();
      },
      onPointerUp: (_) => setState(() => pressed = false),
      onPointerCancel: (_) => setState(() => pressed = false),
      child: Container(
        decoration: BoxDecoration(color: color, borderRadius: BorderRadius.circular(5)),
        alignment: Alignment.bottomCenter,
        padding: const EdgeInsets.only(bottom: 6),
        child: widget.caption == null
            ? null
            : Text(widget.caption!, style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: GridTheme.dim)),
      ),
    );
  }
}
