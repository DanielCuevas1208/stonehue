(in-package :stonehue/tests)

(in-suite stonehue-suite)

(test gtp-protocol-version
  (let ((server (make-gtp-server)))
    (is (string= "= 2" (process-line server "protocol_version")))))

(test gtp-name-and-version
  (let ((server (make-gtp-server)))
    (is (string= "= Stonehue" (process-line server "name")))
    (is (string= (format nil "= ~a" +version+)
                 (process-line server "version")))))

(test gtp-boardsize
  (let ((server (make-gtp-server)))
    (is (string= "= " (process-line server "boardsize 9")))
    (is (search "?" (process-line server "boardsize 25")))
    (is (string= "= " (process-line server "boardsize 19")))))

(test gtp-play-responds
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (is (string= "= " (process-line server "play b D4")))
    (is (search "?" (process-line server "play b D4")))))

(test gtp-play-pass
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (is (string= "= " (process-line server "play b pass")))))

(test gtp-genmove-returns-vertex
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (process-line server "stonehue_seed 42")
    (process-line server "stonehue_strength 1")
    (let ((response (process-line server "genmove b")))
      (is (search "= " response))
      (let ((vertex (string-trim '(#\Space #\Tab) (subseq response 2))))
        (unless (string-equal vertex "pass")
          (is (integerp (vertex->index 9 vertex))))))))

(test gtp-known-and-list-commands
  (let ((server (make-gtp-server)))
    (is (string= "= true" (process-line server "known_command genmove")))
    (is (string= "= false" (process-line server "known_command fly")))
    (let ((response (process-line server "list_commands")))
      (is (search "protocol_version" response))
      (is (search "genmove" response))
      (is (search "quit" response)))))

(test gtp-unknown-command
  (let ((server (make-gtp-server)))
    (is (search "?" (process-line server "frobnicate")))))

(test gtp-id-echo
  (let ((server (make-gtp-server)))
    (is (string= "= 7 2" (process-line server "7 protocol_version")))
    (is (search "? 3 " (process-line server "3 frobnicate")))))

(test gtp-ko-through-commands
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (dolist (cmd '("play b A2" "play w B2" "play b B1" "play w A3"
                   "play b C2" "play w C3" "play b G1" "play w B4"))
      (is (string= "= " (process-line server cmd))))
    (is (string= "= " (process-line server "play b B3")))
    (is (search "?" (process-line server "play w B2")))))

(test gtp-final-score-format
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (process-line server "komi 6.5")
    (is (string= "= W+6.5" (process-line server "final_score")))))

(test gtp-handicap
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (is (string= "= " (process-line server "fixed_handicap 4")))
    (is (search "?" (process-line server "fixed_handicap 12")))
    (process-line server "clear_board")
    (is (string= "= " (process-line server "place_free_handicap A2 B2 C2")))))

(test gtp-handicap-turn-order
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (process-line server "place_free_handicap A2 B2 C2")
    (is (eql +white+
             (position-to-play (engine-position (gtp-server-engine server)))))
    (process-line server "clear_board")
    (process-line server "set_free_handicap A2 B2 C2")
    (is (eql +black+
             (position-to-play (engine-position (gtp-server-engine server)))))))

(test gtp-handicap-records-setup
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (process-line server "fixed_handicap 4")
    (is (= 4 (length (engine-setup (gtp-server-engine server)))))
    (is (zerop (length (engine-move-list (gtp-server-engine server)))))
    (let ((sgf (process-line server "printsgf")))
      (is (search "AB[" sgf))
      (is (search "PL[W]" sgf)))))

(test gtp-showboard
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (process-line server "play b D4")
    (let ((response (process-line server "showboard")))
      (is (search "X" response))
      (is (search "A" response)))))

(test gtp-time-settings
  (let ((server (make-gtp-server)))
    (is (string= "= " (process-line server "time_settings 600 30 20")))
    (is (string= "= " (process-line server "kgs-time_settings 600 30 20")))))

(test gtp-stonehue-extension-commands
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (is (string= "= " (process-line server "stonehue_seed 42")))
    (is (string= "= " (process-line server "stonehue_strength 1")))
    (let ((response (process-line server "stonehue_opening")))
      (is (search "Hoshi" response)))
    (process-line server "genmove b")
    (let ((response (process-line server "stonehue_analyze")))
      (is (search "pass" response)))))

(test gtp-deterministic-genmove
  (labels ((play-once ()
             (let ((server (make-gtp-server)))
               (process-line server "boardsize 9")
               (process-line server "stonehue_seed 42")
               (process-line server "stonehue_strength 1")
               (process-line server "play b D4")
               (process-line server "play w F4")
               (process-line server "genmove b"))))
    (is (string= (play-once) (play-once)))))

(test gtp-quit-stops-server
  (let ((server (make-gtp-server)))
    (is (string= "= " (process-line server "quit")))
    (is-false (gtp-server-running server))))

(test gtp-crlf-line-endings
  (let ((server (make-gtp-server)))
    (is (string= "= 2"
                 (process-line server
                               (concatenate 'string "protocol_version"
                                            (string #\Return)))))
    (is (string= "= "
                 (process-line server
                               (concatenate 'string "boardsize 9"
                                            (string #\Return)))))))

(defun fixture-path (name)
  "Return the full path of a GTP fixture inside examples/fixtures."
  (merge-pathnames name
                   (merge-pathnames "examples/fixtures/"
                                    (asdf:system-source-directory :stonehue))))

(defun temp-path (name)
  "Return a path inside the system temporary directory."
  (merge-pathnames name (uiop:temporary-directory)))

(test gtp-loadsgf-missing-file
  (let ((server (make-gtp-server)))
    (process-line server "boardsize 9")
    (is (search "?" (process-line server "loadsgf /no/such/file.sgf")))))

(test gtp-loadsgf-and-printsgf-roundtrip
  (let* ((path (temp-path "stonehue-gtp-roundtrip.sgf"))
         (server (make-gtp-server)))
    (unwind-protect
         (progn
           (process-line server "boardsize 9")
           (process-line server "komi 6.5")
           (process-line server "play b D4")
           (process-line server "play w F4")
           (process-line server "play b D6")
           (is (string= "= "
                        (process-line server
                                      (format nil "printsgf ~a" path))))
           (let ((sgf (process-line server "printsgf")))
             (is (search "FF[4]" sgf))
             (is (search "SZ[9]" sgf))
             (is (search "B[df]" sgf))
             (is (search "W[ff]" sgf))
             (is (search "B[dd]" sgf)))
           (process-line server "clear_board")
           (is (string= "= "
                        (process-line server
                                      (format nil "loadsgf ~a" path))))
           (is (= 3 (position-move-number
                     (engine-position (gtp-server-engine server)))))
           (is (= 3 (length (engine-move-list (gtp-server-engine server)))))
           (is (string= "= W+5.5" (process-line server "final_score"))))
      (ignore-errors (delete-file path)))))

(test gtp-loadsgf-with-move-number
  (let* ((path (temp-path "stonehue-gtp-partial.sgf"))
         (server (make-gtp-server)))
    (unwind-protect
         (progn
           (process-line server "boardsize 9")
           (process-line server "play b D4")
           (process-line server "play w F4")
           (process-line server "play b D6")
           (is (string= "= "
                        (process-line server
                                      (format nil "printsgf ~a" path))))
           (process-line server "clear_board")
           (is (string= "= "
                        (process-line server
                                      (format nil "loadsgf ~a 1" path))))
           (is (= 1 (position-move-number
                     (engine-position (gtp-server-engine server)))))
           (is (eql +white+
                    (position-to-play (engine-position (gtp-server-engine server))))))
      (ignore-errors (delete-file path)))))

(test gtp-loadsgf-unsupported-size
  (let* ((path (temp-path "stonehue-gtp-badsize.sgf"))
         (server (make-gtp-server)))
    (unwind-protect
         (progn
           (with-open-file (out path :direction :output :if-exists :supersede)
             (write-string "(;FF[4]GM[1]SZ[21])" out))
           (is (search "?" (process-line server
                                         (format nil "loadsgf ~a" path)))))
      (ignore-errors (delete-file path)))))

(test gtp-loadsgf-replays-pass-moves
  (let* ((path (temp-path "stonehue-gtp-pass.sgf"))
         (server (make-gtp-server)))
    (unwind-protect
         (progn
           (with-open-file (out path :direction :output :if-exists :supersede)
             (write-string "(;FF[4]GM[1]SZ[9]KM[6.5];B[dd];W[])" out))
           (is (string= "= "
                        (process-line server
                                      (format nil "loadsgf ~a" path))))
           (is (= 2 (position-move-number
                     (engine-position (gtp-server-engine server)))))
           (is (eql :pass (position-last-move (engine-position (gtp-server-engine server))))))
      (ignore-errors (delete-file path)))))

(defun replay-fixture (name)
  "Run every command in fixture NAME and return the list of replies."
  (with-open-file (in (fixture-path name))
    (let ((server (make-gtp-server)))
      (loop for line = (read-line in nil :eof)
            while (not (eq line :eof))
            for clean = (string-trim '(#\Space #\Tab) line)
            when (and (plusp (length clean))
                      (not (equal #\# (char clean 0))))
            collect (process-line server clean)))))

(test gtp-replay-basic-session
  (let ((replies (replay-fixture "basic-session.gtp")))
    (is (plusp (length replies)))
    (dolist (reply replies)
      (is (equal #\= (char reply 0))))))

(test gtp-replay-ko-fixture
  (let ((replies (replay-fixture "ko-game.gtp")))
    (is (= 11 (length replies)))
    (is (every (lambda (reply) (equal #\= (char reply 0)))
               (subseq replies 0 10)))
    (is (equal #\? (char (nth 10 replies) 0)))))

(test gtp-replay-opening-13x13
  (let ((replies (replay-fixture "opening-13x13.gtp")))
    (is (plusp (length replies)))
    (dolist (reply replies)
      (is (equal #\= (char reply 0))))))
