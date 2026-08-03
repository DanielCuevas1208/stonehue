(in-package :stonehue/tests)

(in-suite stonehue-suite)

(test scoring-empty-board
  (let ((pos (make-position 9)))
    (multiple-value-bind (black white) (score-position pos :komi 6.5)
      (is (= 0 black))
      (is (= 6.5 white)))
    (is (= -6.5 (score-margin pos :komi 6.5)))))

(test scoring-stones-count
  (let ((pos (make-position 9)))
    (play-at pos +black+ "D4")
    (play-at pos +white+ "D5")
    (play-at pos +black+ "E4")
    (play-at pos +white+ "E5")
    (multiple-value-bind (black white) (score-position pos :komi 6.5)
      (is (= 2 black))
      (is (= 8.5 white)))))

(test scoring-territory-classification
  (let ((pos (make-position 9)))
    ;; A black ring encloses one empty point at D4.
    (play-at pos +black+ "C3")
    (play-at pos +white+ "A1")
    (play-at pos +black+ "D3")
    (play-at pos +white+ "A9")
    (play-at pos +black+ "E3")
    (play-at pos +white+ "J1")
    (play-at pos +black+ "C4")
    (play-at pos +white+ "J9")
    (play-at pos +black+ "E4")
    (play-at pos +white+ "A2")
    (play-at pos +black+ "C5")
    (play-at pos +white+ "J2")
    (play-at pos +black+ "D5")
    (play-at pos +white+ "A3")
    (play-at pos +black+ "E5")
    (play-at pos +white+ "J3")
    (multiple-value-bind (black white dame) (territory-of pos)
      (is (= 1 black))
      (is (= 0 white))
      (is (plusp dame)))
    (multiple-value-bind (black white) (score-position pos :komi 6.5)
      (is (= 9 black))
      (is (= 14.5 white)))))

(test scoring-string-format
  (is (string= "W+6.5" (score-string (make-position 9) :komi 6.5)))
  (is (string= "B+3.5" (score-string (make-position 9) :komi -3.5))))
