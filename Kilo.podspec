Pod::Spec.new do |s|
  s.name            = 'Kilo'
  s.version         = '1.0.4'
  s.license         = 'Apache License, Version 2.0'
  s.homepage        = 'https://github.com/gk-brown/Lima'
  s.author          = 'Greg Brown'
  s.summary         = 'Lightweight REST for iOS and tvOS'
  s.source          = { :git => "https://github.com/gk-brown/Kilo.git", :tag => s.version.to_s }
  s.swift_version   = '4.2'

  s.ios.deployment_target   = '10.0'
  s.ios.source_files        = 'Kilo-iOS/Kilo/*.{h,m,swift}'
  s.tvos.deployment_target  = '10.0'
  s.tvos.source_files       = 'Kilo-iOS/Kilo/*.{h,m,swift}'
end