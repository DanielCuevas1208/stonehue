(load (merge-pathnames "../src/packages.lisp"
                      (or *load-pathname* *load-truename*)))
(in-package :stonehue)
(format t "AFTER-LOAD BOUND: ~a VAL: ~a KIND: ~a~%"
        (boundp '+version+)
        (and (boundp '+version+) (symbol-value '+version+))
        (sb-int:info :variable :kind '+version+))
(defparameter +version+ "0.1.0")
(format t "AFTER-DEFPARAMETER BOUND: ~a VAL: ~a KIND: ~a~%"
        (boundp '+version+)
        (and (boundp '+version+) (symbol-value '+version+))
        (sb-int:info :variable :kind '+version+))
