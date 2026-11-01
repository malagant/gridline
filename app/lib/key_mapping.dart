import 'package:flutter/services.dart';

import 'tracker_model.dart';

/// Belegung nach physischer Tastenposition, unabhängig vom Layout (QWERTZ/QWERTY).
final Map<PhysicalKeyboardKey, int> pianoKeys = {
  // untere Reihe: Y/Z S X D C V G B H N J M
  PhysicalKeyboardKey.keyZ: 0, PhysicalKeyboardKey.keyS: 1, PhysicalKeyboardKey.keyX: 2,
  PhysicalKeyboardKey.keyD: 3, PhysicalKeyboardKey.keyC: 4, PhysicalKeyboardKey.keyV: 5,
  PhysicalKeyboardKey.keyG: 6, PhysicalKeyboardKey.keyB: 7, PhysicalKeyboardKey.keyH: 8,
  PhysicalKeyboardKey.keyN: 9, PhysicalKeyboardKey.keyJ: 10, PhysicalKeyboardKey.keyM: 11,
  // obere Reihe: Q 2 W 3 E R 5 T 6 Z/Y 7 U (eine Oktave höher)
  PhysicalKeyboardKey.keyQ: 12, PhysicalKeyboardKey.digit2: 13, PhysicalKeyboardKey.keyW: 14,
  PhysicalKeyboardKey.digit3: 15, PhysicalKeyboardKey.keyE: 16, PhysicalKeyboardKey.keyR: 17,
  PhysicalKeyboardKey.digit5: 18, PhysicalKeyboardKey.keyT: 19, PhysicalKeyboardKey.digit6: 20,
  PhysicalKeyboardKey.keyY: 21, PhysicalKeyboardKey.digit7: 22, PhysicalKeyboardKey.keyU: 23,
};

/// Verarbeitet eine Taste. Gibt `true` zurück, wenn sie verbraucht wurde.
bool handleTrackerKey(KeyEvent event, TrackerModel model) {
  if (event is KeyUpEvent) return false;
  final keys = HardwareKeyboard.instance;
  if (keys.isControlPressed || keys.isMetaPressed || keys.isAltPressed) return false;
  final shift = keys.isShiftPressed;
  final key = event.physicalKey;
  final repeat = event is KeyRepeatEvent;

  if (key == PhysicalKeyboardKey.space) {
    if (!repeat) model.togglePlay();
  } else if (key == PhysicalKeyboardKey.arrowUp) {
    shift ? model.shiftOctave(1) : model.moveStep(-1);
  } else if (key == PhysicalKeyboardKey.arrowDown) {
    shift ? model.shiftOctave(-1) : model.moveStep(1);
  } else if (key == PhysicalKeyboardKey.arrowLeft) {
    model.moveTrack(-1);
  } else if (key == PhysicalKeyboardKey.arrowRight) {
    model.moveTrack(1);
  } else if (key == PhysicalKeyboardKey.pageUp) {
    model.moveStep(-16);
  } else if (key == PhysicalKeyboardKey.pageDown) {
    model.moveStep(16);
  } else if (key == PhysicalKeyboardKey.backspace || key == PhysicalKeyboardKey.delete) {
    model.clearStep();
  } else if (key == PhysicalKeyboardKey.keyA) {
    if (!repeat) model.enterNoteOff();
  } else if (pianoKeys[key] case final semitone?) {
    if (!repeat) model.enterSemitone(semitone);
  } else {
    return false;
  }
  return true;
}
