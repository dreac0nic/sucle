(in-package :glhelp)

(defmacro with-gl-list (&body body)
  (let ((list-sym (gensym)))
    `(let ((,list-sym (gl:gen-lists 1)))
       (unwind-protect
	    (progn (gl:new-list ,list-sym :compile)
		   ,@body)
	 (gl:end-list))
       ,list-sym)))

(export '(with-gl-list))