import 'dart:io';

import 'package:flutter/material.dart';

import 'instrument_panel.dart';
import 'key_mapping.dart';
import 'pattern_grid.dart';
import 'theme.dart';
import 'touch_keyboard.dart';
import 'tracker_model.dart';
import 'transport_bar.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key, this.model});

  /// Für Tests injizierbar.
  final TrackerModel? model;

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  late final TrackerModel model = widget.model ?? TrackerModel();
  final focus = FocusNode(debugLabel: 'tracker');
  late bool showKeyboard = Platform.isIOS || Platform.isAndroid;

  @override
  void dispose() {
    focus.dispose();
    if (widget.model == null) model.dispose();
    super.dispose();
  }

  void _openInstruments() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: GridTheme.panel,
      builder: (_) => FractionallySizedBox(heightFactor: 0.7, child: InstrumentPanel(model: model)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Focus(
          focusNode: focus,
          autofocus: true,
          onKeyEvent: (_, event) => handleTrackerKey(event, model) ? KeyEventResult.handled : KeyEventResult.ignored,
          child: LayoutBuilder(builder: (context, constraints) {
            final wide = constraints.maxWidth >= 900;
            return ListenableBuilder(
              listenable: model,
              builder: (context, _) => Column(
                children: [
                  TransportBar(
                    model: model,
                    onShowInstruments: wide ? null : _openInstruments,
                    keyboardVisible: showKeyboard,
                    onToggleKeyboard: () => setState(() => showKeyboard = !showKeyboard),
                  ),
                  const Divider(),
                  Expanded(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: GestureDetector(
                            onTapDown: (_) => focus.requestFocus(),
                            child: PatternGrid(model: model, compact: constraints.maxWidth < 600),
                          ),
                        ),
                        if (wide) ...[
                          const VerticalDivider(width: 1),
                          SizedBox(width: 260, child: InstrumentPanel(model: model)),
                        ],
                      ],
                    ),
                  ),
                  if (showKeyboard) ...[const Divider(), TouchKeyboard(model: model)],
                  const Divider(),
                  StatusBar(model: model, showHints: !showKeyboard),
                ],
              ),
            );
          }),
        ),
      ),
    );
  }
}

class StatusBar extends StatelessWidget {
  const StatusBar({super.key, required this.model, required this.showHints});

  final TrackerModel model;
  final bool showHints;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 11, color: GridTheme.dim);
    return Container(
      color: GridTheme.panel,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          if (showHints)
            const Flexible(
              child: Text(
                'Pfeile: bewegen · ⇧↑/⇧↓: Oktave · Y–M / Q–U: Noten · A: Note aus · ⌫: löschen · Leertaste: Play/Stopp',
                style: style,
                overflow: TextOverflow.ellipsis,
              ),
            ),
          const Spacer(),
          Flexible(
            child: Text(model.status,
                style: style.copyWith(color: GridTheme.text), overflow: TextOverflow.ellipsis, textAlign: TextAlign.end),
          ),
        ],
      ),
    );
  }
}
