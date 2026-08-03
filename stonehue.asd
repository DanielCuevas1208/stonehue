(asdf:defsystem "stonehue"
  :description "A Go engine for small boards with Monte Carlo tree search and the Go Text Protocol."
  :long-description
  "Stonehue plays the board game Go on boards from 3x3 to 19x19. It applies
the capture rules and simple area scoring. It chooses moves with Monte Carlo
tree search. It answers Go Text Protocol (GTP) commands so standard tools can
play against it."
  :author "Stonehue contributors"
  :license "MIT"
  :version "0.2.0"
  :serial t
  :components
  ((:module "src"
    :components
    ((:file "packages")
     (:file "random")
     (:file "board")
     (:file "rules")
     (:file "render")
     (:file "scoring")
     (:file "mcts")
     (:file "opening")
     (:file "engine")
     (:file "sgf")
     (:file "gtp"))))
  :in-order-to ((asdf:test-op (asdf:test-op "stonehue/tests"))))

(asdf:defsystem "stonehue/tests"
  :description "The FiveAM test suite for Stonehue."
  :author "Stonehue contributors"
  :license "MIT"
  :version "0.2.0"
  :depends-on ("stonehue" "fiveam")
  :serial t
  :components
  ((:module "tests"
    :components
    ((:file "packages")
     (:file "suite")
     (:file "board-tests")
     (:file "rules-tests")
     (:file "scoring-tests")
     (:file "mcts-tests")
     (:file "opening-tests")
     (:file "engine-tests")
     (:file "sgf-tests")
     (:file "gtp-tests"))))
  :perform (asdf:test-op (op c)
             (uiop:symbol-call :stonehue/tests :run-tests)))
