(in-package :stonehue)

;;; Monte Carlo tree search with upper confidence bounds (UCT).
;;; The tree keeps a deterministic move order, and every random
;;; choice flows through the seeded generator, so a fixed seed
;;; always produces the same result.

(defparameter +exploration+ 0.4d0
  "The UCB exploration constant.")

(defparameter +max-simulation-plies+ 400
  "The upper bound on a full random playout length.")

(defparameter +playout-plies+ 12
  "The number of tactical plies in one bounded playout.
A short playout keeps the value close to the material balance,
so captures show up clearly in the tree search.")

(defun playout-margin (position)
  "The heuristic value that ranks moves during a playout.
A prisoner counts for two points: the stone gained plus the stone
removed from the opponent."
  (let* ((stones (material-margin position :komi 0.0))
         (prisoners (- (position-captures-black position)
                       (position-captures-white position))))
    (+ stones (* 2.0d0 prisoners))))

(defparameter +pass-probability+ 0.06d0
  "The chance that a random playout chooses pass on a given turn.")

(defparameter +capture-bias+ 0.9d0
  "The chance that a random playout first looks for a capturing move.")

(defparameter +capture-attempts+ 30
  "The sampling attempts used to find a capturing playout move.")

(defparameter +max-move-attempts+ 400
  "The sampling attempts per random playout move.")

(defun capture-count (position color idx)
  "Return the number of stones that a move at IDX would capture.
Return 0 when the move captures nothing or is plainly illegal.
The board is not modified."
  (let* ((board (position-board position))
         (size (position-size position))
         (n (* size size))
         (marks (position-marks position)))
    (unless (and (<= 0 idx) (< idx n) (zerop (aref board idx)))
      (return-from capture-count 0))
    (let ((opp (other-color color))
          (total 0))
      (dolist (nb (neighbors size idx))
        (when (= (aref board nb) opp)
          (let* ((group (group-of-board board size nb marks))
                 (libs (group-liberties-board board size group marks)))
            (when (and (= 1 (length libs)) (eql (first libs) idx))
              (incf total (length group))))))
      total)))

(defun find-capture (pos rng)
  "Return a sampled move for POSITION that captures stones, or NIL."
  (let* ((size (position-size pos))
         (n (* size size))
         (color (position-to-play pos)))
    (loop repeat +capture-attempts+
          for i = (rng-integer rng n)
          when (zerop (aref (position-board pos) i))
          do (when (plusp (capture-count pos color i))
               (return-from find-capture i)))
    nil))

(defstruct (mcts-node (:constructor %make-mcts-node (move to-play)))
  move        ; NIL at the root, otherwise an index or :PASS
  to-play     ; the color to move at this node
  (plays 0 :type fixnum)
  (wins 0 :type fixnum)
  (children '())        ; child nodes in expansion order
  (untried '())         ; candidate moves not yet expanded
  (hint-table nil)      ; opening prior weights, or NIL
  parent)

(defun win-for-p (color margin)
  "Return T when the player COLOR wins a game ending with MARGIN."
  (if (eql color +black+)
      (> margin 0)
      (< margin 0)))

(defun ucb-score (child log-parent-plays)
  "Return the UCB value used to select a child during descent.
The child stores its value from its own mover's perspective, so the
parent's value is one minus the child's value."
  (let ((plays (max 1 (mcts-node-plays child))))
    (+ (- 1.0d0 (/ (mcts-node-wins child) plays))
       (* +exploration+ (sqrt (/ log-parent-plays plays))))))

(defun select-child (node)
  "Return the child of NODE with the highest UCB score."
  (let ((best nil)
        (best-score -1.0d0)
        (log-parent (log (max 1 (mcts-node-plays node)))))
    (dolist (child (mcts-node-children node))
      (let ((score (ucb-score child log-parent)))
        (when (> score best-score)
          (setf best child)
          (setf best-score score))))
    best))

(defun select-best-move (root)
  "Return the move that the side to move rates most highly.
A child is chosen by its win rate from the root player's perspective,
once it has enough visits."
  (let ((best nil)
        (best-score -1.0d0)
        (root-color (mcts-node-to-play root)))
    (dolist (child (mcts-node-children root))
      (when (>= (mcts-node-plays child) 2)
        (let* ((plays (mcts-node-plays child))
               (wins (mcts-node-wins child))
               (root-wins (if (eql (mcts-node-to-play child) root-color)
                              wins
                              (- plays wins)))
               (score (/ root-wins plays)))
          (when (or (null best)
                    (> score best-score)
                    (and (= score best-score)
                         (> plays (mcts-node-plays best))))
            (setf best child)
            (setf best-score score)))))
    (if best (mcts-node-move best) :pass)))

(defun random-move (pos rng)
  "Choose a random legal move for POSITION, or NIL to pass.
Capturing moves are preferred during the sample."
  (when (< (rng-random rng) +pass-probability+)
    (return-from random-move nil))
  (when (< (rng-random rng) +capture-bias+)
    (let ((capture (find-capture pos rng)))
      (when capture
        (return-from random-move capture))))
  (let* ((size (position-size pos))
         (n (* size size))
         (color (position-to-play pos)))
    (loop repeat +max-move-attempts+
          for i = (rng-integer rng n)
          when (zerop (aref (position-board pos) i))
          do (when (try-play pos color i)
               (return-from random-move i)))
    nil))

(defun simulate (position komi rng)
  "Play tactical random moves from POSITION and return the playout margin.
KOMI is reserved for future use and is not part of the playout value."
  (declare (ignore komi))
  (let ((pos (position-copy position))
        (plies 0))
    (loop while (< plies +playout-plies+)
          for passes = (position-consecutive-passes pos)
          while (< passes 2)
          do (incf plies)
             (let ((move (random-move pos rng)))
               (if (null move)
                   (pass-move pos (position-to-play pos))
                   (try-play pos (position-to-play pos) move))))
    (playout-margin pos)))

(defun expand-node (node pos rng opening-fn opening-move-limit max-branching)
  "Expand one untried move of NODE and return the new child node.
POS is the position at NODE. The child's position is left in POS."
  (let* ((move (pop (mcts-node-untried node)))
         (opening-prior (and opening-fn
                             (< (position-move-number pos) opening-move-limit)
                             (gethash move (mcts-node-hint-table node))))
         (captures (and (integerp move)
                        (capture-count pos (position-to-play pos) move)))
         (child (%make-mcts-node move nil)))
    (if (eq move :pass)
        (pass-move pos (position-to-play pos))
        (try-play pos (position-to-play pos) move))
    (setf (mcts-node-to-play child) (position-to-play pos))
    (let ((virtual-plays 8)
          (virtual-wins 4))
      (cond (opening-prior
             ;; An opening hint is a strong prior on a good move. The
             ;; count is sized so the hint survives the playout noise of
             ;; a small search budget, yet fades as real evidence arrives.
             (setf virtual-plays 32
                   virtual-wins (max 0 (round (* 32 (- 1.0d0 opening-prior))))))
            ((and captures (plusp captures))
             ;; A move that captures stones is likely good for the mover.
             ;; The child stores its value from the opponent's perspective,
             ;; so a strong move gets a LOW child win rate.
             (let ((quality (min 0.95d0 (+ 0.55d0 (* captures 0.15d0)))))
               (setf virtual-plays 8
                     virtual-wins (max 1 (round (* 8 (- 1.0d0 quality))))))))
      (setf (mcts-node-plays child) virtual-plays
            (mcts-node-wins child) virtual-wins))
    (setf (mcts-node-parent child) node)
    (push child (mcts-node-children node))
    (setf (mcts-node-untried child)
          (legal-moves pos :max-branching max-branching :rng rng))
    (setf (mcts-node-hint-table child)
          (and opening-fn
               (< (position-move-number pos) opening-move-limit)
               (funcall opening-fn pos)))
    child))

(defun one-iteration (root position rng komi opening-fn opening-move-limit max-branching)
  "Run one MCTS playout from ROOT at POSITION."
  (let ((node root)
        (pos (position-copy position)))
    (loop
      (cond ((mcts-node-untried node)
             (setf node (expand-node node pos rng opening-fn
                                     opening-move-limit max-branching))
             (return))
            ((mcts-node-children node)
             (let ((child (select-child node)))
               (if (eq (mcts-node-move child) :pass)
                   (pass-move pos (position-to-play pos))
                   (try-play pos (position-to-play pos) (mcts-node-move child)))
               (setf node child)))
            (t
             (return)))
      (when (is-terminal-p pos)
        (return)))
    (let ((result (simulate pos komi rng)))
      (loop for n = node then (mcts-node-parent n)
            while n
            do (incf (mcts-node-plays n))
               (when (win-for-p (mcts-node-to-play n) result)
                 (incf (mcts-node-wins n)))))))

(defun mcts-search (position
                    &key (iterations 1000)
                         (time-limit nil)
                         (rng (make-rng))
                         (komi 6.5)
                         (opening-fn nil)
                         (opening-move-limit 4)
                         (max-branching nil))
  "Search POSITION with Monte Carlo tree search.
Return (values best-move stats) where STATS lists the root children
as (move plays wins win-rate)."
  (let* ((root (%make-mcts-node nil (position-to-play position))))
    (setf (mcts-node-untried root)
          (cons :pass (legal-moves position :max-branching max-branching :rng rng)))
    (setf (mcts-node-hint-table root)
          (and opening-fn
               (< (position-move-number position) opening-move-limit)
               (funcall opening-fn position)))
    (let ((deadline (and time-limit
                         (+ (get-internal-real-time)
                            (round (* time-limit internal-time-units-per-second))))))
      (loop for i from 1 to (max 0 iterations)
            while (or (null deadline) (< (get-internal-real-time) deadline))
            do (one-iteration root position rng komi opening-fn
                              opening-move-limit max-branching)))
    (values (select-best-move root) (mcts-analyze root))))

(defun mcts-analyze (root)
  "Return a sorted list of (move plays wins win-rate) for the root children."
  (sort (loop for child in (mcts-node-children root)
              collect (list (mcts-node-move child)
                            (mcts-node-plays child)
                            (mcts-node-wins child)
                            (if (plusp (mcts-node-plays child))
                                (/ (mcts-node-wins child)
                                   (mcts-node-plays child))
                                0.0d0)))
        #'>
        :key #'third))
