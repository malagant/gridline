Pod::Spec.new do |s|
  s.name             = 'gridline_native'
  s.version          = '0.1.0'
  s.summary          = 'Rust-Kern von Gridline als FFI-Plugin.'
  s.homepage         = 'https://github.com/malagant/gridline'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Michael Johann' => 'noreply@github.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.dependency 'Flutter'
  s.platform = :ios, '15.0'
  s.frameworks       = 'AudioToolbox', 'AVFoundation', 'CoreAudio'

  # Baut die statische Rust-Bibliothek vor dem Kompilieren des Plugins.
  s.script_phase = {
    :name => 'Rust-Kern bauen',
    :script => 'bash "${PODS_TARGET_SRCROOT}/../scripts/build_apple.sh"',
    :execution_position => :before_compile,
    :always_out_of_date => '1',
  }

  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'OTHER_LDFLAGS' => '-force_load ${PODS_TARGET_SRCROOT}/../build-rust/${PLATFORM_NAME}/libgridline_ffi.a',
  }
  s.swift_version = '5.0'
end
