(in-package :stonehue)

(defparameter +empty+ 0)
(defparameter +black+ 1)
(defparameter +white+ 2)
(defparameter +pass+ -1)

(defstruct (board (:constructor %make-board (size cells)))
  (size 9 :type (integer 3 25))
  (cells nil :type (simple-array (unsigned-byte 2) (*))))

(defun make-board (size)
  "Return an empty square board of side SIZE."
  (check-type size (integer 3 25))
  (%make-board size
               (make-array (* size size)
                           :element-type '(unsigned-byte 2)
                           :initial-element +empty+)))

(defun board-copy (board)
  "Return an independent copy of BOARD."
  (%make-board (board-size board) (copy-seq (board-cells board))))

(declaim (inline board-ref))
(defun board-ref (board idx)
  "Return the stone at INDEX on BOARD: empty, black, or white."
  (aref (board-cells board) idx))

(declaim (inline row-col->index))
(defun row-col->index (size row col)
  "Map a zero-based ROW and COL to a flat board index."
  (+ (* row size) col))

(declaim (inline index->row-col))
(defun index->row-col (size idx)
  "Return the zero-based row and column for a flat board INDEX."
  (values (floor idx size) (mod idx size)))

(defun all-points (size)
  "Return a list of every flat index on a board of side SIZE."
  (loop for i below (* size size) collect i))

(defun neighbors (size idx)
  "Return the flat indices orthogonally adjacent to INDEX.
The order is up, down, left, right for the valid directions."
  (let ((row (floor idx size))
        (col (mod idx size))
        (result '()))
    (when (> row 0)
      (push (- idx size) result))
    (when (< row (1- size))
      (push (+ idx size) result))
    (when (> col 0)
      (push (1- idx) result))
    (when (< col (1- size))
      (push (1+ idx) result))
    (nreverse result)))

(defparameter +vertex-letters+
  "ABCDEFGHJKLMNOPQRSTUVWXYZ"
  "GTP column letters. The letter I is omitted by the protocol.")

(defun vertex->index (size vertex)
  "Return the flat index for a GTP vertex such as D4.
Signal an error when the vertex is malformed or out of range."
  (let* ((clean (string-upcase (string-trim '(#\Space #\Tab #\Newline)
                                            (princ-to-string vertex))))
         (col (position (char clean 0) +vertex-letters+)))
    (unless col
      (error "Illegal vertex: ~a" vertex))
    (let* ((row-text (subseq clean 1))
           (row (parse-integer row-text :junk-allowed t)))
      (unless (and row (plusp row))
        (error "Illegal vertex: ~a" vertex))
      (let ((r (1- row))
            (c col))
        (when (or (< r 0) (>= r size) (< c 0) (>= c size))
          (error "Vertex ~a is out of range for board size ~d"
                 vertex size))
        (row-col->index size r c)))))

(defun index->vertex (size idx)
  "Return the GTP vertex string for a flat INDEX."
  (multiple-value-bind (row col) (index->row-col size idx)
    (format nil "~c~d" (char +vertex-letters+ col) (1+ row))))
