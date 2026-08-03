(require :asdf)
(when (probe-file (merge-pathnames "quicklisp/setup.lisp"
                                   (user-homedir-pathname)))
  (load (merge-pathnames "quicklisp/setup.lisp"
                         (user-homedir-pathname))))
(asdf:load-asd (merge-pathnames "../../stonehue.asd"
                                (or *load-pathname* *load-truename*)))
(handler-bind ((warning #'muffle-warning))
  (asdf:load-system :stonehue))
(in-package :stonehue)

(defun play-at (pos color vertex)
  (setf (position-to-play pos) color)
  (try-play pos color (vertex->index (position-size pos) vertex)))

(let ((pos (make-position 9)))
  (play-at pos +black+ "E7")
  (play-at pos +white+ "E6")
  (play-at pos +black+ "D6")
  (play-at pos +white+ "A1")
  (play-at pos +black+ "F6")
  (play-at pos +white+ "A2")
  (format t "to-play=~a~%" (color-name (position-to-play pos)))
  (format t "capture-count E5 for black = ~d~%"
          (capture-count pos +black+ (vertex->index 9 "E5")))
  (format t "capture-count E5 for white = ~d~%"
          (capture-count pos +white+ (vertex->index 9 "E5")))
  (format t "capture-count G9 for black = ~d~%"
          (capture-count pos +black+ (vertex->index 9 "G9"))))
