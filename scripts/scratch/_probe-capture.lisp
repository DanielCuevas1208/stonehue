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

(dolist (iter '(1200 2000))
  (let* ((pos (make-position 9))
         (rng (make-rng 5)))
    (play-at pos +black+ "E7")
    (play-at pos +white+ "E6")
    (play-at pos +black+ "D6")
    (play-at pos +white+ "A1")
    (play-at pos +black+ "F6")
    (play-at pos +white+ "A2")
    (multiple-value-bind (move stats)
        (mcts-search pos :iterations iter :rng rng :komi 0.0)
      (format t "iter=~d move=~a~%"
              iter (if (eq move :pass) "pass" (index->vertex 9 move)))
      (format t "  top5: ~{~a~^, ~}~%"
              (loop for (m p w r) in (subseq stats 0 5)
                    collect (format nil "~a(~d/~d/~,2f)"
                                    (if (eq m :pass) "pass" (index->vertex 9 m))
                                    p w r))))))
