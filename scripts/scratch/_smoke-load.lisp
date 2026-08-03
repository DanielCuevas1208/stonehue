(require :asdf)
(when (probe-file (merge-pathnames "quicklisp/setup.lisp"
                                   (user-homedir-pathname)))
  (load (merge-pathnames "quicklisp/setup.lisp"
                         (user-homedir-pathname))))
(handler-case
    (asdf:load-asd (merge-pathnames "../../stonehue.asd"
                                    (or *load-pathname* *load-truename*)))
  (error (e)
    (format t "LOADASD FAILED: ~a~%" e)
    (sb-ext:exit :code 1)))
(handler-case
    (asdf:load-system :stonehue)
  (error (e)
    (format t "LOAD FAILED: ~a~%" e)
    (sb-ext:exit :code 1)))
(format t "STONEHUE LOADED OK~%")
