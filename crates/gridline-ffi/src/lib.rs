//! C-Schnittstelle für die Flutter-App (dart:ffi).
//!
//! Alle Funktionen werden vom UI-Thread aufgerufen. Zurückgegebene Strings gehören
//! der Sitzung und bleiben bis zum nächsten String-Aufruf gültig.

#![allow(clippy::missing_safety_doc)]

mod audio;
pub mod session;

use std::ffi::{c_char, CStr, CString};

use session::Session;

/// Sitzung plus Puffer für zurückgegebene Strings.
pub struct Handle {
    session: Session,
    text: CString,
}

impl Handle {
    fn put(&mut self, s: String) -> *const c_char {
        self.text = CString::new(s).unwrap_or_default();
        self.text.as_ptr()
    }

    fn result(&mut self, r: Result<(), String>) -> *const c_char {
        match r {
            Ok(()) => std::ptr::null(),
            Err(e) => self.put(e),
        }
    }
}

unsafe fn handle<'a>(h: *mut Handle) -> &'a mut Handle {
    assert!(!h.is_null(), "Gridline-Handle ist null");
    &mut *h
}

unsafe fn text(p: *const c_char) -> String {
    if p.is_null() {
        String::new()
    } else {
        CStr::from_ptr(p).to_string_lossy().into_owned()
    }
}

#[no_mangle]
pub extern "C" fn gl_new(with_audio: bool) -> *mut Handle {
    Box::into_raw(Box::new(Handle { session: Session::new(with_audio), text: CString::default() }))
}

#[no_mangle]
pub unsafe extern "C" fn gl_free(h: *mut Handle) {
    if !h.is_null() {
        drop(Box::from_raw(h));
    }
}

#[no_mangle]
pub unsafe extern "C" fn gl_audio_status(h: *mut Handle) -> *const c_char {
    let h = handle(h);
    let s = h.session.audio_status.clone();
    h.put(s)
}

#[no_mangle]
pub unsafe extern "C" fn gl_has_audio(h: *mut Handle) -> bool {
    handle(h).session.has_audio()
}

#[no_mangle]
pub unsafe extern "C" fn gl_play(h: *mut Handle, from_step: u32) {
    handle(h).session.play(from_step as usize);
}

#[no_mangle]
pub unsafe extern "C" fn gl_stop(h: *mut Handle) {
    handle(h).session.stop();
}

#[no_mangle]
pub unsafe extern "C" fn gl_is_playing(h: *mut Handle) -> bool {
    handle(h).session.is_playing()
}

#[no_mangle]
pub unsafe extern "C" fn gl_playhead(h: *mut Handle) -> i32 {
    handle(h).session.playhead()
}

#[no_mangle]
pub unsafe extern "C" fn gl_set_bpm(h: *mut Handle, bpm: f64) {
    handle(h).session.set_bpm(bpm);
}

#[no_mangle]
pub unsafe extern "C" fn gl_set_pattern_length(h: *mut Handle, length: u32) {
    handle(h).session.set_pattern_length(length as usize);
}

#[no_mangle]
pub unsafe extern "C" fn gl_enter_note(h: *mut Handle, track: u32, step: u32, midi: u8, instrument: u32) {
    handle(h).session.enter_note(track as usize, step as usize, midi, instrument as usize);
}

#[no_mangle]
pub unsafe extern "C" fn gl_note_off(h: *mut Handle, track: u32, step: u32) {
    handle(h).session.note_off(track as usize, step as usize);
}

#[no_mangle]
pub unsafe extern "C" fn gl_clear(h: *mut Handle, track: u32, step: u32) {
    handle(h).session.clear(track as usize, step as usize);
}

#[no_mangle]
pub unsafe extern "C" fn gl_audition(h: *mut Handle, track: u32, midi: u8, instrument: u32) {
    handle(h).session.audition(track as usize, midi, instrument as usize);
}

/// Parameter: 0 Lautstärke, 1 Stimmung, 2 Attack, 3 Release, 4 Loop (0/1).
#[no_mangle]
pub unsafe extern "C" fn gl_set_instrument_param(h: *mut Handle, index: u32, param: u32, value: f64) -> bool {
    handle(h).session.set_instrument_param(index as usize, param, value)
}

/// Gibt `null` bei Erfolg zurück, sonst eine Fehlermeldung.
#[no_mangle]
pub unsafe extern "C" fn gl_load_sample(h: *mut Handle, index: u32, path: *const c_char) -> *const c_char {
    let h = handle(h);
    let r = h.session.load_sample(index as usize, &text(path));
    h.result(r)
}

#[no_mangle]
pub unsafe extern "C" fn gl_save(h: *mut Handle, path: *const c_char) -> *const c_char {
    let h = handle(h);
    let r = h.session.save(&text(path));
    h.result(r)
}

#[no_mangle]
pub unsafe extern "C" fn gl_load(h: *mut Handle, path: *const c_char) -> *const c_char {
    let h = handle(h);
    let r = h.session.load(&text(path));
    h.result(r)
}

#[no_mangle]
pub unsafe extern "C" fn gl_export_wav(h: *mut Handle, path: *const c_char, bars: u32) -> *const c_char {
    let h = handle(h);
    let r = h.session.export_wav(&text(path), bars as usize);
    h.result(r)
}

/// `{ "length": n, "bpm": x, "tracks": [[[note, inst, vol, fx], …], …] }`
#[no_mangle]
pub unsafe extern "C" fn gl_pattern_json(h: *mut Handle) -> *const c_char {
    let h = handle(h);
    let s = h.session.pattern_json().to_string();
    h.put(s)
}

/// `[{ "name", "volume", "tune", "attack", "release", "looped", "hasSample" }, …]`
#[no_mangle]
pub unsafe extern "C" fn gl_instruments_json(h: *mut Handle) -> *const c_char {
    let h = handle(h);
    let s = h.session.instruments_json().to_string();
    h.put(s)
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn c_api_round_trip() {
        unsafe {
            let h = gl_new(false);
            assert!(!gl_has_audio(h));
            gl_enter_note(h, 2, 3, 60, 1);
            let json = CStr::from_ptr(gl_pattern_json(h)).to_str().unwrap().to_owned();
            assert!(json.contains("\"C-4\""));
            let path = CString::new("/nicht/vorhanden.wav").unwrap();
            assert!(!gl_load_sample(h, 0, path.as_ptr()).is_null());
            gl_free(h);
        }
    }
}
