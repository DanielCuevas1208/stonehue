(in-package :stonehue/tests)

(in-suite stonehue-suite)

(test board-basics
  (let ((board (make-board 9)))
    (is (= 9 (board-size board)))
    (is (board-p board))
    (dotimes (i 81)
      (is (= +empty+ (board-ref board i))))))

(test board-copy-is-independent
  (let* ((board (make-board 5))
         (copy (board-copy board)))
    (setf (aref (board-cells board) 0) +black+)
    (is (= +empty+ (aref (board-cells copy) 0)))))

(test row-col-round-trip
  (dolist (size (list 9 13 19))
    (dotimes (idx (* size size))
      (multiple-value-bind (row col) (index->row-col size idx)
        (is (= idx (row-col->index size row col)))))))

(test neighbors-on-board
  (let ((size 9))
    (is (= 2 (length (neighbors size 0))))            ; corner
    (is (= 3 (length (neighbors size 1))))            ; top edge
    (is (= 4 (length (neighbors size (+ (* 4 9) 4))))))) ; center

(test neighbors-are-orthogonal
  (let ((size 9)
        (idx (+ (* 4 9) 4)))
    (is (equal (list (- idx 9) (+ idx 9) (1- idx) (1+ idx))
               (neighbors size idx)))))

(test vertex-round-trip
  (dolist (size (list 9 13 19))
    (dotimes (idx (* size size))
      (is (= idx (vertex->index size (index->vertex size idx)))))))

(test vertex-skipping-i
  (is (= 8 (vertex->index 9 "J1")))
  (is (equal "J9" (index->vertex 9 (+ (* 8 9) 8)))))

(test vertex-out-of-range
  (signals error (vertex->index 9 "K1"))
  (signals error (vertex->index 9 "A10"))
  (signals error (vertex->index 9 "Z1")))

(test render-position-shows-stones
  (let ((pos (make-position 9)))
    (try-play pos +black+ (vertex->index 9 "D4"))
    (let ((picture (render-position pos)))
      (is (search "X" picture))
      (is (search "A" picture))
      (is (search "9" picture)))))
