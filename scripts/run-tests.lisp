(require :asdf)

(when (probe-file (merge-pathnames "quicklisp/setup.lisp"
                                   (user-homedir-pathname)))
  (load (merge-pathnames "quicklisp/setup.lisp"
                         (user-homedir-pathname))))

(let* ((script (or *load-pathname* *load-truename*))
       (root (uiop:pathname-directory-pathname (truename script))))
  (asdf:load-asd (merge-pathnames "../stonehue.asd" root)))

#+sbcl
(handler-bind ((warning #'muffle-warning))
  (handler-case
      (progn
        (asdf:test-system :stonehue)
        (sb-ext:exit :code 0))
    (error (e)
      (format *error-output* "~%Stonehue tests failed: ~a~%" e)
      (sb-ext:exit :code 1))))
