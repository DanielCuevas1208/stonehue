(require :asdf)

(let* ((script (or *load-pathname* *load-truename*))
       (root (uiop:pathname-directory-pathname (truename script))))
  (asdf:load-asd (merge-pathnames "../stonehue.asd" root))
  (handler-bind ((warning #'muffle-warning))
    (asdf:load-system :stonehue)))

(stonehue:run-gtp)

#+sbcl
(sb-ext:exit :code 0)
