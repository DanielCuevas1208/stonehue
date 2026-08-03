(in-package :stonehue/tests)

(in-suite stonehue-suite)

(test engine-genmove-applies-move
  (let ((engine (make-engine :size 9 :strength 1)))
    (let ((move (engine-genmove engine +black+)))
      (is (= 1 (position-move-number (engine-position engine))))
      (is (= +white+ (position-to-play (engine-position engine))))
      (when (integerp move)
        (is (= +black+ (stone-at (engine-position engine) move)))))))

(test engine-play-legal-and-illegal
  (let ((engine (make-engine :size 9 :strength 1)))
    (is-true (engine-play engine +black+ (vertex->index 9 "D4")))
    (signals error (engine-play engine +black+ (vertex->index 9 "D4")))
    (is-true (engine-play engine +white+ (vertex->index 9 "D5")))))

(test engine-pass-move
  (let ((engine (make-engine :size 9 :strength 1)))
    (engine-pass engine +black+)
    (is (eql :pass (position-last-move (engine-position engine))))
    (is (= +white+ (position-to-play (engine-position engine))))))

(test engine-undo-restores-position
  (let ((engine (make-engine :size 9 :strength 1 :seed 3)))
    (let ((before (position-copy (engine-position engine))))
      (engine-genmove engine +black+)
      (is-true (engine-undo engine))
      (is (= (position-hash before) (position-hash (engine-position engine))))
      (is (eql (position-to-play before) (position-to-play (engine-position engine))))
      (is (= (position-move-number before) (position-move-number (engine-position engine)))))))

(test engine-undo-empty-stack
  (let ((engine (make-engine :size 9 :strength 1)))
    (is-false (engine-undo engine))))

(test engine-strength-setting
  (let ((engine (make-engine :size 9 :strength 1)))
    (engine-set-strength engine 5)
    (is (= 5 (engine-strength engine)))
    (is (= (strength-iterations 5) (engine-iterations engine)))
    (signals error (engine-set-strength engine 7))))

(test engine-komi-setting
  (let ((engine (make-engine :size 9)))
    (engine-set-komi engine 7.5)
    (is (= 7.5 (engine-komi engine)))))

(test engine-time-settings-set-budget
  (let ((engine (make-engine :size 9)))
    (engine-set-time-settings engine 600 0 0)
    (is-true (engine-time-limit engine))
    (engine-set-time-settings engine 0 30 20)
    (is (< (abs (- 1.5 (engine-time-limit engine))) 1e-6))))

(test engine-genmove-deterministic
  (labels ((play-once ()
             (let ((engine (make-engine :size 9 :strength 1 :seed 11)))
               (engine-play engine +black+ (vertex->index 9 "D4"))
               (engine-play engine +white+ (vertex->index 9 "F4"))
               (engine-genmove engine +black+))))
    (is (equal (play-once) (play-once)))))
