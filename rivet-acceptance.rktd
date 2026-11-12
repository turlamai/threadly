#hasheq(
 (version . 1)
 (requirements
  . (#hasheq((kind . contract) (platforms . (windows macos linux)))
     #hasheq((kind . native-build) (platforms . (windows macos linux)))))
 (suites
  . (#hasheq((id . core-contract) (kind . contract)
             (platforms . (windows macos linux))
             (command . ("raco" "test" "tests/")) (timeout-seconds . 1200))
     #hasheq((id . native-host) (kind . native-build)
             (platforms . (windows macos linux))
             (command . ("raco" "rivet" "build")) (timeout-seconds . 2400)))))
