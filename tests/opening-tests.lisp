(in-package :stonehue/tests)

(in-suite stonehue-suite)

(test opening-hints-on-empty-board
  (let ((hints (opening-hints (make-position 9))))
    (is (plusp (length hints)))
    (destructuring-bind (idx weight name) (first hints)
      (declare (ignore weight))
      (is (string= "Hoshi" name))
      (is (string= "D4" (index->vertex 9 idx))))))

(test opening-hints-offer-only-empty-points
  (let ((pos (make-position 9)))
    (dolist (hint (opening-hints pos))
      (is (= +empty+ (stone-at pos (first hint)))))))

(test opening-hints-sorted-by-weight
  (let ((hints (opening-hints (make-position 19))))
    (loop for (a b) on hints
          while b
          do (is (>= (second a) (second b))))))

(test opening-hints-respect-board-size
  (is (zerop (length (opening-hints (make-position 3)))))
  (is (plusp (length (opening-hints (make-position 7)))))
  (is (plusp (length (opening-hints (make-position 19))))))

(test opening-hints-avoid-occupied-points
  (let ((pos (make-position 9)))
    (try-play pos +black+ (vertex->index 9 "D4"))
    (is (not (member (vertex->index 9 "D4")
                     (mapcar #'first (opening-hints pos)))))))

(test opening-weight-returns-double
  (let ((pos (make-position 9)))
    (is (typep (opening-weight pos (vertex->index 9 "D4")) 'double-float))
    (is (= 0.0d0 (opening-weight pos 0)))))

(test handicap-points-count
  (is (= 2 (length (handicap-points 19 2))))
  (is (= 4 (length (handicap-points 19 4))))
  (is (= 9 (length (handicap-points 19 9))))
  (is (= 4 (length (handicap-points 9 4))))
  (is (= 2 (length (handicap-points 9 2))))
  (is (every (lambda (p) (and (<= 0 p) (< p 361)))
             (handicap-points 19 9))))

(test handicap-points-distinct
  (is (= 9 (length (remove-duplicates (handicap-points 19 9))))))
