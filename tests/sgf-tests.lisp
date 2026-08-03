(in-package :stonehue/tests)

(in-suite stonehue-suite)

(defun sgf-roundtrip-index (size idx)
  "Return the index recovered from SGF after writing INDEX as a point."
  (sgf-coord-to-index size (index-to-sgf size idx)))

(test sgf-coordinate-round-trip
  (dolist (size (list 9 13 19))
    (dotimes (idx (* size size))
      (is (= idx (sgf-roundtrip-index size idx))))))

(test sgf-coordinate-known-points
  (is (string= "ai" (index-to-sgf 9 (vertex->index 9 "A1"))))
  (is (string= "df" (index-to-sgf 9 (vertex->index 9 "D4"))))
  (is (string= "dd" (index-to-sgf 9 (vertex->index 9 "D6"))))
  (is (string= "ff" (index-to-sgf 9 (vertex->index 9 "F4"))))
  (is (string= "D4" (index->vertex 9 (sgf-coord-to-index 9 "df")))))

(test sgf-pass-coordinates
  (is-true (sgf-pass-coord-p ""))
  (is-true (sgf-pass-coord-p "tt"))
  (is-true (sgf-pass-coord-p "TT"))
  (is-false (sgf-pass-coord-p "dd"))
  (is-false (sgf-pass-coord-p "zz")))

(test sgf-out-of-range-coordinate
  (is (= 72 (sgf-coord-to-index 9 "aa")))
  (is-false (sgf-coord-to-index 9 "jj"))
  (is-false (sgf-coord-to-index 9 "zz"))
  (is-false (sgf-coord-to-index 9 "d!")))

(test sgf-parse-basic-game
  (let* ((text "(;FF[4]GM[1]SZ[9]KM[6.5];B[dd];W[ff];B[df];W[tt])")
         (trees (parse-sgf text))
         (info (sgf-game-info (first trees))))
    (is (= 1 (length trees)))
    (is (= 9 (getf info :size)))
    (is (= 6.5 (getf info :komi)))
    (is (= 4 (length (getf info :moves))))
    (is (equal (cons +black+ "dd") (first (getf info :moves))))
    (is (equal (cons +white+ "ff") (second (getf info :moves))))
    (is (equal (cons +white+ "tt") (fourth (getf info :moves))))))

(test sgf-parse-whitespace-and-comments
  (let* ((text (format nil "(;FF[4]GM[1]SZ[19]C[escaped ~a bracket]
~a)
(;FF[4]GM[1]SZ[13])
"
                      "\\]" ";"))
         (trees (parse-sgf text)))
    (is (= 2 (length trees)))
    (is (= 19 (getf (sgf-game-info (first trees)) :size)))
    (is (= 13 (getf (sgf-game-info (second trees)) :size)))))

(test sgf-parse-handicap-setup
  (let* ((text "(;FF[4]GM[1]SZ[9]HA[2]AB[dd][ff]PL[W];W[ee])")
         (info (sgf-game-info (first (parse-sgf text)))))
    (is (= 2 (length (getf info :setup))))
    (is (equal (cons +black+ "dd") (first (getf info :setup))))
    (is (equal +white+ (getf info :player-to-play)))
    (is (= 1 (length (getf info :moves))))))

(test sgf-parse-malformed-text
  (signals error (parse-sgf "(;FF[4]"))
  (signals error (parse-sgf "(;B)"))
  (signals error (parse-sgf "not sgf")))

(test sgf-write-and-reparse
  (let* ((moves (list (cons +black+ (vertex->index 9 "D4"))
                      (cons +white+ (vertex->index 9 "F4"))
                      (cons +black+ :pass)))
         (text (sgf-write-game :size 9 :komi 6.5 :moves moves))
         (info (sgf-game-info (first (parse-sgf text)))))
    (is (search "FF[4]" text))
    (is (search "SZ[9]" text))
    (is (search "KM[6.5]" text))
    (is (= 3 (length (getf info :moves))))
    (is (equal (list (cons +black+ "df")
                     (cons +white+ "ff")
                     (cons +black+ ""))
               (getf info :moves)))))

(test sgf-write-setup-and-player
  (let* ((setup (list (cons +black+ (vertex->index 9 "D4"))
                      (cons +black+ (vertex->index 9 "F6"))))
         (text (sgf-write-game :size 9
                               :setup setup
                               :player-to-play +white+))
         (info (sgf-game-info (first (parse-sgf text)))))
    (is (search "AB[df]" text))
    (is (search "PL[W]" text))
    (is (= 2 (length (getf info :setup))))
    (is (equal +white+ (getf info :player-to-play)))))

(defun sample-sgf-path ()
  "Return the path of the sample SGF game record."
  (merge-pathnames "sample-game.sgf"
                   (merge-pathnames "examples/"
                                    (asdf:system-source-directory :stonehue))))

(test sgf-sample-game-loads
  (let* ((info (load-sgf-file (sample-sgf-path)))
         (engine (make-engine :size 9 :strength 1)))
    (apply-loaded-game engine info)
    (is (= 9 (getf info :size)))
    (is (plusp (length (getf info :moves))))
    (is (= (length (getf info :moves))
           (length (engine-move-list engine))))
    (is (eql (if (oddp (length (getf info :moves))) +white+ +black+)
             (position-to-play (engine-position engine))))))
