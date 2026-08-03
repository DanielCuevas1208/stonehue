(require :asdf)

(let* ((script (or *load-pathname* *load-truename*))
       (root (uiop:pathname-directory-pathname (truename script))))
  (asdf:load-asd (merge-pathnames "../stonehue.asd" root))
  (asdf:load-system :stonehue))

(in-package :stonehue)

(defun play-selfplay-game
    (&key (size 9)
          (komi 6.5)
          (iterations 300)
          (seed 11)
          (max-moves 220)
          (opening-move-limit 4)
          (verbose t))
  "Play a full game between two Stonehue search instances.
Return the final position and the list of moves in GTP notation."
  (let ((pos (make-position size))
        (rng (make-rng seed))
        (moves '())
        (move-count 0))
    (when verbose
      (format t "~%Stonehue self-play on a ~dx~d board, komi ~a.~%"
              size size komi))
    (loop while (and (< move-count max-moves)
                     (not (is-terminal-p pos)))
          for color = (position-to-play pos)
          do (multiple-value-bind (move stats)
                 (mcts-search pos
                              :iterations iterations
                              :rng rng
                              :komi 0.0d0
                              :opening-fn 'opening-hint-table
                              :opening-move-limit opening-move-limit
                              :max-branching 60)
               (declare (ignore stats))
               (if (eq move :pass)
                   (pass-move pos color)
                   (try-play pos color move))
               (incf move-count)
               (push (if (eq move :pass)
                         "pass"
                         (index->vertex size move))
                     moves)
               (when verbose
                 (format t "Move ~3d ~5a: ~a~%"
                         move-count (color-name color)
                         (if (eq move :pass)
                             "pass"
                             (index->vertex size move))))))
    (when verbose
      (format t "~%~a" (render-position pos))
      (multiple-value-bind (black white) (score-position pos :komi komi)
        (format t "Black ~,1f - ~,1f White (komi ~,1f).~%"
                black white komi))
      (format t "Result: ~a~%" (score-string pos :komi komi)))
    (values pos (nreverse moves))))

(play-selfplay-game)

#+sbcl
(sb-ext:exit :code 0)
