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

(dolist (iter '(120 300 600 1000))
  (let* ((pos (make-position 9))
         (rng (make-rng 7))
         (move (mcts-search pos
                            :iterations iter
                            :rng rng
                            :opening-fn 'opening-hint-table
                            :opening-move-limit 4)))
    (format t "iter=~d move=~a~%" iter
            (if (eq move :pass) "pass" (index->vertex 9 move)))))
