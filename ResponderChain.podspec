Pod::Spec.new do |s|
  s.name             = 'ResponderChain'
  s.version          = '1.1.1'
  s.summary          = 'Cross-platform first responder handling without subclassing views or making custom ViewRepresentables in SwiftUI'
  s.license = { type: 'MIT' }
  s.homepage         = 'https://github.com/Amzd/ResponderChain'
  s.author           = { 'Casper Zandbergen' => 'info@casperzandbergen.nl' }
  s.source           = { :git => 'https://github.com/Amzd/ResponderChain.git', :tag => s.version.to_s }
  s.dependency 'Introspect', '0.1.2'
  s.dependency 'SwizzleSwift'
  s.source_files = 'Sources/**/*.swift'
  
  s.swift_version = '5.1'
  s.ios.deployment_target = '11.0'
#   s.tvos.deployment_target = '11.0' # SwizzleSwift doesn't support tvos on cocoapods
  s.osx.deployment_target = '10.13'
end
