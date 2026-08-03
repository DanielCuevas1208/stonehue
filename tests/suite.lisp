(in-package :stonehue/tests)

(def-suite stonehue-suite
  :description "The complete Stonehue test suite.")

(defun play-at (pos color vertex)
  "Force COLOR to play at VERTEX on POS, ignoring the turn order."
  (setf (position-to-play pos) color)
  (try-play pos color (vertex->index (position-size pos) vertex)))

(defun index (pos vertex)
  "Return the flat index of VERTEX on the board of POS."
  (vertex->index (position-size pos) vertex))

(defun run-tests ()
  "Run the whole suite and signal an error when any test fails."
  (let ((status (run! 'stonehue-suite)))
    (unless status
      (error "The Stonehue test suite reported failures."))
    (format t "~%Stonehue test suite: all tests passed.~%")
    status))
