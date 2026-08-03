(in-package :stonehue)

;;; A position holds one board state plus the small amount of game
;;; information needed to apply the capture and simple-ko rules.

(defstruct (marks (:constructor make-marks ()))
  "Scratch arrays shared by copies of a position.
The global mark counter keeps writes from separate calls apart,
so sharing the arrays across positions is safe."
  (group (make-array 0 :element-type 'fixnum) :type (simple-array fixnum (*)))
  (lib (make-array 0 :element-type 'fixnum) :type (simple-array fixnum (*)))
  (queue (make-array 0 :element-type 'fixnum) :type (simple-array fixnum (*))))

(defvar *mark-tick* 0
  "Monotonic counter used to stamp scratch arrays.")

(declaim (inline %next-mark))
(defun %next-mark ()
  (incf *mark-tick*))

(defun ensure-marks (marks size)
  "Grow the scratch arrays in MARKS to fit a board of side SIZE."
  (let ((n (* size size)))
    (when (< (length (marks-group marks)) n)
      (setf (marks-group marks)
            (make-array n :element-type 'fixnum :initial-element 0)))
    (when (< (length (marks-lib marks)) n)
      (setf (marks-lib marks)
            (make-array n :element-type 'fixnum :initial-element 0)))
    (when (< (length (marks-queue marks)) n)
      (setf (marks-queue marks) (make-array n :element-type 'fixnum)))
    marks))

(defstruct (go-position (:conc-name position-)
                        (:constructor %make-position (size board to-play))
                        (:predicate go-position-p))
  (size 9 :type (integer 3 25))
  (board nil)
  (to-play +black+ :type (integer 1 2))
  (move-number 0 :type fixnum)
  (cur-hash 0 :type (unsigned-byte 64))
  (prev-hash 0 :type (unsigned-byte 64))
  (last-move nil)
  (captured-last 0 :type fixnum)
  (captures-black 0 :type fixnum)
  (captures-white 0 :type fixnum)
  (consecutive-passes 0 :type fixnum)
  (marks (make-marks) :type marks))

(defun make-position (size)
  "Return a new empty position on a board of side SIZE."
  (check-type size (integer 3 25))
  (let* ((board (make-board size))
         (cells (board-cells board))
         (pos (%make-position size cells +black+)))
    (setf (position-cur-hash pos) (hash-position cells size))
    pos))

(defun position-copy (position)
  "Return an independent copy of POSITION.
The scratch arrays are shared and stay safe through the mark counter."
  (let ((copy (%make-position (position-size position)
                              (copy-seq (position-board position))
                              (position-to-play position))))
    (setf (position-move-number copy) (position-move-number position)
          (position-cur-hash copy) (position-cur-hash position)
          (position-prev-hash copy) (position-prev-hash position)
          (position-last-move copy) (position-last-move position)
          (position-captured-last copy) (position-captured-last position)
          (position-captures-black copy) (position-captures-black position)
          (position-captures-white copy) (position-captures-white position)
          (position-consecutive-passes copy)
          (position-consecutive-passes position)
          (position-marks copy) (position-marks position))
    copy))

(defun position-hash (position)
  "Return the current board hash of POSITION."
  (position-cur-hash position))

(declaim (inline stone-at))
(defun stone-at (position idx)
  "Return the stone at INDEX on the board of POSITION."
  (aref (position-board position) idx))

(defun other-color (color)
  "Return the opponent of COLOR."
  (if (eql color +black+) +white+ +black+))

(defun color-name (color)
  "Return the printable name of COLOR."
  (cond ((eql color +black+) "Black")
        ((eql color +white+) "White")
        (t "Empty")))

(defun hash-position (board size)
  "Return a deterministic 64-bit hash of the stones on BOARD."
  (let ((h 14695981039346656037))
    (dotimes (i (* size size))
      (let ((v (aref board i)))
        (when (plusp v)
          (setf h (logxor h (logand #xFFFFFFFFFFFFFFFF (* (1+ i) (+ 7 (* v 31))))))
          (setf h (logand #xFFFFFFFFFFFFFFFF (* h 1099511628211))))))
    h))

(defun group-of-board (board size idx marks)
  "Return the list of indices connected to IDX by stones of the same color."
  (ensure-marks marks size)
  (let* ((color (aref board idx))
         (group-mark (marks-group marks))
         (queue (marks-queue marks))
         (tick (%next-mark))
         (head 0)
         (tail 0)
         (group '()))
    (setf (aref group-mark idx) tick)
    (setf (aref queue tail) idx)
    (incf tail)
    (loop while (< head tail)
          for p = (aref queue head)
          do (incf head)
             (push p group)
             (dolist (nb (neighbors size p))
               (when (and (= (aref board nb) color)
                          (/= (aref group-mark nb) tick))
                 (setf (aref group-mark nb) tick)
                 (setf (aref queue tail) nb)
                 (incf tail))))
    group))

(defun group-liberties-board (board size group marks)
  "Return the empty points adjacent to any stone in GROUP."
  (ensure-marks marks size)
  (let* ((lib-mark (marks-lib marks))
         (tick (%next-mark))
         (libs '()))
    (dolist (p group)
      (dolist (nb (neighbors size p))
        (when (and (zerop (aref board nb))
                   (/= (aref lib-mark nb) tick))
          (setf (aref lib-mark nb) tick)
          (push nb libs))))
    libs))

(defun group-of (position idx)
  "Return the group of connected stones that contains INDEX."
  (group-of-board (position-board position)
                  (position-size position)
                  idx
                  (position-marks position)))

(defun group-liberties (position group)
  "Return the liberties of GROUP on the board of POSITION."
  (group-liberties-board (position-board position)
                         (position-size position)
                         group
                         (position-marks position)))

(defun try-play (position color idx)
  "Place a stone of COLOR at IDX when the move is legal.
Return T and advance POSITION on success. Return NIL otherwise,
leaving POSITION unchanged."
  (unless (eql color (position-to-play position))
    (return-from try-play nil))
  (let* ((size (position-size position))
         (n (* size size))
         (board (position-board position)))
    (unless (and (<= 0 idx) (< idx n))
      (return-from try-play nil))
    (unless (zerop (aref board idx))
      (return-from try-play nil))
    (let ((opp (other-color color))
          (captured '())
          (marks (position-marks position)))
      (setf (aref board idx) color)
      (dolist (nb (neighbors size idx))
        (when (= (aref board nb) opp)
          (let ((group (group-of-board board size nb marks)))
            (when (zerop (length (group-liberties-board board size group marks)))
              (setf captured (nconc captured group))))))
      (dolist (p captured)
        (setf (aref board p) +empty+))
      (let ((own (group-of-board board size idx marks)))
        (when (and (null captured)
                   (zerop (length (group-liberties-board board size own marks))))
          ;; Suicide: revert the placement.
          (setf (aref board idx) +empty+)
          (dolist (p captured) (setf (aref board p) opp))
          (return-from try-play nil)))
      (let ((new-hash (hash-position board size)))
        (when (= new-hash (position-prev-hash position))
          ;; Simple ko: the move recreates the position before the last move.
          (setf (aref board idx) +empty+)
          (dolist (p captured) (setf (aref board p) opp))
          (return-from try-play nil))
        (setf (position-prev-hash position) (position-cur-hash position))
        (setf (position-cur-hash position) new-hash))
      (setf (position-captured-last position) (length captured))
      (let ((n (length captured)))
        (when (plusp n)
          (if (eql color +black+)
              (incf (position-captures-black position) n)
              (incf (position-captures-white position) n))))
      (setf (position-to-play position) opp)
      (setf (position-last-move position) idx)
      (setf (position-consecutive-passes position) 0)
      (incf (position-move-number position))
      t)))

(defun play-move (position color idx)
  "Place a stone and signal an error when the move is illegal."
  (unless (try-play position color idx)
    (error "Illegal move for ~a at ~a"
           (color-name color)
           (index->vertex (position-size position) idx)))
  position)

(defun pass-move (position color)
  "Record a pass for COLOR and advance POSITION."
  (unless (eql color (position-to-play position))
    (error "It is not ~a's turn" (color-name color)))
  (setf (position-prev-hash position) (position-cur-hash position))
  (setf (position-to-play position) (other-color color))
  (setf (position-last-move position) :pass)
  (setf (position-captured-last position) 0)
  (incf (position-consecutive-passes position))
  (incf (position-move-number position))
  position)

(defun legal-move-p (position color idx)
  "Return T when COLOR may legally place a stone at IDX."
  (unless (eql color (position-to-play position))
    (return-from legal-move-p nil))
  (let* ((size (position-size position))
         (n (* size size))
         (board (position-board position)))
    (unless (and (<= 0 idx) (< idx n))
      (return-from legal-move-p nil))
    (unless (zerop (aref board idx))
      (return-from legal-move-p nil))
    (let ((test (copy-seq board))
          (marks (position-marks position)))
      (setf (aref test idx) color)
      (let ((opp (other-color color))
            (captured '()))
        (dolist (nb (neighbors size idx))
          (when (= (aref test nb) opp)
            (let ((group (group-of-board test size nb marks)))
              (when (zerop (length (group-liberties-board test size group marks)))
                (setf captured (nconc captured group))))))
        (dolist (p captured)
          (setf (aref test p) +empty+))
        (let ((own (group-of-board test size idx marks)))
          (when (and (null captured)
                     (zerop (length (group-liberties-board test size own marks))))
            (return-from legal-move-p nil)))
        (not (= (hash-position test size) (position-prev-hash position)))))))

(defun legal-moves (position &key (max-branching nil) (rng nil))
  "Return the legal non-pass moves for the side to move.
When MAX-BRANCHING is set, keep at most that many moves, sampled
at random with RNG."
  (let* ((size (position-size position))
         (n (* size size))
         (color (position-to-play position))
         (moves '()))
    (dotimes (i n)
      (when (legal-move-p position color i)
        (push i moves)))
    (setf moves (nreverse moves))
    (when (and max-branching (> (length moves) max-branching))
      (setf moves (rng-shuffle rng moves))
      (setf moves (subseq moves 0 max-branching)))
    moves))

(defun is-terminal-p (position)
  "Return T when two consecutive passes have ended the game."
  (>= (position-consecutive-passes position) 2))
