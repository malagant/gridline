/// Dart-Anbindung an den Rust-Kern von Gridline.
///
/// Alle Aufrufe laufen synchron auf dem UI-Isolate. Der Rust-Kern übergibt
/// Befehle lock-frei an den Audio-Thread, daher blockiert hier nichts.
library;

import 'dart:convert';
import 'dart:ffi';
import 'dart:io';

import 'package:ffi/ffi.dart';

final class _Handle extends Opaque {}

typedef _H = Pointer<_Handle>;

DynamicLibrary _open() {
  if (Platform.isMacOS || Platform.isIOS) {
    // Statisch in das Plugin-Framework gelinkt.
    return DynamicLibrary.process();
  }
  if (Platform.isLinux) return DynamicLibrary.open('libgridline_ffi.so');
  if (Platform.isWindows) return DynamicLibrary.open('gridline_ffi.dll');
  throw UnsupportedError('Plattform ${Platform.operatingSystem} wird nicht unterstützt');
}

final DynamicLibrary _lib = _open();

final _new = _lib.lookupFunction<_H Function(Bool), _H Function(bool)>('gl_new');
final _free = _lib.lookupFunction<Void Function(_H), void Function(_H)>('gl_free');
final _audioStatus =
    _lib.lookupFunction<Pointer<Utf8> Function(_H), Pointer<Utf8> Function(_H)>('gl_audio_status');
final _hasAudio = _lib.lookupFunction<Bool Function(_H), bool Function(_H)>('gl_has_audio');
final _play = _lib.lookupFunction<Void Function(_H, Uint32), void Function(_H, int)>('gl_play');
final _stop = _lib.lookupFunction<Void Function(_H), void Function(_H)>('gl_stop');
final _isPlaying = _lib.lookupFunction<Bool Function(_H), bool Function(_H)>('gl_is_playing');
final _playhead = _lib.lookupFunction<Int32 Function(_H), int Function(_H)>('gl_playhead');
final _setBpm = _lib.lookupFunction<Void Function(_H, Double), void Function(_H, double)>('gl_set_bpm');
final _setLength =
    _lib.lookupFunction<Void Function(_H, Uint32), void Function(_H, int)>('gl_set_pattern_length');
final _enterNote = _lib.lookupFunction<Void Function(_H, Uint32, Uint32, Uint8, Uint32),
    void Function(_H, int, int, int, int)>('gl_enter_note');
final _noteOff =
    _lib.lookupFunction<Void Function(_H, Uint32, Uint32), void Function(_H, int, int)>('gl_note_off');
final _clear = _lib.lookupFunction<Void Function(_H, Uint32, Uint32), void Function(_H, int, int)>('gl_clear');
final _audition = _lib.lookupFunction<Void Function(_H, Uint32, Uint8, Uint32),
    void Function(_H, int, int, int)>('gl_audition');
final _setParam = _lib.lookupFunction<Bool Function(_H, Uint32, Uint32, Double),
    bool Function(_H, int, int, double)>('gl_set_instrument_param');
final _loadSample = _lib.lookupFunction<Pointer<Utf8> Function(_H, Uint32, Pointer<Utf8>),
    Pointer<Utf8> Function(_H, int, Pointer<Utf8>)>('gl_load_sample');
final _save = _lib.lookupFunction<Pointer<Utf8> Function(_H, Pointer<Utf8>),
    Pointer<Utf8> Function(_H, Pointer<Utf8>)>('gl_save');
final _load = _lib.lookupFunction<Pointer<Utf8> Function(_H, Pointer<Utf8>),
    Pointer<Utf8> Function(_H, Pointer<Utf8>)>('gl_load');
final _exportWav = _lib.lookupFunction<Pointer<Utf8> Function(_H, Pointer<Utf8>, Uint32),
    Pointer<Utf8> Function(_H, Pointer<Utf8>, int)>('gl_export_wav');
final _patternJson =
    _lib.lookupFunction<Pointer<Utf8> Function(_H), Pointer<Utf8> Function(_H)>('gl_pattern_json');
final _instrumentsJson =
    _lib.lookupFunction<Pointer<Utf8> Function(_H), Pointer<Utf8> Function(_H)>('gl_instruments_json');

/// Fehler aus dem Rust-Kern.
class GridlineException implements Exception {
  GridlineException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// Eine Zelle im Pattern, bereits als Text formatiert.
class Cell {
  const Cell(this.note, this.instrument, this.volume, this.fx);
  final String note;
  final String instrument;
  final String volume;
  final String fx;

  bool get hasNote => note != '---';
  bool get hasInstrument => instrument != '--';
  bool get hasVolume => volume != '--';
  bool get hasFx => fx != '---';
}

class PatternView {
  PatternView(this.length, this.bpm, this.tracks);
  final int length;
  final double bpm;

  /// `tracks[track][step]`
  final List<List<Cell>> tracks;

  int get trackCount => tracks.length;
}

class InstrumentInfo {
  InstrumentInfo.fromJson(Map<String, dynamic> j)
      : name = j['name'] as String,
        volume = (j['volume'] as num).toDouble(),
        tune = (j['tune'] as num).toDouble(),
        attack = (j['attack'] as num).toDouble(),
        release = (j['release'] as num).toDouble(),
        looped = j['looped'] as bool,
        hasSample = j['hasSample'] as bool;

  final String name;
  final double volume;
  final double tune;
  final double attack;
  final double release;
  final bool looped;
  final bool hasSample;
}

enum InstrumentParam { volume, tune, attack, release, looped }

/// Eine Gridline-Sitzung: Song, Samples und Audio-Engine.
class GridlineEngine {
  GridlineEngine({bool withAudio = true}) : _h = _new(withAudio);

  final _H _h;
  bool _disposed = false;

  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _free(_h);
  }

  String get audioStatus => _audioStatus(_h).toDartString();
  bool get hasAudio => _hasAudio(_h);

  void play({int fromStep = 0}) => _play(_h, fromStep);
  void stop() => _stop(_h);
  bool get isPlaying => _isPlaying(_h);

  /// Gerade spielender Step, -1 wenn gestoppt.
  int get playhead => _playhead(_h);

  set bpm(double value) => _setBpm(_h, value);
  set patternLength(int value) => _setLength(_h, value);

  void enterNote(int track, int step, int midi, int instrument) => _enterNote(_h, track, step, midi, instrument);
  void noteOff(int track, int step) => _noteOff(_h, track, step);
  void clear(int track, int step) => _clear(_h, track, step);
  void audition(int track, int midi, int instrument) => _audition(_h, track, midi, instrument);

  bool setInstrumentParam(int index, InstrumentParam param, double value) =>
      _setParam(_h, index, param.index, value);

  void loadSample(int index, String path) => _withPath(path, (p) => _loadSample(_h, index, p));
  void save(String path) => _withPath(path, (p) => _save(_h, p));
  void load(String path) => _withPath(path, (p) => _load(_h, p));
  void exportWav(String path, {int bars = 4}) => _withPath(path, (p) => _exportWav(_h, p, bars));

  PatternView pattern() {
    final j = jsonDecode(_patternJson(_h).toDartString()) as Map<String, dynamic>;
    final tracks = (j['tracks'] as List)
        .map((t) => (t as List).map((c) {
              final l = c as List;
              return Cell(l[0] as String, l[1] as String, l[2] as String, l[3] as String);
            }).toList())
        .toList();
    return PatternView(j['length'] as int, (j['bpm'] as num).toDouble(), tracks);
  }

  List<InstrumentInfo> instruments() => (jsonDecode(_instrumentsJson(_h).toDartString()) as List)
      .map((e) => InstrumentInfo.fromJson(e as Map<String, dynamic>))
      .toList();

  void _withPath(String path, Pointer<Utf8> Function(Pointer<Utf8>) call) {
    final p = path.toNativeUtf8();
    try {
      final err = call(p);
      if (err != nullptr) throw GridlineException(err.toDartString());
    } finally {
      malloc.free(p);
    }
  }
}
