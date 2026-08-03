(in-package :stonehue)

;;; Smart Game Format (SGF) FF[4] support. The engine reads and writes
;;; game records, so a finished game can be saved and loaded later.
;;; The writer produces one compact line, which keeps the GTP reply
;;; simple for standard tools.

;;; --- data model ---

(defstruct (sgf-property (:constructor make-sgf-property (id values)))
  "One SGF property such as SZ[9] or B[dd]."
  id
  values)

(defstruct (sgf-node (:constructor make-sgf-node (properties)))
  "One SGF node: a collection of properties."
  properties)

(defstruct (sgf-tree (:constructor make-sgf-tree (nodes children)))
  "One SGF game tree. NODES is the main line. CHILDREN holds the
variation subtrees, which are parsed but not replayed."
  nodes
  children)

;;; --- coordinates ---

(defun index-to-sgf (size idx)
  "Return the SGF point string for a flat board INDEX.
SGF points are two lower-case letters, column first."
  (multiple-value-bind (row col) (index->row-col size idx)
    (let ((r (- (1- size) row)))
      (format nil "~c~c"
              (code-char (+ (char-code #\a) col))
              (code-char (+ (char-code #\a) r))))))

(defun sgf-pass-coord-p (coord)
  "Return T when COORD is a pass: empty or the special point \"tt\"."
  (let ((s (string-trim " " coord)))
    (or (zerop (length s))
        (and (= 2 (length s))
             (char-equal (char s 0) #\T)
             (char-equal (char s 1) #\T)))))

(defun sgf-coord-to-index (size coord)
  "Return the flat index for a non-pass SGF point, or NIL when COORD
is not a point on the board."
  (let ((s (string-downcase (string-trim " " coord))))
    (when (= 2 (length s))
      (let ((c (- (char-code (char s 0)) (char-code #\a)))
            (r (- (char-code (char s 1)) (char-code #\a))))
        (when (and (<= 0 c) (< c size)
                   (<= 0 r) (< r size))
          (row-col->index size (- (1- size) r) c))))))

;;; --- parser ---

(defun sgf-node-property-values (node id)
  "Return every value of property ID in NODE, in file order.
Duplicate properties with the same ID are merged."
  (loop for prop in (sgf-node-properties node)
        when (string-equal id (sgf-property-id prop))
        append (sgf-property-values prop)))

(defun sgf-node-property (node id)
  "Return the first value of property ID in NODE, or NIL."
  (first (sgf-node-property-values node id)))

(defun parse-sgf (text)
  "Parse SGF TEXT and return a list of game trees.
Signal an error when the text is not well-formed SGF."
  (let ((pos 0)
        (len (length text)))
    (labels ((skip-space ()
               (loop while (and (< pos len)
                                (find (char text pos)
                                      '(#\Space #\Tab #\Newline #\Return)))
                     do (incf pos)))
             (expect (char)
               (unless (and (< pos len) (char= (char text pos) char))
                 (error "SGF parse error: expected ~a at position ~d"
                        char pos))
               (incf pos))
             (read-value ()
               (expect #\[)
               (let ((out (make-string-output-stream)))
                 (loop while (< pos len)
                       for c = (char text pos)
                       do (cond ((char= c #\])
                                 (incf pos)
                                 (return))
                                ((char= c #\\)
                                 (incf pos)
                                 (when (< pos len)
                                   (let ((next (char text pos)))
                                     (incf pos)
                                     (unless (member next '(#\Newline #\Return))
                                       (write-char next out)))))
                                (t
                                 (write-char c out)
                                 (incf pos))))
                 (get-output-stream-string out)))
             (read-properties ()
               (let ((properties '()))
                 (loop
                   (skip-space)
                   (when (or (>= pos len)
                             (member (char text pos) '(#\( #\) #\;)))
                     (return))
                   (let ((start pos))
                     (loop while (and (< pos len)
                                      (upper-case-p (char text pos)))
                           do (incf pos))
                     (when (= start pos)
                       (error "SGF parse error: bad property at position ~d"
                              pos))
                     (let ((id (subseq text start pos)))
                       (skip-space)
                       (let ((values '()))
                         (loop while (and (< pos len)
                                          (char= (char text pos) #\[))
                               do (push (read-value) values))
                         (when (null values)
                           (error "SGF parse error: property ~a has no value"
                                  id))
                         (push (make-sgf-property id (nreverse values))
                               properties)))))
                 (nreverse properties)))
             (read-node ()
               (expect #\;)
               (make-sgf-node (read-properties)))
             (parse-sequence ()
               (let ((nodes '()))
                 (loop while (and (< pos len)
                                  (char= (char text pos) #\;))
                       do (push (read-node) nodes))
                 (nreverse nodes)))
             (read-tree ()
               (expect #\()
               (skip-space)
               (let ((sequence (parse-sequence)))
                 (when (null sequence)
                   (error "SGF parse error: empty game tree at position ~d"
                          pos))
                 (let ((children '()))
                   (loop
                     (skip-space)
                     (cond ((>= pos len)
                            (error "SGF parse error: unterminated game tree"))
                           ((char= (char text pos) #\()
                            (push (read-tree) children))
                           ((char= (char text pos) #\))
                            (incf pos)
                            (return))
                           (t
                            (error "SGF parse error: unexpected character at ~
                                    position ~d"
                                   pos))))
                   (make-sgf-tree sequence (nreverse children))))))
      (let ((trees '()))
        (loop
          (skip-space)
          (when (>= pos len) (return))
          (unless (char= (char text pos) #\()
            (error "SGF parse error: unexpected character at position ~d"
                   pos))
          (push (read-tree) trees))
        (nreverse trees)))))

;;; --- game extraction ---

(defun parse-color-token (token)
  "Return the stone color for an SGF color token, or NIL."
  (cond ((string-equal token "B") +black+)
        ((string-equal token "W") +white+)
        (t nil)))

(defun sgf-game-info (tree)
  "Extract a playable game from the main line of TREE.
Return a plist with keys :SIZE, :KOMI, :SETUP, :MOVES, :RESULT, and
:PLAYER-TO-PLAY. SETUP and MOVES hold (color . coordinate) pairs where
the coordinate is an SGF point string."
  (let ((size nil)
        (komi nil)
        (result nil)
        (player-to-play nil)
        (setup '())
        (moves '()))
    (dolist (node (sgf-tree-nodes tree))
      (let ((sz (sgf-node-property node "SZ")))
        (when sz
          (setf size (or (parse-integer sz :junk-allowed t) size))))
      (let ((km (sgf-node-property node "KM")))
        (when km
          (let ((value (ignore-errors (read-from-string km))))
            (when (numberp value)
              (setf komi (coerce value 'double-float))))))
      (let ((re (sgf-node-property node "RE")))
        (when re
          (setf result re)))
      (let ((pl (sgf-node-property node "PL")))
        (when pl
          (let ((color (parse-color-token pl)))
            (when color
              (setf player-to-play color)))))
      (dolist (coord (sgf-node-property-values node "AB"))
        (push (cons +black+ coord) setup))
      (dolist (coord (sgf-node-property-values node "AW"))
        (push (cons +white+ coord) setup))
      (dolist (coord (sgf-node-property-values node "B"))
        (push (cons +black+ coord) moves))
      (dolist (coord (sgf-node-property-values node "W"))
        (push (cons +white+ coord) moves)))
    (list :size size
          :komi komi
          :result result
          :player-to-play player-to-play
          :setup (nreverse setup)
          :moves (nreverse moves))))

;;; --- writer ---

(defun format-komi (komi)
  "Return a compact SGF komi value such as \"6.5\"."
  (format nil "~,1F" komi))

(defun sgf-write-game
    (&key (size 19)
          (komi nil)
          (setup '())
          (moves '())
          (result nil)
          (player-to-play nil))
  "Return a game as one line of SGF FF[4] text.
SETUP is a list of (color . index) pairs. MOVES is a list of
(color . index-or-:pass) pairs."
  (with-output-to-string (out)
    (format out "(;FF[4]GM[1]SZ[~d]" size)
    (when komi
      (format out "KM[~a]" (format-komi komi)))
    (when result
      (format out "RE[~a]" result))
    (let ((black-setup '())
          (white-setup '()))
      (dolist (pair setup)
        (if (eql (car pair) +black+)
            (push (index-to-sgf size (cdr pair)) black-setup)
            (push (index-to-sgf size (cdr pair)) white-setup)))
      (when black-setup
        (format out "AB")
        (dolist (coord (nreverse black-setup))
          (format out "[~a]" coord)))
      (when white-setup
        (format out "AW")
        (dolist (coord (nreverse white-setup))
          (format out "[~a]" coord))))
    (when player-to-play
      (format out "PL[~a]"
              (if (eql player-to-play +black+) "B" "W")))
    (dolist (pair moves)
      (let* ((color (car pair))
             (move (cdr pair))
             (prop (if (eql color +black+) "B" "W"))
             (coord (if (eq move :pass)
                        ""
                        (index-to-sgf size move))))
        (format out ";~a[~a]" prop coord)))
    (format out ")")))

;;; --- file and engine integration ---

(defun read-text-file (filename)
  "Return the whole contents of FILENAME as a string."
  (with-open-file (in filename :direction :input
                              :if-does-not-exist :error)
    (let ((out (make-string-output-stream)))
      (loop for line = (read-line in nil :eof)
            while (not (eq line :eof))
            do (write-string line out)
               (write-char #\Newline out))
      (get-output-stream-string out))))

(defun load-sgf-file (filename)
  "Read FILENAME and return the extracted game info plist.
The board size defaults to 19 when the record has no SZ property."
  (let* ((text (read-text-file filename))
         (trees (parse-sgf text)))
    (when (null trees)
      (error "The SGF file has no game tree"))
    (let ((info (sgf-game-info (first trees))))
      (setf (getf info :size) (or (getf info :size) 19))
      info)))

(defun apply-loaded-game (engine info &optional (stop nil))
  "Reset ENGINE and replay game INFO from LOAD-SGF-FILE.
Replay at most STOP moves. STOP 0 keeps the setup only. NIL plays all
moves. Signal an error for an unsupported board or an illegal move."
  (let ((size (getf info :size)))
    (unless (and size (integerp size) (<= 3 size 19))
      (error "Unsupported board size: ~a" size))
    (setf (engine-position engine) (make-position size))
    (setf (engine-undo-stack engine) '())
    (setf (engine-history engine) '())
    (setf (engine-setup engine) '())
    (when (getf info :komi)
      (engine-set-komi engine (getf info :komi)))
    (let ((setup '()))
      (dolist (pair (getf info :setup))
        (let ((color (car pair))
              (coord (cdr pair)))
          (when (sgf-pass-coord-p coord)
            (error "A setup stone cannot be a pass"))
          (let ((idx (sgf-coord-to-index size coord)))
            (unless idx
              (error "Invalid setup point: ~a" coord))
            (push (cons color idx) setup))))
      (dolist (pair (nreverse setup))
        (let ((pos (engine-position engine)))
          (setf (position-to-play pos) (car pair))
          (unless (try-play pos (car pair) (cdr pair))
            (error "The setup stones overlap or are illegal"))))
      (setf (engine-setup engine) (nreverse setup))
      (setf (position-move-number (engine-position engine)) 0))
    (when (getf info :player-to-play)
      (setf (position-to-play (engine-position engine))
            (getf info :player-to-play)))
    (let ((moves (getf info :moves)))
      (when (and stop (<= 0 stop (length moves)))
        (setf moves (subseq moves 0 stop)))
      (dolist (pair moves)
        (let ((color (car pair))
              (coord (cdr pair)))
          (if (sgf-pass-coord-p coord)
              (engine-pass engine color)
              (let ((idx (sgf-coord-to-index size coord)))
                (unless idx
                  (error "Invalid move point: ~a" coord))
                (engine-play engine color idx))))))
    (values)))

(defun engine-move-list (engine)
  "Return the moves played on ENGINE in chronological order.
Each entry is a (color . index-or-:pass) pair. The list is a fresh
copy, so the engine history is not modified."
  (reverse (engine-history engine)))

(defun engine-to-sgf-text (engine)
  "Return the current ENGINE game as SGF FF[4] text."
  (let* ((pos (engine-position engine))
         (size (position-size pos))
         (moves (engine-move-list engine))
         (setup (engine-setup engine))
         (first-move-color (and moves (car (car moves)))))
    (sgf-write-game
     :size size
     :komi (engine-komi engine)
     :setup setup
     :player-to-play (when setup
                       (if first-move-color
                           first-move-color
                           (position-to-play pos)))
     :result (when (is-terminal-p pos)
               (score-string pos :komi (engine-komi engine)))
     :moves moves)))
