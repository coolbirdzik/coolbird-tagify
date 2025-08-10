#
# To learn more about a Podspec see http://guides.cocoapods.org/syntax/podspec.html.
# Run `pod lib lint mobile_smb_native.podspec` to validate before publishing.
#
Pod::Spec.new do |s|
  s.name             = 'mobile_smb_native'
  s.version          = '0.0.1'
  s.summary          = 'A Flutter plugin for SMB file sharing on mobile platforms.'
  s.description      = <<-DESC
A Flutter plugin for SMB (Server Message Block) file sharing on mobile platforms.
                       DESC
  s.homepage         = 'http://example.com'
  s.license          = { :file => '../LICENSE' }
  s.author           = { 'Your Company' => 'email@example.com' }
  s.source           = { :path => '.' }
  s.source_files = 'Classes/**/*', '../native/smb_bridge_stub.cpp'
  s.public_header_files = 'Classes/**/*.h'
  s.dependency 'Flutter'
  s.platform = :ios, '11.0'

  # Configure C++ compilation
  s.pod_target_xcconfig = {
    'DEFINES_MODULE' => 'YES',
    'EXCLUDED_ARCHS[sdk=iphonesimulator*]' => 'i386',
    'CLANG_CXX_LANGUAGE_STANDARD' => 'c++17',
    'CLANG_CXX_LIBRARY' => 'libc++',
    'HEADER_SEARCH_PATHS' => '$(SRCROOT)/../native/include $(SRCROOT)/../native/src'
  }
  s.swift_version = '5.0'
end
