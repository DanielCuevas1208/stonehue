(require :asdf)

(let* ((script (or *load-pathname* *load-truename*))
       (root (uiop:pathname-directory-pathname (truename script))))
  (asdf:load-asd (merge-pathnames "../stonehue.asd" root))
  (asdf:load-system :stonehue))

#+sbcl
(sb-ext:save-lisp-and-die
 "build/stonehue.exe"
 :executable t
 :toplevel (lambda ()
             (stonehue:run-gtp)
             (sb-ext:exit :code 0)))
