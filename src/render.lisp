(in-package :stonehue)

(defun render-position (position)
  "Return a printable ASCII picture of the position.
X is black, O is white, and . is an empty point."
  (let* ((size (position-size position))
         (board (position-board position))
         (lines '()))
    (push (format nil "   ~{~a~^ ~}"
                  (coerce (subseq +vertex-letters+ 0 size) 'list))
          lines)
    (loop for row from (1- size) downto 0
          do (let ((cells '()))
               (dotimes (col size)
                 (let ((stone (aref board (row-col->index size row col))))
                   (push (cond ((= stone +black+) #\X)
                               ((= stone +white+) #\O)
                               (t #\.))
                         cells)))
               (push (format nil "~2d ~{~a~^ ~}" (1+ row) (nreverse cells))
                     lines)))
    (format nil "~{~a~%~}" (nreverse lines))))
