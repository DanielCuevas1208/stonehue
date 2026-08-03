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

(let* ((pos (make-position 9))
       (rng (make-rng 5)))
  (play-at pos +black+ "E7")
  (play-at pos +white+ "E6")
  (play-at pos +black+ "D6")
  (play-at pos +white+ "A1")
  (play-at pos +black+ "F6")
  (play-at pos +white+ "A2")
  (multiple-value-bind (move stats)
      (mcts-search pos :iterations 1500 :rng rng :komi 0.0)
    (format t "chosen=~a~%" (index->vertex 9 move))
    (dolist (entry stats)
      (destructuring-bind (m plays wins rate) entry
        (when (and (integerp m)
                   (or (= m (vertex->index 9 "E5"))
                       (> plays 20)))
          (format t "  ~a plays=~d wins=~d rate=~,3f~%"
                  (index->vertex 9 m) plays wins rate))))))
