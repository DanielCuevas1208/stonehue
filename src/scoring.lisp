(in-package :stonehue)

;;; Simple Chinese area scoring. Each empty region belongs to the
;;; color of the stones that surround it. A region touching both
;;; colors is dame and scores for nobody.

(defun territory-of (position)
  "Classify the empty regions of POSITION.
Return (values black-territory white-territory dame)."
  (let* ((size (position-size position))
         (board (position-board position))
         (n (* size size))
         (seen (make-array n :element-type 'bit :initial-element 0))
         (black 0)
         (white 0)
         (dame 0))
    (dotimes (start n)
      (when (and (zerop (aref board start))
                 (zerop (aref seen start)))
        (let ((queue (make-array n :element-type 'fixnum))
              (head 0)
              (tail 0)
              (count 0)
              (black-touch nil)
              (white-touch nil))
          (setf (aref seen start) 1)
          (setf (aref queue tail) start)
          (incf tail)
          (loop while (< head tail)
                for p = (aref queue head)
                do (incf head)
                   (incf count)
                   (dolist (nb (neighbors size p))
                     (let ((s (aref board nb)))
                       (cond ((zerop s)
                              (when (zerop (aref seen nb))
                                (setf (aref seen nb) 1)
                                (setf (aref queue tail) nb)
                                (incf tail)))
                             ((= s +black+)
                              (setf black-touch t))
                             (t
                              (setf white-touch t))))))
          (cond ((and black-touch (not white-touch))
                 (incf black count))
                ((and white-touch (not black-touch))
                 (incf white count))
                (t
                 (incf dame count))))))
    (values black white dame)))

(defun score-position (position &key (komi 6.5))
  "Return (values black-score white-score) using Chinese area scoring."
  (let ((board (position-board position))
        (n (* (position-size position) (position-size position)))
        (black 0)
        (white 0))
    (dotimes (i n)
      (let ((s (aref board i)))
        (when (= s +black+) (incf black))
        (when (= s +white+) (incf white))))
    (multiple-value-bind (black-territory white-territory)
        (territory-of position)
      (values (+ black black-territory)
              (+ white white-territory komi)))))

(defun score-margin (position &key (komi 6.5))
  "Return the final margin as black minus white."
  (multiple-value-bind (black white) (score-position position :komi komi)
    (- black white)))

(defun score-string (position &key (komi 6.5))
  "Return a GTP final_score value such as B+3.5 or 0."
  (let ((margin (score-margin position :komi komi)))
    (cond ((> margin 0)
           (format nil "B+~,1f" margin))
          ((< margin 0)
           (format nil "W+~,1f" (abs margin)))
          (t "0"))))

(defun material-margin (position &key (komi 0.0))
  "Return the material balance used for playout evaluation.
This is Black stones plus Black prisoners minus the same for White,
minus KOMI."
  (let ((board (position-board position))
        (n (* (position-size position) (position-size position)))
        (black 0)
        (white 0))
    (dotimes (i n)
      (let ((s (aref board i)))
        (when (= s +black+) (incf black))
        (when (= s +white+) (incf white))))
    (- (+ black (position-captures-black position))
       (+ white (position-captures-white position))
       komi)))
