import 'package:flutter/material.dart';
import 'package:gridline_native/gridline_native.dart';

import 'files.dart';
import 'theme.dart';
import 'tracker_model.dart';

class InstrumentPanel extends StatelessWidget {
  const InstrumentPanel({super.key, required this.model});

  final TrackerModel model;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: model,
      builder: (context, _) {
        final list = model.instruments;
        final sel = list[model.selectedInstrument];
        return ColoredBox(
          color: GridTheme.panel,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: Text('INSTRUMENTE', style: GridTheme.monoBold.copyWith(color: GridTheme.dim)),
              ),
              Expanded(
                child: ListView.builder(
                  itemCount: list.length,
                  itemBuilder: (_, i) => InkWell(
                    onTap: () => model.selectInstrument(i),
                    child: Container(
                      color: i == model.selectedInstrument ? GridTheme.accent.withValues(alpha: 0.18) : null,
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Row(children: [
                        Text((i + 1).toString().padLeft(2, '0'), style: GridTheme.mono.copyWith(color: GridTheme.dim)),
                        const SizedBox(width: 10),
                        Expanded(child: Text(list[i].name, style: GridTheme.mono, overflow: TextOverflow.ellipsis)),
                        if (list[i].hasSample) const Icon(Icons.graphic_eq, size: 14, color: GridTheme.accent),
                      ]),
                    ),
                  ),
                ),
              ),
              const Divider(),
              Padding(
                padding: const EdgeInsets.all(12),
                child: _Editor(model: model, info: sel),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _Editor extends StatelessWidget {
  const _Editor({required this.model, required this.info});

  final TrackerModel model;
  final InstrumentInfo info;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        OutlinedButton.icon(
          onPressed: () async {
            final path = await Files.pickSample();
            if (path != null) model.loadSample(path);
          },
          icon: const Icon(Icons.upload_file, size: 18),
          label: const Text('WAV-Sample laden …'),
        ),
        const SizedBox(height: 8),
        _slider('Lautstärke', info.volume, 0, 1, InstrumentParam.volume),
        _slider('Stimmung', info.tune, -24, 24, InstrumentParam.tune),
        _slider('Attack', info.attack, 0.001, 1, InstrumentParam.attack),
        _slider('Release', info.release, 0.005, 2, InstrumentParam.release),
        SwitchListTile(
          dense: true,
          contentPadding: EdgeInsets.zero,
          title: const Text('Loop', style: TextStyle(fontSize: 12)),
          value: info.looped,
          onChanged: (v) => model.setParam(InstrumentParam.looped, v ? 1 : 0),
        ),
      ],
    );
  }

  Widget _slider(String title, double value, double min, double max, InstrumentParam param) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(children: [
          Text(title, style: const TextStyle(fontSize: 11, color: GridTheme.dim)),
          const Spacer(),
          Text(value.toStringAsFixed(2), style: GridTheme.mono.copyWith(fontSize: 11)),
        ]),
        SizedBox(
          height: 28,
          child: Slider(value: value.clamp(min, max), min: min, max: max, onChanged: (v) => model.setParam(param, v)),
        ),
      ],
    );
  }
}
