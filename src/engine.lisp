(in-package :stonehue)

;;; The engine ties a position, komi, a strength level, and time
;;; controls together and exposes the move-finding entry points.

(defstruct (engine (:constructor %make-engine
                     (position komi strength rng iterations time-limit
                      use-opening opening-move-limit max-branching undo-stack)))
  position
  (komi 6.5 :type double-float)
  (strength 3 :type (integer 1 5))
  rng
  (iterations 1000 :type (integer 0 #.most-positive-fixnum))
  (time-limit nil)
  (use-opening t)
  (opening-move-limit 4 :type fixnum)
  (max-branching nil)
  (undo-stack '())
  (history '())   ; (color . move) pairs, newest first
  (setup '())     ; (color . index) setup stones from a handicap
  (last-stats nil))

(defun engine-push-snapshot (engine)
  "Save the position, move history, and setup stones for an undo."
  (push (list (position-copy (engine-position engine))
              (engine-history engine)
              (engine-setup engine))
        (engine-undo-stack engine)))

(defun engine-record-move (engine color move)
  "Append MOVE for COLOR to the engine move history."
  (push (cons color move) (engine-history engine)))

(defun strength-iterations (strength)
  "Return the playout budget for a strength level from 1 to 5."
  (case strength
    (1 120)
    (2 400)
    (3 1000)
    (4 3000)
    (5 9000)
    (otherwise 1000)))

(defun strength-time-limit (strength)
  "Return a suggested per-move time budget for a strength level."
  (case strength
    (1 0.1d0)
    (2 0.3d0)
    (3 0.8d0)
    (4 2.0d0)
    (5 6.0d0)
    (otherwise 0.8d0)))

(defun make-engine
    (&key (size 9)
          (komi 6.5)
          (strength 3)
          (seed 42)
          (iterations nil)
          (time-limit nil)
          (use-opening t)
          (opening-move-limit 4)
          (max-branching nil))
  "Return a new engine on a board of side SIZE.
STRENGTH selects the default playout budget from 1 to 5.
ITERATIONS and TIME-LIMIT override that budget when given."
  (check-type size (integer 3 25))
  (check-type strength (integer 1 5))
  (%make-engine (make-position size)
               (coerce komi 'double-float)
               strength
               (make-rng seed)
               (or iterations (strength-iterations strength))
               time-limit
               use-opening
               opening-move-limit
               max-branching
               '()))

(defun engine-set-strength (engine strength)
  "Set the strength level and its default playout budget."
  (check-type strength (integer 1 5))
  (setf (engine-strength engine) strength)
  (setf (engine-iterations engine) (strength-iterations strength))
  engine)

(defun engine-set-komi (engine komi)
  "Set the komi used for scoring and search."
  (setf (engine-komi engine) (coerce komi 'double-float))
  engine)

(defun engine-set-iterations (engine n)
  "Set the maximum number of MCTS playouts per move."
  (check-type n (integer 0 #.most-positive-fixnum))
  (setf (engine-iterations engine) n)
  engine)

(defun engine-set-time-limit (engine seconds)
  "Set the wall-clock search budget per move, or NIL for none."
  (setf (engine-time-limit engine)
        (and seconds (coerce seconds 'double-float)))
  engine)

(defun engine-set-use-opening (engine flag)
  "Enable or disable opening pattern hints."
  (setf (engine-use-opening engine) flag)
  engine)

(defun engine-play (engine color move)
  "Apply MOVE for COLOR. Signal an error on an illegal move or wrong turn."
  (let ((pos (engine-position engine)))
    (unless (eql color (position-to-play pos))
      (error "It is not ~a's turn" (color-name color)))
    (engine-push-snapshot engine)
    (cond ((eq move :pass)
           (pass-move pos color)
           (engine-record-move engine color :pass))
          ((try-play pos color move)
           (engine-record-move engine color move))
          (t
           (pop (engine-undo-stack engine))
           (error "Illegal move ~a for ~a"
                  (index->vertex (position-size pos) move)
                  (color-name color)))))
  engine)

(defun engine-pass (engine color)
  "Record a pass for COLOR on the engine position."
  (engine-play engine color :pass))

(defun engine-genmove (engine color)
  "Choose a move for COLOR with Monte Carlo tree search.
Apply the chosen move and return it. Return :PASS when the engine passes."
  (let ((pos (engine-position engine)))
    (unless (eql color (position-to-play pos))
      (error "It is not ~a's turn" (color-name color)))
    (engine-push-snapshot engine)
    (multiple-value-bind (move stats)
        (mcts-search pos
                     :iterations (engine-iterations engine)
                     :time-limit (engine-time-limit engine)
                     :rng (engine-rng engine)
                     :komi 0.0d0
                     :opening-fn (when (engine-use-opening engine)
                                   'opening-hint-table)
                     :opening-move-limit (engine-opening-move-limit engine)
                     :max-branching (engine-max-branching engine))
      (setf (engine-last-stats engine) stats)
      (if (eq move :pass)
          (pass-move pos color)
          (try-play pos color move))
      (engine-record-move engine color move)
      move)))

(defun engine-undo (engine)
  "Undo the last move. Return T on success and NIL when nothing to undo."
  (let ((snapshot (pop (engine-undo-stack engine))))
    (when snapshot
      (destructuring-bind (pos history setup) snapshot
        (setf (engine-position engine) pos)
        (setf (engine-history engine) history)
        (setf (engine-setup engine) setup))
      t)))

(defun engine-set-time-settings (engine main-time byo-yomi byo-yomi-stones)
  "Store GTP time settings and derive a per-move wall-clock budget."
  (let* ((size (position-size (engine-position engine)))
         (budget
           (cond ((and main-time (plusp main-time))
                  (max 0.05d0
                       (/ main-time (max 10 (round (* size size) 2)))))
                 ((and byo-yomi byo-yomi-stones (plusp byo-yomi-stones))
                  (max 0.05d0 (/ byo-yomi byo-yomi-stones)))
                 (t 1.0d0))))
    (setf (engine-time-limit engine) (min 60.0d0 budget))
    (setf (engine-iterations engine) 100000)
    engine))
