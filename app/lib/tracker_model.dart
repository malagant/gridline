import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:gridline_native/gridline_native.dart';

/// UI-Zustand von Gridline. Song und Audio liegen im Rust-Kern,
/// hier sind nur Cursor, Auswahl und zwischengespeicherte Ansichten.
class TrackerModel extends ChangeNotifier {
  TrackerModel({GridlineEngine? engine}) : engine = engine ?? GridlineEngine() {
    _refresh();
    status = this.engine.audioStatus;
    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _poll());
  }

  final GridlineEngine engine;
  late Timer _ticker;

  late PatternView pattern;
  late List<InstrumentInfo> instruments;

  int cursorTrack = 0;
  int cursorStep = 0;
  int octave = 4;
  int selectedInstrument = 0;
  int playhead = -1;
  bool isPlaying = false;
  String status = '';

  static const trackCount = 8;
  static const maxLength = 128;

  @override
  void dispose() {
    _ticker.cancel();
    engine.dispose();
    super.dispose();
  }

  void _refresh() {
    pattern = engine.pattern();
    instruments = engine.instruments();
  }

  void _changed() {
    _refresh();
    notifyListeners();
  }

  void _poll() {
    final p = engine.playhead;
    if (p != playhead) {
      playhead = p;
      notifyListeners();
    }
  }

  // Transport

  void togglePlay() {
    if (isPlaying) {
      engine.stop();
    } else {
      engine.play();
    }
    isPlaying = !isPlaying;
    notifyListeners();
  }

  void setBpm(double bpm) {
    engine.bpm = bpm;
    _changed();
  }

  void setPatternLength(int length) {
    engine.patternLength = length;
    _refresh();
    cursorStep = cursorStep.clamp(0, pattern.length - 1);
    notifyListeners();
  }

  // Cursor

  void moveTrack(int delta) {
    cursorTrack = (cursorTrack + delta) % trackCount;
    notifyListeners();
  }

  void moveStep(int delta) {
    final len = pattern.length;
    cursorStep = (cursorStep + delta) % len;
    notifyListeners();
  }

  void select(int track, int step) {
    cursorTrack = track;
    cursorStep = step;
    notifyListeners();
  }

  void shiftOctave(int delta) {
    octave = (octave + delta).clamp(0, 8);
    notifyListeners();
  }

  // Editieren

  /// Halbton relativ zum C der aktuellen Oktave.
  void enterSemitone(int semitone) => enterNote((octave + 1) * 12 + semitone);

  void enterNote(int midi) {
    engine.enterNote(cursorTrack, cursorStep, midi.clamp(12, 119), selectedInstrument);
    cursorStep = (cursorStep + 1) % pattern.length;
    _changed();
  }

  void enterNoteOff() {
    engine.noteOff(cursorTrack, cursorStep);
    cursorStep = (cursorStep + 1) % pattern.length;
    _changed();
  }

  void clearStep() {
    engine.clear(cursorTrack, cursorStep);
    cursorStep = (cursorStep + 1) % pattern.length;
    _changed();
  }

  // Instrumente

  void selectInstrument(int index) {
    selectedInstrument = index;
    notifyListeners();
  }

  void setParam(InstrumentParam param, double value) {
    engine.setInstrumentParam(selectedInstrument, param, value);
    _changed();
  }

  // Dateien

  void run(String success, void Function() action) {
    try {
      action();
      status = success;
    } on GridlineException catch (e) {
      status = e.message;
    }
    _changed();
  }

  void loadSample(String path) =>
      run('Sample geladen: ${path.split(RegExp(r'[/\\]')).last}', () => engine.loadSample(selectedInstrument, path));
  void saveProject(String path) => run('Gesichert: $path', () => engine.save(path));
  void openProject(String path) => run('Geöffnet: $path', () {
        engine.load(path);
        isPlaying = false;
        cursorStep = 0;
      });
  void exportWav(String path) => run('Exportiert: $path', () => engine.exportWav(path, bars: 4));
}
