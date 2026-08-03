(require :asdf)

(let* ((script (or *load-pathname* *load-truename*))
       (root (uiop:pathname-directory-pathname (truename script))))
  (asdf:load-asd (merge-pathnames "../stonehue.asd" root)))

#+sbcl
(handler-bind ((warning #'error))
  (asdf:load-system :stonehue)
  (format t "Stonehue compiled with no warnings.~%")
  (sb-ext:exit :code 0))
