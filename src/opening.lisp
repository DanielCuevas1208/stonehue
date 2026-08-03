(in-package :stonehue)

;;; A small library of opening pattern hints. The hints bias the tree
;;; search in the first few moves toward the standard corner points:
;;; star points, komoku, takamoku, and the like.

(defparameter *corner-patterns*
  '((3 3 0.95d0 "Hoshi")
    (3 4 0.85d0 "Komoku")
    (4 3 0.85d0 "Komoku")
    (4 4 0.75d0 "Takamoku")
    (3 5 0.6d0 "Mokuhazushi")
    (5 3 0.6d0 "Mokuhazushi")
    (4 5 0.5d0 "Kakari")
    (5 4 0.5d0 "Kakari")
    (5 5 0.45d0 "Fuseki")
    (2 3 0.35d0 "Kakari")
    (3 2 0.35d0 "Kakari")
    (2 2 0.25d0 "Shimari")
    (1 1 0.1d0 "Corner"))
  "Corner opening patterns. Each entry is (drow dcol weight name)
measured from the nearest corner of the board.")

(defun opening-hints (position)
  "Return the opening hints for POSITION as a list of (index weight name),
sorted by weight descending. Only empty points are offered."
  (let* ((size (position-size position))
         (board (position-board position))
         (weights (make-hash-table :test #'eql))
         (names (make-hash-table :test #'eql)))
    (labels ((offer (r c weight name)
               (when (and (<= 0 r) (< r size) (<= 0 c) (< c size))
                 (let ((idx (row-col->index size r c)))
                   (when (zerop (aref board idx))
                     (let ((best (gethash idx weights)))
                       (when (or (null best) (> weight best))
                         (setf (gethash idx weights) weight)
                         (setf (gethash idx names) name))))))))
      (when (>= size 7)
        (dolist (pattern *corner-patterns*)
          (destructuring-bind (dr dc weight name) pattern
            (let ((r0 (- size 1 dr))
                  (c0 (- size 1 dc)))
              (offer dr dc weight name)
              (offer dr c0 weight name)
              (offer r0 dc weight name)
              (offer r0 c0 weight name)))))
      (when (and (oddp size) (>= size 9))
        (let ((mid (floor size 2)))
          (offer mid mid 0.7d0 "Tengen")
          (offer mid 0 0.4d0 "Edge")
          (offer 0 mid 0.4d0 "Edge")
          (offer mid (1- size) 0.4d0 "Edge")
          (offer (1- size) mid 0.4d0 "Edge"))))
    (sort (loop for idx being the hash-keys of weights
                collect (list idx (gethash idx weights) (gethash idx names)))
          #'>
          :key #'second)))

(defun opening-hint-table (position)
  "Return a hash table that maps each hinted move index to its prior weight."
  (let ((table (make-hash-table :test #'eql)))
    (dolist (hint (opening-hints position))
      (setf (gethash (first hint) table) (second hint)))
    table))

(defun opening-weight (position move)
  "Return the opening prior weight for MOVE in POSITION, or 0.0."
  (or (gethash move (opening-hint-table position)) 0.0d0))

(defun handicap-points (size n)
  "Return N standard handicap points for a board of side SIZE.
Star points come first, then edge star points, then the center."
  (let ((star (min 3 (floor size 2)))
        (far (max 3 (- size 4)))
        (points '()))
    (labels ((push-point (r c)
               (when (and (<= 0 r) (< r size) (<= 0 c) (< c size))
                 (push (row-col->index size r c) points))))
      (when (>= n 1) (push-point star star))
      (when (>= n 2) (push-point far far))
      (when (>= n 3) (push-point star far))
      (when (>= n 4) (push-point far star))
      (when (>= size 13)
        (let ((mid (floor size 2)))
          (when (>= n 5) (push-point star mid))
          (when (>= n 6) (push-point mid star))
          (when (>= n 7) (push-point far mid))
          (when (>= n 8) (push-point mid far))))
      (when (and (>= n 9) (oddp size) (>= size 13))
        (push-point (floor size 2) (floor size 2))))
    (nreverse points)))
