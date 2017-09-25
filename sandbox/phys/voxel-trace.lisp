(in-package :sandbox)

(defun aux-func (x dx)
  (if (zerop dx)
      nil
      (if (plusp dx)
	  (floor (1+ x))
	  (ceiling (1- x)))))


(defun aux-func2 (x dx)
  (if (zerop dx)
      nil
      (if (plusp dx)
	  (ceiling x)
	  (floor x))))

(defun floor2 (x)
  (1- (ceiling x)))
(defun ceiling2 (x)
  (1+ (floor x)))

(defun aabb-collect-blocks (px py pz dx dy dz aabb func)
  (with-slots ((minx aabbcc::minx) (miny aabbcc::miny) (minz aabbcc::minz)
	       (maxx aabbcc::maxx) (maxy aabbcc::maxy) (maxz aabbcc::maxz)) aabb
    (block cya
      (let ((total 1))
	(let ((pluspdx (plusp dx))
	      (pluspdy (plusp dy))
	      (pluspdz (plusp dz))
	      (zeropdx (zerop dx))
	      (zeropdy (zerop dy))
	      (zeropdz (zerop dz)))
	  (when (and zeropdx zeropdy zeropdz)
	    (return-from cya))
	  (let ((xoffset (if zeropdx 0.0 (if pluspdx maxx minx)))
		(yoffset (if zeropdy 0.0 (if pluspdy maxy miny)))
		(zoffset (if zeropdz 0.0 (if pluspdz maxz minz))))
	    (let ((x (+ px xoffset))
		  (y (+ py yoffset))
		  (z (+ pz zoffset)))
	      (flet ((collide-surface (newx newy newz i? j? k?)
		       (let ((aabb-posx (- newx xoffset))
			     (aabb-posy (- newy yoffset))
			     (aabb-posz (- newz zoffset)))
					;	 (print "a")
			 (when i?
			   (dobox ((j (floor2 (+ aabb-posy miny))
				      (ceiling2 (+ aabb-posy maxy)))
				   (k (floor2 (+ aabb-posz minz))
				      (ceiling2 (+ aabb-posz maxz))))
				  (funcall func (if pluspdx newx (1- newx)) j k)))
					;	 (print "b")
			 (when j?
			   (dobox ((i (floor2 (+ aabb-posx minx))
				      (ceiling2 (+ aabb-posx maxx)))
				   (k (floor2 (+ aabb-posz minz))
				      (ceiling2 (+ aabb-posz maxz))))
				  (funcall func i (if pluspdy newy (1- newy)) k)))
					;(print "c")
			 (when k?
			   (dobox ((j (floor2 (+ aabb-posy miny))
				      (ceiling2 (+ aabb-posy maxy)))
				   (i (floor2 (+ aabb-posx minx))
				      (ceiling2 (+ aabb-posx maxx))))
				  (funcall func i j (if pluspdz newz (1- newz))))))))
		(let ((i-next (aux-func2 x dx))
		      (j-next (aux-func2 y dy))
		      (k-next (aux-func2 z dz)))
		  (tagbody
		   rep
					;     		   (print (list i-next j-next k-next))		     
		     (let ((i? nil)
			   (j? nil)
			   (k? nil)
			   (ratio nil))
		       ;;;;find the shortest distance to the next axis-aligned surface,
		       ;;;;setting the ? vars to true if they are the closest
		       (let ((fooi (if i-next
				       (/ (- i-next x) dx)
				       nil))
			     (fooj (if j-next
				       (/ (- j-next y) dy)
				       nil))
			     (fook (if k-next
				       (/ (- k-next z) dz)
				       nil)))
			 ;;		 (print (list fooi fooj fook))
			 (progn
			   (when fooi
			     (setf ratio (if ratio					    
					     (min ratio fooi)
					     fooi)))
			   (when fooj
			     (setf ratio (if ratio					    
					     (min ratio fooj)
					     fooj)))
			   (when fook
			     (setf ratio (if ratio					    
					     (min ratio fook)
					     fook))))
			 (progn
			   (when fooi
			     (when (= ratio fooi)
			       (setf i? t)))
			   (when fooj
			     (when (= ratio fooj)
			       (setf j? t)))
			   (when fook
			     (when (= ratio fook)
			       (setf k? t)))))

		       (decf total ratio)
		       (when (minusp total) (return-from cya))
		       (when (zerop (/ most-positive-single-float ratio))
			 (return-from cya))
		       (let ((newx (if i? i-next (+ x (* dx ratio))))
			     (newy (if j? j-next (+ y (* dy ratio))))
			     (newz (if k? k-next (+ z (* dz ratio)))))
			 
			 (collide-surface newx newy newz i? j? k?)

			 #+nil
			 (progn
			   (when i? (if (plusp dx)
					(incf newx)
					(decf newx)))
			   (when j? (if (plusp dy)
					(incf newy)
					(decf newy)))
			   (when k? (if (plusp dz)
					(incf newz)
					(decf newz))))

			 (setf x newx y newy z newz))

		       (setf i-next (aux-func x dx)
			     j-next (aux-func y dy)
			     k-next (aux-func z dz)))
		     (go rep)))))))))))

(defun floor5 (x)
  (1- (ceiling x)))
(defun get-blocks-around (aabb-posx aabb-posy aabb-posz aabb func)
  (with-slots ((minx aabbcc::minx) (miny aabbcc::miny) (minz aabbcc::minz)
	       (maxx aabbcc::maxx) (maxy aabbcc::maxy) (maxz aabbcc::maxz)) aabb
    (let ((minx (+ minx aabb-posx))
	  (maxx (+ maxx aabb-posx))
	  (miny (+ miny aabb-posy))
	  (maxy (+ maxy aabb-posy))
	  (minz (+ minz aabb-posz))
	  (maxz (+ maxz aabb-posz)))
      (dobox ((j (floor miny)
		 (ceiling maxy))
	      (k (floor minz)
		 (ceiling maxz)))
	     (funcall func (floor5 minx) j k)
	     (funcall func (floor maxx) j k))
      (dobox ((i (floor minx)
		 (ceiling maxx))
	      (k (floor minz)
		 (ceiling maxz)))
	     (funcall func i (floor5 miny) k)
	     (funcall func i (floor maxy) k))
      (dobox ((j (floor miny)
		 (ceiling maxy))
	      (i (floor minx)
		 (ceiling maxx)))
	     (funcall func i j (floor5 minz))
	     (funcall func i j (floor maxz))))))

#+nil
(defparameter *bar* nil)
#+nil
()

					;		       (print (list xoffset yoffset zoffset))

					;	       (print "asdfasdfa")

					;		     (print (list i? j? k?))

#+nil
(defun smallest (i j k)
  (if (< i j)
      (if (< i k) ;;i < j j is out
	  (values i t nil nil)	  ;;; i < k and i < j
	  (if (= i k)
	      (values i t nil t) ;;;tied for smallest
	      (values k nil nil t)	     ;;; k < i <j
	      ))
      (if (< j k) ;;i>=j
	  (if (= i j)
	      (values i t t nil)
	      (values j nil t nil)) ;;j<k and i<=j k is nout
	  (if (= i k)
	      (values i t t t)
	      (if (= k j)
		  (values k nil t t)
		  (values k nil nil t))) ;;i>=j>=k
	  )))

;;			 (print (list fooi fooj fook))
#+nil
(smallest 
 fooi fooj fook
 )