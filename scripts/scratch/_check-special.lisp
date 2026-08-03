(require :asdf)
(when (probe-file (merge-pathnames "quicklisp/setup.lisp"
                                   (user-homedir-pathname)))
  (load (merge-pathnames "quicklisp/setup.lisp"
                         (user-homedir-pathname))))
(asdf:load-asd (merge-pathnames "../../stonehue.asd"
                                (or *load-pathname* *load-truename*)))
(handler-bind ((warning #'(lambda (c) (declare (ignore c)) (muffle-warning))))
  (asdf:load-system :stonehue))
(format t "SPECIAL-P: ~a~%" (and (find-symbol "+VERSION+" :stonehue)
                                 (multiple-value-list
                                  (special-operator-p (find-symbol "+VERSION+" :stonehue)))
                                 (sb-int:info :variable :kind
                                              (find-symbol "+VERSION+" :stonehue))))
(format t "DONE~%")
