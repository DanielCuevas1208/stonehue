(require :asdf)

(let* ((script (or *load-pathname* *load-truename*))
       (root (uiop:pathname-directory-pathname (truename script))))
  (asdf:load-asd (merge-pathnames "../stonehue.asd" root))
  (asdf:load-system :stonehue))

(in-package :stonehue)

(defun play-recorded-game
    (&key (size 9)
          (komi 6.5)
          (iterations 300)
          (seed 13)
          (max-moves 200)
          (output nil))
  "Play a fixed-seed self-play game and return its SGF text.
When OUTPUT is given, write the record to that file."
  (let ((engine (make-engine :size size :komi komi :strength 3 :seed seed)))
    (setf (engine-iterations engine) iterations)
    (loop while (and (< (position-move-number (engine-position engine))
                        max-moves)
                     (not (is-terminal-p (engine-position engine))))
          for color = (position-to-play (engine-position engine))
          do (engine-genmove engine color))
    (let ((sgf (engine-to-sgf-text engine)))
      (when output
        (with-open-file (out output :direction :output :if-exists :supersede)
          (write-string sgf out)))
      (format t "~%Played ~d moves on a ~dx~d board.~%"
              (length (engine-move-list engine)) size size)
      (format t "Result: ~a~%"
              (if (is-terminal-p (engine-position engine))
                  (score-string (engine-position engine) :komi komi)
                  "unfinished"))
      (values sgf engine))))

(let ((output (first (uiop:command-line-arguments))))
  (play-recorded-game :output output))

#+sbcl
(sb-ext:exit :code 0)
