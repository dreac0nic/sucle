(in-package :sandbox)

(defparameter *box* #(0 128 0 128 -128 0))
(with-unsafe-speed
  (defun map-box (func &optional (box *box*))
    (declare (type (function (fixnum fixnum fixnum)) func)
	     (type simple-vector box))
    (etouq
     (with-vec-params (quote (x0 x1 y0 y1 z0 z1)) (quote (box))
		      (quote (dobox ((x x0 x1)
				     (y y0 y1)
				     (z z0 z1))
				    (funcall func x y z)))))))

(defun grassify (x y z)
  (let ((blockid (world:getblock x y z)))
    (when (= blockid 3)
      (let ((idabove (world:getblock x (1+ y) z)))
	(when (zerop idabove)
	  (plain-setblock x y z 2 0))))))

(defun dirts (x y z)
  (let ((blockid (world:getblock x y z)))
    (when (= blockid 1)
      (when (or (zerop (world:getblock x (+ 2 y) z))
		(zerop (world:getblock x (+ 3 y) z)))
	(plain-setblock x y z 3 0)))))

(defun find-top (x z min max test)
  (let ((delta (- max min)))
    (dotimes (i delta)
      (let* ((height (- max i 1))
	     (obj (funcall test x height z)))
	(when obj
	  (return-from find-top (values height obj)))))
    (values nil nil)))

(defun enclose ()
  (dobox ((x 0 128)
	  (y 0 128))
	 (plain-setblock x y -1   1 0)
	 (plain-setblock x y -2   1 0)
	 (plain-setblock x y -127 1 0)
	 (plain-setblock x y -128 1 0))
  (dobox ((z -128 0)
	  (y 0 128))
	 (plain-setblock 0   y z 1 0)
	 (plain-setblock 1   y z 1 0)
	 (plain-setblock 127 y z 1 0)
	 (plain-setblock 126 y z 1 0))
  (dobox ((z -128 0)
	  (x 0 128)
	  (y 0 64))
	 (plain-setblock x y z 1 0)))

(defun simple-relight (&optional (box *box*))
  (map-box (lambda (x y z)
	     (let ((blockid (world:getblock x y z)))
					;(unless (zerop blockid))
	       (let ((light (aref mc-blocks:*lightvalue* blockid)))
		 (if (zerop light)
		     (plain-setblock x y z blockid 0 0)
		     (plain-setblock x y z blockid light)))))
	   box)
  (map-box (lambda (x y z)
	     (multiple-value-bind (height obj)
		 (find-top x z 0 y (lambda (x y z)
				     (not (zerop (world:getblock x y z)))))
	       (declare (ignore obj))
	       (unless height
		 (setf height 0))
	       (dobox ((upup (1+ height) y))
		      (world:skysetlight x upup z 15))))
	   #(0 128 128 129 -128 0))
  (map-box (lambda (x y z)
	     (when (= 15 (world:skygetlight x y z))
	       (sky-light-node x y z)))
	   *box*)
  (map-box (lambda (x y z)
	     (unless (zerop (world:getblock x y z))
	       (light-node x y z)))
	   *box*))

(defun invert (x y z)
  (let ((blockid (world:getblock x y z)))
    (if (= blockid 0)
	(plain-setblock x y z 1 ;(aref #(56 21 14 73 15) (random 5))
			0)
	(plain-setblock x y z 0 0)
	)))

(defun neighbors (x y z)
  (let ((tot 0))
    (macrolet ((aux (i j k)
		 `(unless (zerop (world:getblock (+ x ,i) (+ y ,j) (+ z ,k)))
		   (incf tot))))
      (aux 1 0 0)
      (aux -1 0 0)
      (aux 0 1 0)
      (aux 0 -1 0)
      (aux 0 0 1)
      (aux 0 0 -1))
    tot))

(defun bonder (x y z)
  (let ((blockid (world:getblock x y z)))
    (unless (zerop blockid)
      (let ((naybs (neighbors x y z)))
	(when (> 3 naybs)		     
	  (plain-setblock x y z 0 0 0))))))

(defun bonder2 (x y z)
  (let ((blockid (world:getblock x y z)))
    (when (zerop blockid)
      (let ((naybs (neighbors x y z)))
	(when (< 2 naybs)		     
	  (plain-setblock x y z 1 0 0))))))

(defun invert-light (x y z)
  (when (zerop (world:getblock x y z))
    (let ((blockid2 (world:skygetlight x y z)))
      (Setf (world:skygetlight x y z) (- 15 blockid2)))))

(defun edge-bench (x y z)
  (let ((blockid (world:getblock x y z)))
    (unless (zerop blockid)
      (when (= 4 (neighbors x y z))
	(plain-setblock x y z 58 0 0)))))

(defun corner-obsidian (x y z)
  (let ((blockid (world:getblock x y z)))
    (unless (zerop blockid)
      (when (= 3 (neighbors x y z))
	(plain-setblock x y z 49 0 0)))))


(defun seed (id chance)
  (declare (type (unsigned-byte 8) id))
  (lambda (x y z)
    (let ((blockid (world:getblock x y z)))
      (when (and (zerop blockid)
		 (zerop (random chance)))
	(plain-setblock x y z id 0)))))

(defun grow (old new)
  (lambda (x y z)
    (let ((naybs (sandbox::neighbors2 x y z old)))
      (when (and (not (zerop naybs))
		 (zerop (world:getblock x y z))
		 (zerop (random (- 7 naybs))))
	(sandbox::plain-setblock x y z new 0)))))

(defun bub (new)
  (lambda (x y z)
    (let ((naybs (sandbox::neighbors2 x y z 0)))
      (when (and (not (zerop naybs))
		 (not (zerop (world:getblock x y z))))
	(sandbox::plain-setblock x y z new 0)))))

(defun bub2 (new)
  (lambda (x y z)
    (let ((naybs (sandbox::neighbors2 x y z 45)))
      (when (and (not (zerop naybs))
		 (not (or (zerop (world:getblock x y z))
			  (= 45 (world:getblock x y z)))))
	(sandbox::plain-setblock x y z new 0)))))

(defun sheath (old new)
  (lambda (x y z)
    (let ((naybs (sandbox::neighbors2 x y z old)))
      (when (and (not (zerop naybs))
		 (zerop (world:getblock x y z)))
	(sandbox::plain-setblock x y z new 0)))))

(defun neighbors2 (x y z w)
  (let ((tot 0))
    (macrolet ((aux (i j k)
		 `(when (= w (world:getblock (+ x ,i) (+ y ,j) (+ z ,k)))
		   (incf tot))))
      (aux 1 0 0)
      (aux -1 0 0)
      (aux 0 1 0)
      (aux 0 -1 0)
      (aux 0 0 1)
      (aux 0 0 -1))
    tot))

(defun testes (&optional (box *box*))
  (map nil
       (lambda (x) (map-box x box))
       (list #'sandbox::edge-bench
	     #'corner-obsidian
	     (clearblock? 49)
	     (clearblock? 58))))
(defun testicle (&optional (box *box*))
  (dotimes (x 1)
    (map nil
	 (lambda (x) (map-box x box))
	 (list #'sandbox::edge-bench
	       #'corner-obsidian
	       (clearblock? 49)
	       (clearblock? 58)))
    (dotimes (x 3) (map-box #'sandbox::bonder box))))

(defun dirt-sand (x y z)
  (let ((blockid (world:getblock x y z)))
    (case blockid
      (2 (plain-setblock x y z 12 0))
      (3 (plain-setblock x y z 24 0)))))

(defun cactus (x y z)
  (let ((trunk-height (+ 1 (random 3))))
    (dobox ((y0 0 trunk-height))
	   (plain-setblock (+ x 0) (+ y y0) (+ z 0) 81 0 0))))

(defun huuh (&optional (box *box*))
  (flet ((dayum (x)
	   (map-box x box))
	 (message (x)
	   (princ x)))
    (message "seeding")
    (dayum (sandbox::seed 1 10000))
    (message "growing")
    (let ((fun (grow 1 1)))
      (dotimes (x 30)
	(dayum fun)))
    (message "bonding")
    (dotimes (x 10)
      (dayum #'bonder))
    (message "inverting")
    (dayum #'sandbox::invert)
    (message "bonding again")
    (dotimes (x 10)
      (dayum #'bonder))
    (message "inverting and smoothing edges")
    (dotimes (x 4)
      (dayum #'sandbox::invert)
      (dotimes (x (1+ (random 4)))
	(sandbox::testicle box)))
    (message "grinding stone into dirt")
    (dayum #'dirts)
    (message "growing grass on the dirt")
    (dayum #'grassify)
    (message "sunshining")
    (simple-relight)))

(defun growdown (old new)
  (lambda (x y z)
    (let ((naybs (sandbox::neighbors3 x y z old)))
      (when (and (not (zerop naybs))
		 (zerop (world:getblock x y z))
		 (zerop (random (- 7 naybs))))
	(sandbox::plain-setblock x y z new 0)))))

(defun neighbors3 (x y z w)
  (let ((tot 0))
    (macrolet ((aux (i j k)
		 `(when (= w (world:getblock (+ x ,i) (+ y ,j) (+ z ,k)))
		   (incf tot))))
      (aux 1 0 0)
      (aux -1 0 0)
      (aux 0 1 0)
      (aux 0 0 1)
      (aux 0 0 -1))
    tot))

(defun clearblock3 (id other)
  (declare (type (unsigned-byte 8) id))
  (lambda (x y z)
    (let ((blockid (world:getblock x y z)))
      (when (= other blockid)
	(plain-setblock x y z id 0)))))

#+nil
#(1 2 3 4 5 7 12 13 ;14
  15 16 17 18 19 21 22 23 24 25 35 41 42 43 45 46 47 48 49
   54 56 57 58 61 61 73 73 78 82 84 86 87 88 89 91 95)

#+nil
'("lockedchest" "litpumpkin" "lightgem" "hellsand" "hellrock" "pumpkin"
 "jukebox" "clay" "snow" "oreRedstone" "oreRedstone" "furnace" "furnace"
 "workbench" "blockDiamond" "oreDiamond" "chest" "obsidian" "stoneMoss"
 "bookshelf" "tnt" "brick" "stoneSlab" "blockIron" "blockGold" "cloth"
 "musicBlock" "sandStone" "dispenser" "blockLapis" "oreLapis" "sponge" "leaves"
 "log" "oreCoal" "oreIron" "oreGold" "gravel" "sand" "bedrock" "wood"
 "stonebrick" "dirt" "grass" "stone")

(defun platt (x y z)
  (dobox ((x0 (1- x) (+ 2 x))
	  (z0 (1- z) (+ 2 z)))
	 (let ((block (world:getblock x0 y z0)))
	   (when (not (or (= block 2) (= block 5)
			  (= block 3)))
	     (return-from platt nil))))
  t)

(defun platt2 (x y z)
  (dobox ((x0 (1- x) (+ 2 x))
	  (z0 (1- z) (+ 2 z)))
	 (let ((block (world:getblock x0 y z0)))
	   (when (not (or (= block 5) (= block 4)))
	     (return-from platt2 nil))))
  t)

(defun meep (x y z)
  (when (platt x y z)
    (sandbox::plain-setblock x y z 5 0)))

(defun meep2 (x y z)
  (when (platt2 x y z)
    (sandbox::plain-setblock x y z 4 0)))

(defun huhuhuh (xoffset yoffset zoffset)
  (lambda (x y z)
    (if (> (1- (/ (expt (/ y 64.0) 2) 2.0))
	   (black-tie:simplex-noise-3d-single-float
	    (/ (floor (/ (+ xoffset x) 8.0)) 8.0)
	    (/ (floor (* (+ yoffset y) (/ 1.0 8.0))) 8.0)
	    (/ (floor (* (+ zoffset z) (/ 1.0 8.0))) 8.0)))
	(sandbox::plain-setblock x y z 0 0 15)
	(sandbox::plain-setblock x y z 1 0))))

(defstruct octave
  (x (random (ash 1 16)))
  (y (random (ash 1 16)))
  (z (random (ash 1 16)))
  xscale
  yscale
  zscale
  power)


(defun random-octave (x y z w)
  (make-octave :xscale (float (/ 1.0 x))
	       :yscale (float (/ 1.0 y))
	       :zscale (float (/ 1.0 z))
	       :power (float w)))

(defun octivate (x y z octave)
  (* (octave-power octave)
     (black-tie:simplex-noise-3d-single-float
      (* (+ (octave-x octave) x) (octave-xscale octave))
      (* (+ (octave-y octave) y) (octave-yscale octave))
      (* (+ (octave-z octave) z) (octave-zscale octave)))))

(defun huhuhuh2 (scale &rest octaves)
  (lambda (x y z)
    (let ((tot 0.0)
	  (tot2 0.0))
      (dolist (octave octaves)
	(incf tot (octivate x 0 z octave)))
      (dolist (octave octaves)
	(incf tot2 (octivate x y z octave)))
      (if (and (< (/ (- y 64) scale) tot)
;	       (> 0.8 (/ tot tot2))
	       )
	  (sandbox::plain-setblock x y z 1 0)
	  (sandbox::plain-setblock x y z 0 0 15)))))

(defun clearblock? (id)
  (declare (type fixnum id))
  (lambda (x y z)
    (let ((blockid (world:getblock x y z)))
      (when (= blockid id)
	(plain-setblock x y z 0 0)))))

(defun clearblock2 (id)
  (declare (type (unsigned-byte 8) id))
  (lambda (x y z)
    (let ((blockid (world:getblock x y z)))
      (unless (zerop blockid)
	(plain-setblock x y z id 0)))))

#+nil
(defun define-time ()
  (eval
   (defun fine-time ()
      (/ (%glfw::get-timer-value)
	 ,(/ (%glfw::get-timer-frequency) (float (expt 10 6)))))))

#+nil
(defun seeder ()
  (map nil
       (lambda (ent)
	 (let ((pos (sandbox::farticle-position (sandbox::entity-particle ent))))
	   (setf (sandbox::entity-fly? ent) nil
		 (sandbox::entity-gravity? ent) t)
	   (setf (aref pos 0) 64.0
		 (aref pos 1) 128.0
		 (aref pos 2) -64.0))) *ents*))

#+nil
(map nil (lambda (ent)
	   (unless (eq ent *ent*)
	     (setf (sandbox::entity-jump? ent) t)
	     (if (sandbox::entity-hips ent)
		 (incf (sandbox::entity-hips ent)
		       (- (random 1.0) 0.5))
		 (setf (sandbox::entity-hips ent) 1.0))
	     )
	   (sandbox::physentity ent)) *ents*)


#+nil
(progno
 (dotimes (x (length fuck::*ents*))
   (let ((aaah (aref fuck::*ents* x)))
     (unless (eq aaah fuck::*ent*)
       (gl:uniform-matrix-4fv
	pmv
	(cg-matrix:matrix* (camera-matrix-projection-view-player camera)
			   (compute-entity-aabb-matrix aaah partial))
	nil)
       (gl:call-list (getfnc :box))))))
