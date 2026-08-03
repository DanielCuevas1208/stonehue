(in-package :stonehue)

(defstruct (rng (:constructor %make-rng (state)))
  (state 0 :type (unsigned-byte 64)))

(defun make-rng (&optional (seed 88172645463325252))
  "Return a deterministic pseudo-random generator seeded with SEED."
  (declare (type (integer 1 18446744073709551615) seed))
  (%make-rng seed))

(declaim (inline %rng-next))
(defun %rng-next (rng)
  "Advance the xorshift64* generator and return a fresh 64-bit value."
  (let ((x (rng-state rng)))
    (when (zerop x)
      (setf x 88172645463325252))
    (setf x (logand #xFFFFFFFFFFFFFFFF (logxor x (ash x 13))))
    (setf x (logand #xFFFFFFFFFFFFFFFF (logxor x (ash x -7))))
    (setf x (logand #xFFFFFFFFFFFFFFFF (logxor x (ash x 17))))
    (setf (rng-state rng) x)
    (logand #xFFFFFFFFFFFFFFFF (* x 2685821657736338717))))

(defun rng-random (rng)
  "Return a double float uniformly in [0, 1)."
  (/ (%rng-next rng) (coerce (ash 1 64) 'double-float)))

(defun rng-integer (rng n)
  "Return a non-negative integer less than N."
  (declare (type (integer 1 #.most-positive-fixnum) n))
  (mod (%rng-next rng) n))

(defun rng-choose (rng sequence)
  "Return a random element of SEQUENCE."
  (elt sequence (rng-integer rng (length sequence))))

(defun rng-shuffle (rng sequence)
  "Return a shuffled copy of SEQUENCE using the Fisher-Yates method."
  (let ((result (coerce sequence 'vector)))
    (loop for i from (1- (length result)) downto 1
          for j = (rng-integer rng (1+ i))
          do (rotatef (aref result i) (aref result j)))
    (coerce result 'list)))
