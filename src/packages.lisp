(defpackage :stonehue
  (:use :cl)
  (:nicknames :stonehue)
  (:export
   ;; --- version ---
   #:+version+
   #:version-string
   ;; --- random ---
   #:make-rng
   #:rng-random
   #:rng-integer
   #:rng-choose
   #:rng-shuffle
   ;; --- board ---
   #:+empty+
   #:+black+
   #:+white+
   #:+pass+
   #:make-board
   #:board-p
   #:board-size
   #:board-ref
   #:board-cells
   #:board-copy
   #:row-col->index
   #:index->row-col
   #:neighbors
   #:vertex->index
   #:index->vertex
   #:all-points
   #:render-position
   ;; --- rules ---
   #:make-position
   #:position-size
   #:position-board
   #:position-to-play
   #:position-move-number
   #:position-last-move
   #:position-captured-last
   #:position-copy
   #:stone-at
   #:other-color
   #:color-name
   #:group-of
   #:group-liberties
   #:legal-move-p
   #:legal-moves
   #:try-play
   #:play-move
   #:pass-move
   #:is-terminal-p
   #:position-hash
   #:consecutive-passes
   ;; --- scoring ---
   #:score-position
   #:score-margin
   #:score-string
   #:material-margin
   #:territory-of
   ;; --- mcts ---
   #:mcts-search
   #:mcts-analyze
   ;; --- opening ---
   #:opening-hints
   #:opening-hint-table
   #:opening-weight
   #:handicap-points
   ;; --- engine ---
   #:make-engine
   #:engine-position
   #:engine-play
   #:engine-pass
   #:engine-genmove
   #:engine-undo
   #:engine-strength
   #:engine-komi
   #:engine-iterations
   #:engine-time-limit
   #:engine-use-opening
   #:engine-last-stats
   #:engine-set-time-settings
   #:engine-set-strength
   #:engine-set-komi
   #:engine-set-iterations
   #:engine-set-time-limit
   #:engine-set-use-opening
   #:strength-iterations
   #:strength-time-limit
    ;; --- gtp ---
    #:gtp-name
    #:gtp-version
    #:make-gtp-server
    #:process-line
    #:run-gtp
    #:gtp-server-engine
    #:gtp-server-running
    #:gtp-server-last-id))

(in-package :stonehue)

(defparameter +version+ "0.1.0")

(defun version-string ()
  "Return the Stonehue version as a string."
  +version+)
