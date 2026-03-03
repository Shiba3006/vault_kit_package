Pod::Spec.new do |s|
  s.name             = 'vault_kit'
  s.version          = '1.0.0'
  s.summary          = 'Secure credential storage using Android Keystore and iOS Keychain.'
  s.description      = 'A Flutter plugin for secure credential storage using Android Keystore (AES-256-GCM) and iOS Keychain.'
  s.homepage         = 'https://github.com/yourusername/vault_kit'
  s.license          = { :type => 'MIT', :file => '../LICENSE' }
  s.author           = { 'Your Name' => 'your@email.com' }
  s.source           = { :path => '.' }
  s.source_files     = 'Classes/**/*'
  s.platform         = :ios, '11.0'

  s.dependency 'Flutter'

  s.pod_target_xcconfig = { 'DEFINES_MODULE' => 'YES', 'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386' }
  s.swift_version = '5.0'
end