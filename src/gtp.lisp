(in-package :stonehue)

;;; A Go Text Protocol (GTP) version 2 server. It reads commands from
;;; one stream and writes responses to another, so standard Go tools
;;; can drive the engine.

(defstruct (gtp-server (:constructor %make-gtp-server (engine input output)))
  engine
  input
  output
  (running t)
  (last-id ""))

(defun make-gtp-server
    (&key (engine nil) (input *standard-input*) (output *standard-output*))
  "Return a GTP server. ENGINE defaults to a fresh engine."
  (%make-gtp-server (or engine (make-engine)) input output))

(defun gtp-name ()
  "Return the name reported by the GTP name command."
  "Stonehue")

(defun gtp-version ()
  "Return the version reported by the GTP version command."
  +version+)

;;; --- line parsing ---

(defun strip-comment (line)
  "Remove a trailing GTP comment starting at the first # character."
  (let ((pos (position #\# line)))
    (if pos (subseq line 0 pos) line)))

(defun tokenize (text)
  "Split TEXT on spaces and tabs and return a list of tokens."
  (let ((tokens '())
        (start nil)
        (end (length text)))
    (dotimes (i end)
      (let ((c (char text i)))
        (cond ((and (null start)
                    (not (eql c #\Space))
                    (not (eql c #\Tab)))
               (setf start i))
              ((and start
                    (or (eql c #\Space) (eql c #\Tab)))
               (push (subseq text start i) tokens)
               (setf start nil)))))
    (when start
      (push (subseq text start) tokens))
    (nreverse tokens)))

(defun digits-string-p (s)
  "Return T when S consists only of decimal digits."
  (and (plusp (length s)) (every #'digit-char-p s)))

(defun parse-color (token)
  "Parse a GTP color token into +black+ or +white+."
  (cond ((or (string-equal token "b") (string-equal token "black")) +black+)
        ((or (string-equal token "w") (string-equal token "white")) +white+)
        (t (error "Unknown color: ~a" token))))

(defun color-token (color)
  "Return the one-letter GTP token for COLOR."
  (if (eql color +black+) "b" "w"))

(defun parse-number (text)
  "Parse TEXT as a double float and signal an error otherwise."
  (let ((value (read-from-string text)))
    (unless (numberp value)
      (error "Not a number: ~a" text))
    (coerce value 'double-float)))

;;; --- command dispatch ---

(defvar *commands* (make-hash-table :test #'equal))

(defmacro def-command (name (server) &body body)
  "Register a GTP command named NAME taking the server and args."
  `(setf (gethash ,name *commands*)
         (lambda (,server args)
           (declare (ignorable ,server args))
           ,@body)))

(def-command "protocol_version" (server)
  (declare (ignore server))
  "2")

(def-command "name" (server)
  (declare (ignore server))
  (gtp-name))

(def-command "version" (server)
  (declare (ignore server))
  (gtp-version))

(def-command "quit" (server)
  (setf (gtp-server-running server) nil)
  nil)

(def-command "known_command" (server)
  (if (gethash (string-downcase (first args)) *commands*)
      "true"
      "false"))

(def-command "list_commands" (server)
  (format nil "~{~a~^~%~}"
          (sort (loop for key being the hash-keys of *commands* collect key)
                #'string<)))

(def-command "boardsize" (server)
  (let ((size (parse-integer (first args) :junk-allowed t)))
    (unless (and size (<= 3 size 19))
      (error "Unacceptable size: ~a" (first args)))
    (let ((engine (gtp-server-engine server)))
      (setf (engine-position engine) (make-position size))
      (setf (engine-undo-stack engine) '())
      (setf (engine-history engine) '())
      (setf (engine-setup engine) '()))
    nil))

(def-command "clear_board" (server)
  (let ((engine (gtp-server-engine server)))
    (setf (engine-position engine)
          (make-position (position-size (engine-position engine))))
    (setf (engine-undo-stack engine) '())
    (setf (engine-history engine) '())
    (setf (engine-setup engine) '()))
  nil)

(def-command "komi" (server)
  (engine-set-komi (gtp-server-engine server) (parse-number (first args)))
  nil)

(def-command "play" (server)
  (let* ((color (parse-color (first args)))
         (vertex (second args))
         (engine (gtp-server-engine server))
         (move (if (string-equal vertex "pass")
                   :pass
                   (vertex->index (position-size (engine-position engine))
                                  vertex))))
    (engine-play engine color move))
  nil)

(def-command "genmove" (server)
  (let* ((color (parse-color (first args)))
         (engine (gtp-server-engine server))
         (move (engine-genmove engine color)))
    (if (eq move :pass)
        "pass"
        (index->vertex (position-size (engine-position engine)) move))))

(def-command "undo" (server)
  (unless (engine-undo (gtp-server-engine server))
    (error "Cannot undo"))
  nil)

(def-command "loadsgf" (server)
  (let* ((engine (gtp-server-engine server))
         (filename (first args))
         (stop (when (second args)
                 (parse-integer (second args) :junk-allowed t))))
    (unless filename
      (error "loadsgf requires a filename"))
    (let ((info (load-sgf-file filename)))
      (apply-loaded-game engine info stop)))
  nil)

(def-command "printsgf" (server)
  (let* ((engine (gtp-server-engine server))
         (sgf (engine-to-sgf-text engine)))
    (if args
        (progn
          (with-open-file (out (first args)
                               :direction :output
                               :if-exists :supersede
                               :if-does-not-exist :create)
            (write-string sgf out))
          nil)
        sgf)))

(def-command "final_score" (server)
  (let ((engine (gtp-server-engine server)))
    (score-string (engine-position engine) :komi (engine-komi engine))))

(def-command "showboard" (server)
  (let ((engine (gtp-server-engine server)))
    (format nil "~%~a~%" (render-position (engine-position engine)))))

(def-command "time_settings" (server)
  (destructuring-bind (main byo stones)
      (mapcar #'parse-number args)
    (engine-set-time-settings (gtp-server-engine server) main byo stones))
  nil)

(def-command "kgs-time_settings" (server)
  (destructuring-bind (main byo stones &optional periods)
      (mapcar #'parse-number args)
    (declare (ignore periods))
    (engine-set-time-settings (gtp-server-engine server) main byo stones))
  nil)

(defun place-handicap-stones (engine n)
  "Place N standard black handicap stones and give the turn to White."
  (let* ((pos (engine-position engine))
         (size (position-size pos))
         (stones (handicap-points size n)))
    (engine-push-snapshot engine)
    (dolist (idx stones)
      (try-play pos +black+ idx))
    (setf (position-to-play pos) +white+)
    (setf (engine-setup engine)
          (mapcar (lambda (idx) (cons +black+ idx)) stones))
    (setf (engine-history engine) '())
    (setf (position-move-number pos) 0)))

(defun place-free-handicap (engine vertices &key (black-to-play nil))
  "Place black stones at VERTICES.
Give the turn to White unless BLACK-TO-PLAY is set."
  (let* ((pos (engine-position engine))
         (size (position-size pos)))
    (engine-push-snapshot engine)
    (let ((stones '()))
      (dolist (vertex vertices)
        (let ((idx (vertex->index size vertex)))
          (try-play pos +black+ idx)
          (push (cons +black+ idx) stones)))
      (setf (position-to-play pos)
            (if black-to-play +black+ +white+))
      (setf (engine-setup engine) (nreverse stones))
      (setf (engine-history engine) '())
      (setf (position-move-number pos) 0))))

(def-command "fixed_handicap" (server)
  (let* ((n (parse-integer (first args) :junk-allowed t))
         (engine (gtp-server-engine server)))
    (unless (and n (<= 2 n 9))
      (error "Unacceptable handicap: ~a" (first args)))
    (place-handicap-stones engine n))
  nil)

(def-command "place_free_handicap" (server)
  (place-free-handicap (gtp-server-engine server) args)
  nil)

(def-command "set_free_handicap" (server)
  (place-free-handicap (gtp-server-engine server) args :black-to-play t)
  nil)

(def-command "play_handicap" (server)
  (let* ((n (parse-integer (first args) :junk-allowed t))
         (engine (gtp-server-engine server)))
    (unless (and n (<= 2 n 9))
      (error "Unacceptable handicap: ~a" (first args)))
    (place-handicap-stones engine n)
    (dotimes (i n)
      (engine-genmove engine +white+)))
  nil)

(def-command "stonehue_strength" (server)
  (let ((level (parse-integer (first args) :junk-allowed t)))
    (engine-set-strength (gtp-server-engine server)
                         (if level level 3)))
  nil)

(def-command "stonehue_iterations" (server)
  (let ((iterations (parse-integer (first args) :junk-allowed t)))
    (unless (and iterations (<= 0 iterations))
      (error "Unacceptable iteration count: ~a" (first args)))
    (engine-set-iterations (gtp-server-engine server) iterations))
  nil)

(def-command "stonehue_seed" (server)
  (let* ((engine (gtp-server-engine server))
         (seed (parse-integer (first args))))
    (setf (engine-rng engine) (make-rng seed)))
  nil)

(def-command "stonehue_opening" (server)
  (let ((pos (engine-position (gtp-server-engine server))))
    (format nil "~{~a~^~%~}"
            (loop for (idx weight name) in (opening-hints pos)
                  collect (format nil "~a ~,2f ~a"
                                  (index->vertex (position-size pos) idx)
                                  weight
                                  name)))))

(def-command "stonehue_analyze" (server)
  (let* ((engine (gtp-server-engine server))
         (size (position-size (engine-position engine)))
         (stats (engine-last-stats engine)))
    (format nil "~{~a~^~%~}"
            (loop for (move plays wins rate) in stats
                  collect (format nil "~a ~d ~d ~,3f"
                                  (if (eq move :pass)
                                      "pass"
                                      (index->vertex size move))
                                  plays
                                  wins
                                  rate)))))

(def-command "stonehue_search_info" (server)
  (declare (ignore args))
  (let ((info (engine-last-search-info (gtp-server-engine server))))
    (format nil "transposition-hits ~d~%transposition-entries ~d"
            (or (getf info :transposition-hits) 0)
            (or (getf info :transposition-entries) 0))))

(def-command "gogui-analyze_commands" (server)
  (declare (ignore server))
  (format nil "gfx/Stonehue opening/stonehue_opening~%~
               plist/Stonehue analyze/stonehue_analyze~%~
               plist/Stonehue search info/stonehue_search_info"))

(defun error-message (condition)
  "Return a readable one-line message for CONDITION."
  (if (and (typep condition 'simple-condition)
           (simple-condition-format-control condition))
      (apply #'format nil (simple-condition-format-control condition)
             (simple-condition-format-arguments condition))
      (princ-to-string condition)))

(defun process-line (server line)
  "Parse one GTP command line and return the complete response line.
Leading and trailing whitespace, including carriage returns from
Windows line endings, are ignored."
  (handler-case
      (let* ((clean (string-trim '(#\Space #\Tab #\Return #\Newline) line))
             (tokens (tokenize (strip-comment clean)))
             (id ""))
        (when (and tokens (digits-string-p (first tokens)))
          (setf id (pop tokens)))
        (setf (gtp-server-last-id server) id)
        (if (null tokens)
            (format nil "= ~a" id)
            (let* ((command (string-downcase (pop tokens)))
                   (fn (gethash command *commands*)))
              (unless fn
                (error "Unknown command: ~a" command))
              (let ((body (funcall fn server tokens)))
                (cond ((or (null body) (zerop (length body)))
                       (format nil "= ~a" id))
                      ((zerop (length id))
                       (format nil "= ~a" body))
                      (t
                       (format nil "= ~a ~a" id body)))))))
    (error (e)
      (let ((msg (error-message e)))
        (if (zerop (length (gtp-server-last-id server)))
            (format nil "? ~a" msg)
            (format nil "? ~a ~a" (gtp-server-last-id server) msg))))))

(defun run-gtp (&key (input *standard-input*) (output *standard-output*))
  "Serve GTP commands from INPUT and write responses to OUTPUT.
Return when the quit command arrives or the input ends."
  (let ((server (make-gtp-server :input input :output output)))
    (loop while (gtp-server-running server)
          for line = (read-line input nil :eof)
          while (not (eq line :eof))
          do (let ((response (process-line server line)))
               (write-string response output)
               (terpri output)
               (finish-output output)))
    (values)))
