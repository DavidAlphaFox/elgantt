;;;  -*- lexical-binding: t; -*-

(require 'cl-lib)
(require 'color)
(require 'org)
(require 'org-ql)
(require 's)
(require 'dash)
(require 'ts)

(setq elgantt-cal-deadline-character "▲")
;;      "Character used for deadlines in the calendar.")

(setq elgantt-cal-active-timestamp-character "●")
;;      "Character used for active timestamps in the calendar")

(setq elgantt-cal-inactive-timestamp-character "i")
;;      "Character used for inactive timestamps in the calendar")

(setq elgantt-cal-scheduled-character "s")
;;"Character used for active timestamps in the calendar")

(defcustom elgantt:skip-files 'archive
  "Accepts the following values from `org-map-entries'):
`archive'    skip trees with the archive tag
`comment'    skip trees with the COMMENT keyword
`function' or Emacs Lisp form:
           will be used as value for org-agenda-skip-function, so
           whenever the function returns a position, FUNC will not be
           called for that entry and search will continue from the
           position returned")

(defcustom elgantt:header-type 'root
  "Define how to gather the headers"
  :options '(root hashtag category))

(setq elgantt:header-type 'root)
(setq elgantt:leap-year-month-line   "| January xxxx                  | February xxxx               | March xxxx                    | April xxxx                   | May xxxx                      | June xxxx                    | July xxxx                     | August xxxx                   | September xxxx               | October xxxx                  | November xxxx                | December xxxx                 ")
(setq elgantt:leap-year-date-line    "|1234567890123456789012345678901|12345678901234567890123456789|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901")
(setq elgantt:leap-year-blank-line   "|                               |                             |                               |                              |                               |                              |                               |                               |                              |                               |                              |                               ")
(setq elgantt:normal-year-month-line "| January xxxx                  | February xxxx              | March xxxx                    | April xxxx                   | May xxxx                      | June xxxx                    | July xxxx                     | August xxxx                   | September xxxx               | October xxxx                  | November xxxx                | December xxxx                 ")
(setq elgantt:normal-year-date-line  "|1234567890123456789012345678901|1234567890123456789012345678|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901|123456789012345678901234567890|1234567890123456789012345678901")
(setq elgantt:normal-year-blank-line "|                               |                            |                               |                              |                               |                              |                               |                               |                              |                               |                              |                               ")

(defface elgantt:horizontal-line-face
    '((t :background "white" :foreground "white" :height .1))
  "Horizontal line face"
  :group 'elgantt)

(face-spec-set 'elgantt:horizontal-line-face
	       '((t :background "white" :height .2 :width normal)))
(face-spec-set 'elgantt:vertical-line-face
	       '((t :background "white" :foreground "white" :height .1)))

(defface elgantt:vertical-line-face
    '((t :background "white" :foreground "white" :height .1))
  "Vertical line face"
  :group 'elgantt)

(face-spec-set 'elgantt:vertical-line-face
	       '((t :background "white" :foreground "white" :height .1)))

(face-spec-set 'elgantt:vertical-line-face '((t :background "white" :foreground "white" :width ultra-expanded :height .3)))

(setq elgantt:vertical-line-char "|")
(put-text-property 0 1 'face 'elgantt:vertical-line-face elgantt:vertical-line-char)

(setq elgantt:horizontal-bar " ")

;; This was more macro practice than anything...
(defmacro elgantt::add-vertical-line-props (lines)
  (let ((body (cl-loop for line in lines
		       collect `(setq ,line (s-replace "|" ,elgantt:vertical-line-char ,line)))))
    `(progn ,@body)))

(elgantt::add-vertical-line-props (elgantt:leap-year-month-line
				   elgantt:leap-year-date-line
				   elgantt:leap-year-blank-line
				   elgantt:normal-year-month-line
				   elgantt:normal-year-date-line
				   elgantt:normal-year-blank-line))

(defun elgantt::convert-date-string (date-string)
  (ts-format "%Y-%m-%d" (ts-parse-org date-string)))
(setq elgantt:header-type 'root)

(defun elgantt::parse-this-headline ()
  "Get all potentially relevant properties of a headline. 
  Returns a plist suitable for adding text properties. All property names
  are prefixed with `elg' to avoid collision with other properties. In addition,
  all properties returned be `org-element-at-point' are added to the property list."
  (let* ((category (cdr (assoc "CATEGORY" (org-entry-properties (point) "CATEGORY"))))
	 ;; For some reason, certain properties retrieved using `org-entry-properties' return
	 ;; the `category' of an entry if the value is nil. For example, if there is no timestamp
	 ;; in an entry, it will return the category. Thus, certain property values must be check
	 ;; against the entry's category to determine whether the value is nil. Since category
	 ;; is repeatedly used, it is stored first.

	 ;; Note: Many of these properties are irrelevant. This code needs to be cleaned;
	 ;; for now, it is sufficent that all the information about an entry will be stored
	 ;; as text properties preceded with `elg-'.
	 (prop-list (append
		     (list :elg-category category)
		     (list :elg-root
			   (save-excursion 
			     (while (org-up-heading-safe))
			     (cdar (org-entry-properties (point) "ITEM"))))
		     (list :elg-todo 
			   (cdr (car (org-entry-properties (point) "TODO"))))
		     (list :elg-file 
			   (cdr (car (org-entry-properties (point) "FILE"))))
		     (list :elg-headline
			   (cdar (org-entry-properties (point) "ITEM")))
		     (list :elg-timestamp
			   (when-let ((timestamp (cdar (org-entry-properties (point) "TIMESTAMP"))))
			     (cond ((string= timestamp
					     category)
				    nil)
				   ((s-match "--" timestamp)
				    nil)
				   (t
				    (elgantt::convert-date-string timestamp)))))
		     (list :elg-timestamp-ia
			   (when-let ((timestamp-ia (cdar (org-entry-properties (point) "TIMESTAMP_IA"))))
			     (cond ((string= timestamp-ia
					     category)
				    nil)
				   ((s-match "--" timestamp-ia)
				    nil)
				   (t
				    (elgantt::convert-date-string timestamp-ia)))))
		     (list :elg-timestamp-range
			   (when-let ((range (cadr (org-entry-properties (point) "TIMESTAMP"))))
			     (cond ((string= range category)
				    nil)
				   ((not (s-match "--" range))
				    nil)
				   (t
				    (let ((dates (s-split "--" range)))
				      (list (elgantt::convert-date-string (car dates))
					    (elgantt::convert-date-string (cadr dates))))))))
		     (list :elg-timestamp-ia-range
			   (when-let ((range (cadr (org-entry-properties (point) "TIMESTAMP_IA"))))
			     (cond ((string= range category)
				    nil)
				   ((not (s-match "--" range))
				    nil)
				   (t
				    (let ((dates (s-split "--" range)))
				      (list (elgantt::convert-date-string (car dates))
					    (elgantt::convert-date-string (cadr dates))))))))
		     (list :elg-deadline 
			   (when (cdr (car (org-entry-properties (point) "DEADLINE")))
			     (if (string= (cdr (car (org-entry-properties (point) "DEADLINE"))) category)
				 nil
			       (elgantt::convert-date-string (cdr (car (org-entry-properties (point) "DEADLINE")))))))
		     (list :elg-hashtag
		     	   (when-let* ((tag-string (cdar (org-entry-properties (point) "ALLTAGS")))
		     		       (hashtag (-first (lambda (tagstring) (s-starts-with-p "#" tagstring))
		     					(s-split ":" tag-string))))
		     	     (org-no-properties hashtag)))
		     (list :elg-scheduled
			   (when (cdr (car (org-entry-properties (point) "SCHEDULED")))
			     (if (string= (cdr (car (org-entry-properties (point) "SCHEDULED"))) category)
				 nil
			       (elgantt::convert-date-string (cdr (car (org-entry-properties (point) "SCHEDULED")))))))
		     (list :elg-alltags
			   (when-let ((tag-string (cdar (org-entry-properties (point) "ALLTAGS"))))
			     (mapcar #'org-no-properties (s-split ":" tag-string t))))
		     (list :elg-header
			   (pcase elgantt:header-type
			     ('root 
			      (save-excursion 
				(while (org-up-heading-safe))
				(cdar (org-entry-properties (point) "ITEM"))))
			     ('hashtag 
			      (when-let ((tag-string (cdar (org-entry-properties (point) "ALLTAGS"))))
				(substring 
				 (-first (lambda (tagstring) (s-starts-with-p "#" tagstring))
					 (s-split ":" tag-string))
				 1)))
			     ('category  category)
			     (_ (error "Invalid header type."))))
		     (list :elg-org-buffer
			   (current-buffer))
		     (list :elg-anchor
			   (org-entry-get (point) "ELGANTT-ANCHOR")))))
    (setq prop-list (append 
		     (cond ((plist-get prop-list :elg-deadline)
			    (list :elg-date (plist-get prop-list :elg-deadline)
				  :elg-type 'deadline
				  :elg-display-char (org-no-properties (elgantt::get-display-char 'deadline))))
			   ((plist-get prop-list :elg-timestamp)
			    (list :elg-date (plist-get prop-list :elg-timestamp)
				  :elg-type 'timestamp
				  :elg-display-char (org-no-properties (elgantt::get-display-char 'timestamp))))
			   ((plist-get prop-list :elg-timestamp-ia)
			    (list :elg-date (plist-get prop-list :elg-timestamp-ia)
				  :elg-type 'timestamp-ia
				  :elg-display-char (org-no-properties (elgantt::get-display-char 'timestamp-ia))))
			   ((plist-get prop-list :elg-scheduled)
			    (list :elg-date (plist-get prop-list :elg-scheduled)
				  :elg-type 'scheduled
				  :elg-display-char (org-no-properties (elgantt::get-display-char 'scheduled)))))
		     (list :elg-anchor-date
			   (when-let ((anchor-id (plist-get prop-list :elg-anchor))
				      (id-point (cdr (org-id-find anchor-id))))
			     (save-excursion 
			       (goto-char id-point)
			       (plist-get (elgantt::parse-this-headline) :elg-date))))
		     (cadr (org-element-at-point))
		     prop-list))
    (when (plist-get prop-list :elg-date)
      prop-list)))

(defun elgantt::get-years (&optional date-type)
  "Get the date range of all time values in all agenda files. 
Optional DATE-TYPE is any value (or list of values) accepted by `org-re-timestamp':
        all: all timestamps
     active: only active timestamps (<...>)
   inactive: only inactive timestamps ([...])
  scheduled: only scheduled timestamps
   deadline: only deadline timestamps
     closed: only closed time-stamps
If it is not provided, the default is ('active inactive deadline)."
  (save-excursion
    (let ((years '()))
      (--each (-list elgantt:agenda-files)
	(with-temp-buffer
	  (insert-file-contents it)
	  (goto-char (point-min))
	  (--each (or (-list date-type)
		      '(all))
	    (goto-char (point-min))
	    (while (re-search-forward (org-re-timestamp it) nil t)
	      (push (substring (car (s-split "-" (match-string 0))) 1) years)))))
      (delete-dups years)
      (sort
       (mapcar (lambda (it)
		 (string-to-number it))
 	       years)
       '<))))

(defcustom elgantt:agenda-files (org-agenda-files)
  "Source files. Default: `org-agenda-files'.")
(setq elgantt:agenda-files "~/.emacs.d/lisp/elgantt/TEST/sample.org")
;;(setq elgantt:agenda-files "~/Dropbox/DropsyncFiles/taskmaster.org")

(defcustom elgantt:header-column-offset 20
  "Width of the header column")

(defvar elgantt::deadline-warning-days org-deadline-warning-days
  "Warning days to show in calendar.")

(defvar elgantt::date-range (elgantt::get-years)
  "Range of years to be calendared. Default: `elgantt::get-years'")

(defun elgantt::get-display-char (type)
  "Get the character to insert."
  (pcase type
    ('deadline elgantt-cal-deadline-character)
    ('timestamp elgantt-cal-active-timestamp-character)
    ('timestamp-ia elgantt-cal-inactive-timestamp-character)
    ('scheduled elgantt-cal-scheduled-character)))

;; This should be re-written
(defun elgantt::convert-date-to-column-number (timestamp)
  "Accepts a date in the form of \"YYYY-MM-DD\""
  (let ((spaces 0)
	(date timestamp))
    (cl-subseq elgantt::date-range
	       0 (cl-position (string-to-number (substring date 0 4)) elgantt::date-range))
    ;; add the preceding years
    (dolist (year
	      (cl-subseq elgantt::date-range
			 0 (cl-position (string-to-number (substring date 0 4)) elgantt::date-range)))
      (if (elgantt::leap-year-p year)
	  (setq spaces (+ spaces 366 12))
	(setq spaces (+ spaces 365 12))))
    ;; add the current year
    (+ spaces (elgantt::convert-date-to-column-in-current-year date) elgantt:header-column-offset)))

(defun elgantt::convert-date-string-to-day-number-in-year (date)
  "accept a date in the format YYYY-MM-DD and return an int of #day of the year"
  (time-to-day-in-year (encode-time 0 0 0 (string-to-number (substring date 8 10))
				    (string-to-number (substring date 5 7))
				    (string-to-number (substring date 0 4)))))

(defun elgantt::convert-date-to-column-in-current-year (date)
  "accepts a date YYYY-MM-DD and returns the position on the horizontal calendar (int)
                       this works on leap years"
  (+ (elgantt::convert-date-string-to-day-number-in-year date)
     (- (string-to-number (substring date 5 7)) 1)))

(defsubst elgantt::get-days-in-year (year)
  "Return the number of days in YEAR." 
  (if (elgantt::leap-year-p year) 366 365))

(defsubst elgantt::leap-year-p (year)
  "Return t if YEAR is a leap year. Otherwise, nil."
  (= (% year 4) 0))

(defun elgantt::insert-entry (props)
  "PROPS is a plist which must include, at minimum, the following properties:
`elgantt-header', `elgantt-date', `elgantt-type',
`elgantt-label', `elgantt-start-or-end-or-range'"
  (elgantt::get-header-create (plist-get props :elg-header))
  (beginning-of-line)
  (forward-char (elgantt::convert-date-to-column-number (plist-get props :elg-date)))
  (delete-char 1)
  (let ((char (concat (elgantt::get-display-char (plist-get props :elg-type)))))
    (set-text-propertibpes 0 1 props char)
    (insert char)))

(defun elgantt::get-header-create (header)
  "Put point at HEADER, creating it if necessary."
  (goto-char (point-min))
  (let ((new-header (concat (s-truncate elgantt:header-column-offset header))))
    ;; Concat is necessary for reasosn I do not understand, but without it
    ;; the text properties are not set propertly. 
    (if (search-forward new-header nil t)
	(beginning-of-line)
      (put-text-property 0 (length new-header) 'elgantt-header header new-header)
      (elgantt::insert-new-header-line new-header)
      (beginning-of-line))))

(defun elgantt::insert-new-header-line (header)
  (goto-char (point-max))
  (insert "\n"
	  (substring 
	   (concat header (make-string elgantt:header-column-offset ? ))
	   0 elgantt:header-column-offset))
  (cl-loop for year in (elgantt::get-years)
     do (if (elgantt::leap-year-p year)
	    (insert elgantt:leap-year-blank-line)
	  (insert elgantt:normal-year-blank-line))))

(defun elgantt::draw-month-line ()
  (let ((calendar-line ""))
    (dolist (year (elgantt::get-years))
      (if (elgantt::leap-year-p year)
	  (setq calendar-line (concat calendar-line 
				      (replace-regexp-in-string "xxxx" (number-to-string year) 
								elgantt:leap-year-month-line)))
	(setq calendar-line (concat calendar-line
				    (replace-regexp-in-string "xxxx" (number-to-string year) 
							      elgantt:normal-year-month-line)))))
    (insert 
     (concat (make-string elgantt:header-column-offset ? ) calendar-line))))

(defun elgantt::draw-number-line ()
  (let ((number-line ""))
    (dolist (year (elgantt::get-years))
      (if (elgantt::leap-year-p year)
	  (setq number-line (concat number-line elgantt:leap-year-date-line))
	(setq number-line (concat number-line elgantt:normal-year-date-line))))
    (insert 
     (concat (make-string elgantt:header-column-offset ? ) number-line))))

(defun elgantt::draw-horizontal-line ()
  (let* ((length
	  (+ (cl-loop for year in elgantt::date-range
		sum (if (elgantt::leap-year-p year)
			(+ 366 12)
		      (+ 365 12)))
	     elgantt:header-column-offset))
	 (string (make-string length ? )))
    (put-text-property 0 length
		       'face
		       'elgantt:horizontal-line-face
		       string)
    (insert string)))

(defun elgantt:get-data ()
  (interactive)
  (-non-nil
   (org-map-entries #'elgantt::parse-this-headline
		    nil
		    (-list elgantt:agenda-files)
		    elgantt:skip-files)))

(defun elgantt:get-data-org-ql ()
  (interactive)
  (-non-nil
   (org-ql-select elgantt:agenda-files
       '(ts)
     :action #'elgantt::parse-this-headline)))

(defun elgnatt:set-vertical-bar-face ()
  (goto-char (point-min))
  (while (re-search-forward elgantt:vertical-line-char nil t)
    (put-text-property (match-beginning 0)
		       (match-end 0)
		       'face
		       'elgantt-vertical-line-face)))

(defun elgantt:get-date-at-point (&optional column)
  "Get the date at point in YYYY-MM-DD format."
  ;; I decided the easiest way to get it was from the
  ;; context of the buffer, rather than calculating it
  ;; based on the column. This is ugly and should be
  ;; cleaned. 
  (if (not (char-equal (char-after) ?|))
      (progn
	(when (not column)
	  (setq column (current-column)))
	(let ((current-point (point))
	      (date ""))
	  (save-excursion
	    (if (re-search-backward "|" nil t)
		(progn 
		  (setq date (number-to-string (- current-point (match-beginning 0))))
		  (with-no-warnings (goto-line 0))
		  (move-to-column column)
		  (if (re-search-backward "|" nil t)
		      (progn
			(re-search-forward "[[:alpha:]]+" nil t)
			(setq date (concat (match-string 0) " " date))
			(if (re-search-forward "[[:digit:]]+" nil t)
			    (progn
			      (setq date (concat date ", " (match-string 0)))
			      (let ((day (org-day-of-week (nth 3 (parse-time-string date))
							  (nth 4 (parse-time-string date))
							  (nth 5 (parse-time-string date))))
				    (text ""))
				(cond ((= day 0) (setq text "Monday, "))
				      ((= day 1) (setq text "Tuesday, "))
				      ((= day 2) (setq text "Wednesday, "))
				      ((= day 3) (setq text "Thursday, "))
				      ((= day 4) (setq text "Friday, "))
				      ((= day 5) (setq text "Saturday, "))
				      ((= day 6) (setq text "Sunday, ")))
				(setq date (concat text date))))
			  (setq date "")))
		    (setq date "")))
	      (setq date "")))
	  date))
    ""))

(defun elgantt--get-background-of-point (point)
  "give it a point in the buffer, and it returns the background color of it"
  (plist-get (get-text-property point 'face) :background))

(defun elgantt--change-brightness-of-background-at-point (point change)
  "if there is a background font lock color, this will change its brightness"
  (put-text-property point (1+ point) 'font-lock-face
		     `(:background ,(color-lighten-name
				     (plist-get (get-text-property point 'face) :background) change))))

(defun elgantt::set-gradient (header start-date end-date start-color end-color)
  "HEADER is a string, which will be automatically truncated as needed.
START-COLOR and END-COLOR are hex colors formatted as a string: \"#xxxxxx\".
START-DATE and END-DATE are strings: \"YYYY-MM-DD\""
  (goto-char (point-min))
  (let ((header (s-truncate elgantt:header-column-offset header)))
    (if (search-forward header nil t)
	(progn
	  (beginning-of-line)
	  (let* ((start-color `(,(string-to-number (substring start-color 1 3) 16)
				 ,(string-to-number (substring start-color 3 5) 16)
				 ,(string-to-number (substring start-color 5 7) 16)))
		 (end-color `(,(string-to-number (substring end-color 1 3) 16)
			       ,(string-to-number (substring end-color 3 5) 16)
			       ,(string-to-number (substring end-color 5 7) 16)))
		 (start-col (elgantt::convert-date-to-column-number start-date))
		 (end-col (elgantt::convert-date-to-column-number end-date))
		 (start (save-excursion (forward-char start-col) (point)))
		 (end (save-excursion (forward-char end-col) (point)))
		 (hex ""))
	    (beginning-of-line)
	    (dolist (color (color-gradient start-color end-color (1+ (- end start))))
	      (setq hex "")
	      (dolist (c color)
		(if (= (length (format "%x" c)) 1)
		    (setq hex (concat hex (format "0%x" c)))
		  (setq hex (concat hex (format "%x" c)))))
	      (setq hex (concat "#" hex ))
	      (put-text-property start (+ 1 start) 'font-lock-face `(:background ,hex))
	      (setq start (+ 1 start)))))
      (error "Error in elgantt:change-gradient. Header not found."))))

(defun elgantt:get-prop-at-point (&optional property)
  "Get the text PROPERTY at point, if specified. 
Otherwise, get a plist of all properties."
  (let ((properties (text-properties-at (point))))
    (if property
	(plist-get properties property)
      properties)))

(defun elgantt:navigate-to-org-file ()
  "this will navigate to a location in an org file when
supplied with the file name (string) and point (number)"
  (interactive)
  (if-let ((buffer (elgantt:get-prop-at-point :elg-org-buffer))
	   (marker (elgantt:get-prop-at-point :begin)))
      (progn 
	(switch-to-buffer-other-window buffer)
	(goto-char marker)
	(outline-show-children)
	(outline-show-entry)
	(beginning-of-line))
    (message "Cannot navigate to org file: no data at point.")))

(defmacro elgantt:with-point-at-orig-entry (&rest body)
  "Execute BODY with point at location given by the `:begin' property.
Buffer is determined from the `:org-buffer' property." 
  (declare (indent 2))
  `(let ((marker (get-text-property (point) :begin))
	 (buffer (get-text-property (point) :elg-org-buffer)))
     (with-current-buffer buffer
       (save-excursion
	 (goto-char marker)
	 ,@body))))

(defun elgantt::on-vertical-line ()
  (string= "|"
	   (buffer-substring (point) (1+ (point)))))

(defun elgantt::move-horizontally (n)
  (forward-char n)
  (when (elgantt::on-vertical-line)
    (if (< n 0)
	(backward-char)
      (forward-char))))

(defun elgantt::shift-date (n)
  "Move the timestamp up or down by one day.
N should be 1 or -1."
  (unless (or (= n 1)
	      (= n -1))
    (error "elgantt::shift-date: Invalid argument. N must be 1 or -1."))
  (elgantt:with-point-at-orig-entry
      (when (re-search-forward (org-re-timestamp 'all))
	(org-timestamp-change n 'day)))
  (elgantt:update-this-cell)
  (pcase n
    (1  (elgantt::move-horizontally 1)
	(elgantt:update-this-cell))
    (-1 (elgantt::move-horizontally -1)
	(elgantt:update-this-cell))))

(defun elgantt:update-this-cell* ()
  "Gets data for a specific cell by looking for any headings
which occur on on the operative DATE which also contain
the same CATEGORY, HASHTAG, or ROOT."
  (when-let* ((date (elgantt:get-date-at-point))
	      (type (pcase elgantt:header-type
		      ('root 'ancestors)
		      ('category 'category)
		      ('hashtag 'tags-inherited)))
	      (header (elgantt:get-header-at-point))
	      (item (pcase type
		      ('category header)
		      ('hashtag header)
		      ('ancestors `(regexp ,header)))))
    (org-ql-select elgantt:agenda-files
	`(and (ts :on ,date)
	  (,type ,item))
      :action #'elgantt::parse-this-headline)))

(defun elgantt:update-this-cell ()
  "Gets data for a specific cell by looking for any headings
which occur on the operative date."
  (when (elgantt::on-vertical-line)
    (user-error "Error in elgantt:update-this-cell: Not on a calendar cell."))
  (save-excursion 
    (delete-char 1)
    (insert " ")
    (backward-char)
    (when-let* ((date (elgantt:get-date-at-point))
		(type (pcase elgantt:header-type
			('root 'ancestors)
			('category 'category)
			('hashtag 'tags-inherited)))
		(header (elgantt:get-header-at-point))
		(item (pcase type
			('category header)
			('hashtag header)
			('ancestors `(regexp ,header)))))
      (mapc #'elgantt::insert-entry
	    (-non-nil
	     ;;-non-nil is necessary because elgantt::parse-this-headline
	     ;;returns nil if the entry does not match
	     (org-ql-select elgantt:agenda-files
		 `(and (ts :on ,date)
		   (,type ,item))
	       :action #'(elgantt::parse-this-headline)))))))

;; NOTE: Why not combine the parsing and inserting functions? 
(defun elgantt::run-org-ql-for-date-at-point ()
  (interactive)
  (when-let* ((date (elgantt:get-date-at-point))
	      (type (pcase elgantt:header-type
		      ('root 'ancestors)
		      ('category 'category)
		      ('hashtag 'tags-inherited)))
	      (header (elgantt:get-header-at-point))
	      (item (pcase type
		      ('category header)
		      ('hashtag header)
		      ('ancestors `(regexp ,header)))))
    ;;-non-nil is necessary because elgantt::parse-this-headline
    ;;returns nil if the entry does not match
    (org-ql-select elgantt:agenda-files
	`(and (ts :on ,date)
	  (,type ,item))
      :action #'(elgantt::parse-this-headline))))

(defun elgantt:get-header-at-point ()
  (save-excursion
    (beginning-of-line)
    (get-text-property (point) 'elgantt-header)))

(defsubst elgantt::shift-date-forward ()
  (interactive)
  (elgantt::shift-date 1))

(defsubst elgantt::shift-date-backward ()
  (interactive)
  (elgantt::shift-date -1))

(defun elgantt::open-org-agenda-at-date ()
  (interactive)
  (let* ((date (elgantt:get-date-at-point))
	 (date `(,(nth 4 (parse-time-string date))
		  ,(nth 3 (parse-time-string date))
		  ,(nth 5 (parse-time-string date)))))
    (org-agenda-list nil (calendar-absolute-from-gregorian date) 'day))
  (other-window 1))

(define-derived-mode elgantt1-mode special-mode "El Gantt"
		     (define-key elgantt1-mode-map (kbd "r") 'elgantt-open)
		     (define-key elgantt1-mode-map (kbd "SPC") #'elgantt:navigate-to-org-file)
		     (define-key elgantt1-mode-map (kbd "f")   'elgantt::move-selection-bar-forward)
		     (define-key elgantt1-mode-map (kbd "b")   'elgantt::move-selection-bar-backward)
		     (define-key elgantt1-mode-map (kbd "RET") #'elgantt::open-org-agenda-at-date)
		     (define-key elgantt1-mode-map (kbd "M-f") #'elgantt::shift-date-forward)
		     (define-key elgantt1-mode-map (kbd "M-b") #'elgantt::shift-date-backward))


(defun elgantt::vertical-highlight (&optional column)
  "insert a vertical highlight bar at column, and remove the previous vertical bar"
  (interactive)
  (let ((inhibit-read-only t))
    (dolist (p elgantt--old-backgrounds)
      (when (cadr p)
	(put-text-property (car p) (1+ (car p)) 'font-lock-face `(:background ,(cadr p))))))
  (save-excursion
    (goto-char (point-min))
    (let ((x 1)
	  (inhibit-read-only t))
      (while (< x (elgantt--count-lines-in-buffer))
	(move-beginning-of-line 1)
	(forward-char (or column
			  (+ (current-column) elgantt--hidden-past-columns)))
	(add-to-list 'elgantt--old-backgrounds `(,(point) ,(plist-get (get-text-property (point) 'font-lock-face) :background)))
	(elgantt--change-brightness-of-background-at-point (point) -35)
	(forward-line)
	(setq x (1+ x))))))

;; (defun elgantt::move-selection-bar-forward ()
;;   (interactive)
;;   (when (<= (current-column) elgantt:header-column-offset)
;;     (forward-char elgantt:header-column-offset))
;;   (forward-char)
;;   (goto-char (1- (re-search-forward "[^| ]" (save-excursion (end-of-line) (point)) t)))
;;   (elgantt::vertical-highlight (current-column)))

;; (defun elgantt::move-selection-bar-backward ()
;;   (interactive)
;;   (goto-char (re-search-backward "[^| ]" nil t))
;;   (when (< (current-column) elgantt:header-column-offset)
;;     (move-beginning-of-line nil)
;;     (forward-char elgantt:header-column-offset))                               
;;   (elgantt--vertical-highlight (current-column)))


(defun elgantt::show-echo-message ()
  (interactive)
  (unless (elgantt::on-vertical-line)
    (message "%s -- %s -- %s!!"
	     (elgantt:get-date-at-point)
	     (elgantt:get-header-at-point)
	     (elgantt:get-prop-at-point :elg-headline))))



(defun elgantt::populate-cells ()
  "Insert data from agenda files into buffer." 
  ;; Org-ql is much faster, but there are buffer issues if calling
  ;; `elgantt::insert-entry' from the parsing function
  ;; and I suspect the buffer-switching overhead is more
  ;; than storing the plist.
  (mapc #'elgantt::insert-entry
	(-non-nil
	 (org-ql-select elgantt:agenda-files
	     '(ts)
	   :action #'elgantt::parse-this-headline))))
  ;; (mapc #'elgantt::insert-entry
  ;; 	(-non-nil
  ;; 	 (org-map-entries #'elgantt::parse-this-headline
  ;; 			  nil
  ;; 			  (-list elgantt:agenda-files)
  ;; 			  'archive))))

(defun elgantt:open ()
  (switch-to-buffer "*El Gantt Calendar*")
  (setq elgantt::date-range (elgantt::get-years))
  (erase-buffer)
  (elgantt::draw-month-line)
  (insert "\n")
  (elgantt::draw-number-line)
  ;;(insert "\n")
  ;;  (elgantt::draw-horizontal-line)
  (elgantt::populate-cells)
  ;;(elgantt1-mode)
  (toggle-truncate-lines 1)
  (horizontal-scroll-bar-mode 1)
  (goto-char (point-min))
  ;;  (forward-char (elgantt::convert-date-to-column-number (format-time-string "%Y-%m-%d")))
  ;;(add-hook 'post-command-hook 'elgantt::show-echo-message nil t)
  ;;(add-hook 'post-command-hook 'elgantt::vertical-highlight nil t)
  (delete-other-windows))

(defun elgantt:create-anchor ()
  "Prompt user for the anchor heading. Add an `org-id' to the 
anchor heading if necessary. Add the property `ELGANTT-ANCHOR'
to the current heading, which is the `org-id' of the anchor."
  (let ((anchors (cdar (org-entry-properties (point) "ELGANTT-ANCHOR")))
	(anchor-heading-id (save-excursion (org-goto)
					   (org-id-get-create))))
    (org-set-property "ELGANTT-ANCHOR" (concat
					anchors " "
					anchor-heading-id))))

(defun elgantt:get-anchors ()
  "Return a list of anchors"
  (when-let ((anchors (cdar (org-entry-properties (point) "ELGANTT-ANCHOR"))))
    (s-split " " 
	     anchors)))

(defun elgantt::move-date-and-anchor (&optional backward)
  "Move the current date and all anchored dates forward by one days
If called with an argument, move backward."
  (if backward
      (elgantt::shift-date-backward)
    (elgantt::shift-date-forward))
  (when-let ((anchor-date (elgantt:get-prop-at-point :elg-anchor-date)))
    (save-excursion
      (beginning-of-line)
      (forward-char (elgantt::convert-date-to-column-number anchor-date))
      (if backward
	  (elgantt::move-date-and-anchor 'backward)
	(elgantt::move-date-and-anchor)))))

(defun elgantt:date-calculator (date offset)
  "DATE is a string \"YYYY-MM-DD\"
OFFSET is a positive or negative integer representing
the number of days."
  (ts-format "%Y-%m-%d" (ts-adjust 'day offset (ts-parse date))))


(defun elgantt:colorize ()
  (goto-char (point-min))
  

