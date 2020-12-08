Pod::Spec.new do |s|
  s.name             = 'ResponderChain'
  s.version          = '1.0.0'
  s.summary          = 'Cross-platform first responder handling without subclassing views or making custom ViewRepresentables in SwiftUI'
  s.homepage         = 'https://github.com/Amzd/ResponderChain'
  s.author           = { 'Casper Zandbergen' => 'info@casperzandbergen.nl' }
  s.source           = { :git => 'https://github.com/amzd/ResponderChain.git', :tag => s.version.to_s }
  s.dependency 'Introspect', '>= 0.1.1'
  s.source_files = 'Sources/**/*.swift'
  
  s.swift_version = '5.1'
  s.ios.deployment_target = '13.0'
  s.tvos.deployment_target = '13.0'
  s.osx.deployment_target = '10.15'
end
