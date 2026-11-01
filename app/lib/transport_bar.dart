import 'package:flutter/material.dart';

import 'files.dart';
import 'theme.dart';
import 'tracker_model.dart';

class TransportBar extends StatelessWidget {
  const TransportBar({
    super.key,
    required this.model,
    required this.onShowInstruments,
    required this.keyboardVisible,
    required this.onToggleKeyboard,
  });

  final TrackerModel model;

  /// Gesetzt, wenn die Instrumente nicht dauerhaft sichtbar sind (schmale Fenster, iPhone).
  final VoidCallback? onShowInstruments;
  final bool keyboardVisible;
  final VoidCallback onToggleKeyboard;

  @override
  Widget build(BuildContext context) {
    return Container(
      color: GridTheme.panel,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      child: Row(
        children: [
          FilledButton.icon(
            onPressed: model.togglePlay,
            icon: Icon(model.isPlaying ? Icons.stop : Icons.play_arrow),
            label: Text(model.isPlaying ? 'Stopp' : 'Play'),
            style: FilledButton.styleFrom(foregroundColor: GridTheme.background, minimumSize: const Size(104, 44)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  _Stepper(
                    label: 'BPM ${model.pattern.bpm.round()}',
                    onMinus: () => model.setBpm(model.pattern.bpm - 1),
                    onPlus: () => model.setBpm(model.pattern.bpm + 1),
                  ),
                  _Stepper(
                    label: 'Länge ${model.pattern.length}',
                    onMinus: () => model.setPatternLength(model.pattern.length - 1),
                    onPlus: () => model.setPatternLength(model.pattern.length + 1),
                  ),
                  _Stepper(
                    label: 'Oktave ${model.octave}',
                    onMinus: () => model.shiftOctave(-1),
                    onPlus: () => model.shiftOctave(1),
                  ),
                ],
              ),
            ),
          ),
          IconButton(
            tooltip: keyboardVisible ? 'Klaviatur ausblenden' : 'Klaviatur einblenden',
            onPressed: onToggleKeyboard,
            icon: Icon(keyboardVisible ? Icons.keyboard_hide : Icons.piano),
          ),
          if (onShowInstruments != null)
            IconButton(tooltip: 'Instrumente', onPressed: onShowInstruments, icon: const Icon(Icons.library_music)),
          PopupMenuButton<String>(
            tooltip: 'Datei',
            icon: const Icon(Icons.folder_open),
            onSelected: (v) => _file(v),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'open', child: Text('Projekt öffnen …')),
              PopupMenuItem(value: 'save', child: Text('Projekt sichern …')),
              PopupMenuItem(value: 'export', child: Text('Als WAV exportieren …')),
            ],
          ),
          if (onShowInstruments == null) ...[
            const SizedBox(width: 8),
            Text('GRIDLINE',
                style: GridTheme.monoBold.copyWith(color: GridTheme.accent, fontSize: 15, letterSpacing: 4)),
          ],
        ],
      ),
    );
  }

  Future<void> _file(String action) async {
    switch (action) {
      case 'open':
        final p = await Files.pickProject();
        if (p != null) model.openProject(p);
      case 'save':
        final p = await Files.saveProject();
        if (p != null) model.saveProject(p);
      case 'export':
        final p = await Files.saveWav();
        if (p != null) model.exportWav(p);
    }
  }
}

class _Stepper extends StatelessWidget {
  const _Stepper({required this.label, required this.onMinus, required this.onPlus});

  final String label;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 12),
      child: Row(
        children: [
          IconButton(onPressed: onMinus, icon: const Icon(Icons.remove, size: 18), visualDensity: VisualDensity.compact),
          Text(label, style: GridTheme.monoBold),
          IconButton(onPressed: onPlus, icon: const Icon(Icons.add, size: 18), visualDensity: VisualDensity.compact),
        ],
      ),
    );
  }
}
