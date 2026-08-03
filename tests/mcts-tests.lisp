(in-package :stonehue/tests)

(in-suite stonehue-suite)

(test mcts-empty-board-returns-legal-move
  (let* ((pos (make-position 9))
         (rng (make-rng 1))
         (move (mcts-search pos :iterations 80 :rng rng)))
    (is (or (integerp move) (eq move :pass)))
    (when (integerp move)
      (is (= +empty+ (stone-at pos move))))))

(test mcts-favors-opening-star-point
  (let* ((pos (make-position 9))
         (rng (make-rng 7))
         (move (mcts-search pos
                            :iterations 120
                            :rng rng
                            :opening-fn 'opening-hint-table
                            :opening-move-limit 4)))
    (is (integerp move))
    (let ((vertex (index->vertex 9 move)))
      (is (member vertex '("D4" "F4" "D6" "F6" "E5")
                  :test #'string=)))))

(test mcts-deterministic-with-seed
  (labels ((search-once ()
             (let* ((pos (make-position 9))
                    (rng (make-rng 42)))
               (play-at pos +black+ "D4")
               (play-at pos +white+ "F4")
               (mcts-search pos
                            :iterations 150
                            :rng rng
                            :komi 6.5
                            :opening-fn 'opening-hint-table
                            :opening-move-limit 4))))
    (is (equal (search-once) (search-once)))))

(test mcts-finds-capture
  (let* ((pos (make-position 9))
         (rng (make-rng 5)))
    ;; White's single stone at E6 has one liberty left at E5.
    (play-at pos +black+ "E7")
    (play-at pos +white+ "E6")
    (play-at pos +black+ "D6")
    (play-at pos +white+ "A1")
    (play-at pos +black+ "F6")
    (play-at pos +white+ "A2")
    (let* ((move (mcts-search pos
                              :iterations 600
                              :rng rng
                              :komi 0.0)))
      (is (eql (vertex->index 9 "E5") move)))))

(test mcts-never-chooses-illegal-move
  (dotimes (seed 5)
    (let* ((pos (make-position 9))
           (rng (make-rng (+ 200 seed))))
      (play-at pos +black+ "D4")
      (play-at pos +white+ "G6")
      (play-at pos +black+ "G3")
      (let ((move (mcts-search pos
                               :iterations 100
                               :rng rng
                               :komi 6.5)))
        (is (or (eq move :pass)
                (legal-move-p pos (position-to-play pos) move)))))))

(test mcts-pass-is-an-option
  (let* ((pos (make-position 9))
         (rng (make-rng 3)))
    (dotimes (i 20)
      (let ((move (mcts-search pos :iterations 60 :rng rng :komi 6.5)))
        (is (or (integerp move) (eq move :pass)))))))

(test mcts-analyze-reports-legal-moves
  (let* ((pos (make-position 9))
         (rng (make-rng 9)))
    (multiple-value-bind (move stats)
        (mcts-search pos :iterations 120 :rng rng)
      (declare (ignore move))
      (is (plusp (length stats)))
      (dolist (entry stats)
        (destructuring-bind (m plays wins rate) entry
          (is (or (eq m :pass) (integerp m)))
          (is (plusp plays))
          (is (<= 0 rate 1))
          (is (<= 0 wins plays)))))))
