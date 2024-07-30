;;; leetcode-render.el --- UI for leetcode.              -*- lexical-binding: t; -*-

;; Copyright (C) 2024  Qiqi Jin

;; Author: Qiqi Jin <ginqi7@gmail.com>
;; Keywords:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation, either version 3 of the License, or
;; (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program.  If not, see <https://www.gnu.org/licenses/>.

;;; Commentary:

;;

;;; Commands:
;;
;; Below are complete command list:
;;
;;  `leetcode-render-query-next-page'
;;    Leetcode Render Query Next Page.
;;  `leetcode-render-query'
;;    Leetcode Render Query.
;;  `leetcode-problem-list-mode'
;;    Major mode for tabulated leetcode problem list.
;;
;;; Customizable Options:
;;
;; Below are customizable option list:
;;

;;; Code:

(require 'eieio)
(require 'subr-x)
(require 'leetcode-object)

(defvar leetcode-render--propertize-alist
  `(("AC" . ,(propertize "✓" 'face 'success 'hover "AC"))
    ("FAILED" . ,(propertize "✗" 'face 'error))
    ("NOT_STARTED" . "")
    ("TRIED" . ,(propertize "✍" 'face 'warning))
    ("EASY" . ,(propertize "Easy" 'face 'success))
    ("MEDIUM" . ,(propertize "Medium" 'face 'warning))
    ("HARD" . ,(propertize "Hard" 'face 'error))
    ("difficulty" . "Difficulty")
    ("listId" . "List ID")
    ("status" . "Status")
    ("tags" . "Tags")
    ("searchKeywords" . "Keywords")
    ("total" . "Total")
    ("num" . "Page Num")
    ("hasMore" . "Has More")
    ("skip" . "Skip")
    ("limit" . "Limit")
    ("accepted" . ,(propertize "Accepted" 'face 'success))
    ("failed" . ,(propertize "Failed" 'face 'error))
    ("untouched" . ,(propertize "Untouched" 'face 'warning))
    ("allSubNum" . "Submission Num")
    ("acSubNum" . "Accepted Num")
    ("acRate" . "Accepted Rate"))
  "An alist to define how to propertize text."
  )

(defvar leetcode-render--keymap-list
  '(("Next Column" "l" tabulated-list-next-column)
    ("Previous Column" "h" tabulated-list-previous-column)
    ("next Line" "j" next-line)
    ("Previous Line" "k" previous-line)
    ("Query" "q" leetcode-render-query)
    ("Solve" "RET" (lambda () (interactive)
		     (leetcode--show
		      (leetcode-render--tabulated-entry-to-problem
		       (tabulated-list-get-id)
		       (tabulated-list-get-entry))))))
  "A list about keywords in questions page."
  )

(defvar leetcode-render--title-alist
  '(("Status" . status)
   ("Id" . frontendQuestionId)
   ("Title" . title)
   ("Acceptance" . acRate)
   ("Difficulty" . difficulty))
  "An alist to define problems title."
  )

(defvar leetcode-render--submission-status-buffer-name "*LeetCode Submission Status*"
  "Submission status buffer name.")

(defvar leetcode-render--problem-description-buffer-name "*LeetCode Problem Description*"
  "Problem description buffer name.")

(defvar leetcode-render--problems-page-buffer-name "*LeetCode Problems Page*"
  "Problems page buffer name.")

(defvar leetcode-render--button-alist nil
  "An alist to store the buttons in problems page.")

(defun leetcode-render--tabulated-entry-to-problem (identity-value entry)
"Convert Tabulated Entry To Problem.
IDENTITY-VALUE: tabulated-entry id.
ENTRY: tabulated-entry."
  (let ((problem (make-instance 'leetcode-problem))
	(property)
	(value))
    (eieio-oset problem 'titleSlug identity-value)
    (dotimes (index (length leetcode-render--title-alist))
      (setq property (cdr (nth index leetcode-render--title-alist)))
      (setq value (aref entry index))
      (eieio-oset problem property value))
    (eieio-oset problem 'frontendQuestionId (number-to-string (string-to-number (eieio-oref problem 'frontendQuestionId))))
    problem
    ))

(defun leetcode-render--text-in-right-window (buffer-name text)
"Render Text In Right Window.
BUFFER-NAME: render text in this buffer.
TEXT: text needed to render."
  (delete-other-windows)
  (split-window-right)
  (other-window 1)
  (with-current-buffer (get-buffer-create buffer-name)
    (erase-buffer)
    (insert text)
    (switch-to-buffer (current-buffer)))
  (other-window 1))

(defun leetcode-render--submission-status (submission-status-ins)
"Leetcode Render Submission Status.
SUBMISSION-STATUS-INS: an object instance."
  (leetcode-render--text-in-right-window
   leetcode-render--submission-status-buffer-name
   (leetcode-render--box-string
    (leetcode-render--align-string
     (leetcode-render--obj-to-string submission-status-ins)
     ":")
    2)))

(defun leetcode-render-query-next-page ()
  "Leetcode Render Query Next Page."
  (interactive)
  (let* ((button-str
	  (alist-get "Next page" leetcode-render--button-alist))
	 (callback (get-text-property 0 'action button-str))
	 (data (get-text-property 0 'button-data button-str)))
    (funcall callback data)))

(defun leetcode-render-query (&optional name)
"Leetcode Render Query.
NAME: name about query condition."
  (interactive)
  (unless name
    (setq name (completing-read "Select a query type: " leetcode-render--button-alist)))
  (let* ((button-str
	  (alist-get name leetcode-render--button-alist nil nil #'equal))
	 (callback (get-text-property 0 'action button-str))
	 (data (get-text-property 0 'button-data button-str)))
    (funcall callback data)))

(defun leetcode-problem-list--to-tabulated-list (leetcode-problem-list-ins id-property title-alist)
"Leetcode Problem List To Tabulated List.
LEETCODE-PROBLEM-LIST-INS: an object about problem list.
ID-PROPERTY: the property to identify object.
TITLE-ALIST: title alist."
  (leetcode-problem-list-mode)
  (setq tabulated-list-entries
	(leetcode-problem-list--to-tabulated-entries leetcode-problem-list-ins
						     id-property
						     (mapcar #'cdr title-alist)))
  ;; title
  (setq tabulated-list-format
	(leetcode-render--build-tabulated-list-format
	 (mapcar #'car title-alist)
	 tabulated-list-entries))
  (tabulated-list-init-header)
  (tabulated-list-print t t))

(defun leetcode-render--tabulated-entries-max-length (title index entries)
"Compute Tabulated Entries Max Length of the nth column.
TITLE: the column title.
INDEX: the column index.
ENTRIES: the all entries."
  (let ((all-entries-length
	 (mapcar
	  (lambda (entry)
	    (length (aref (nth 1 entry) index)))
	  entries)))
    (unless all-entries-length (setq all-entries-length '(0)))
    (max (length title) (seq-max all-entries-length))))

(defun leetcode-render--build-tabulated-list-format (titles entries)
"Build Tabulated List Format.
TITLES: all column titles.
ENTRIES: all tabulated entries."
  (let ((index -1)
	(len (length titles)))
    (vconcat
     (mapcar
      (lambda (title)
	(setq index (1+ index))
	(list title
	      (leetcode-render--tabulated-entries-max-length title index entries)
	      t
	      :right-align (eq (1+ index) len)))
      titles))))

(define-derived-mode leetcode-problem-list-mode  tabulated-list-mode "leetcode-problem-list-mode"
  "Major mode for tabulated leetcode problem list."
  (dolist (keymap-info leetcode-render--keymap-list)
    (keymap-set leetcode-problem-list-mode-map
		(nth 1 keymap-info)
		(nth 2 keymap-info))))

(defun leetcode-problem-list--to-tabulated-entries (problem-list-ins id-property properties)
  "Convert \='leetcode-problem-list instance to tabulated-entries.
PROBLEM-LIST-INS: \='leetcode-problem-list instance.
ID-PROPERTY: the property to indentify object.
PROPERTIES: all properties needed to convert."
  (mapcar
   (lambda (problem)
     (leetcode-render--problem-ins-to-tabulated-entry problem id-property properties))
   (leetcode--oref-with-default problem-list-ins 'problems)))

(defun leetcode-render--format (value)
"Leetcode Render Format.
VALUE: some Lisp value."
  (when (stringp value)
    (setq value (string-replace "\n" "\\n" value)))
  (cond
   ((class-p value)
    (propertize (symbol-name value) 'face 'bold-italic))
   ((eq (type-of value) 'float)
    (format "%.2f%%" (if (< value 1) (* 100 value) value)))
   ((eq (type-of value) 'integer)
    (format "%04d" value))
   ((and (eq (type-of value) 'string) (leetcode--digit-str-p value))
    (format "%04d" (string-to-number value)))
   ((and
     (eq (type-of value) 'string)
     (leetcode-render--button-p value))
    value)
   ((eq (type-of value) 'string)
    (alist-get value leetcode-render--propertize-alist value nil #'string=))
   (t value)))

(defun leetcode-render--problem-ins-to-tabulated-entry (problem-ins id-property properties)
  "Convert problem-ins instance to tabulated-entry.
PROBLEM-INS: an instance about \='leetcode-problem.
ID-PROPERTY: the property to identify the object.
PROPERTIES: all properties needed to convert."
  (list
   (leetcode--oref-with-default problem-ins id-property)
   (vconcat
    (mapcar
     (lambda (property)
       (leetcode-render--format
	(leetcode--oref-with-default problem-ins property)))
     properties))))

(defun leetcode-render--embed (content &optional margin)
  "Embed CONTENT to current buffer.
MARGIN: the rigion between content to exsits text in current buffer."
  (let ((max-line-width 0))
    (setq buffer-read-only nil)
    (unless margin (setq margin 4))
    (goto-char (point-min))
    (setq max-line-width
	  (- (line-end-position 1) (line-beginning-position 1)))
    (dolist (line (split-string content "\n"))
      (end-of-line 1)
      (when (eobp) (insert (make-string max-line-width ? )))
      (insert (concat (make-string margin ? ) line))
      (when (eobp) (insert "\n"))
      (forward-line 1)

      )
    (setq buffer-read-only t)
    (goto-char (point-min))))

(defun leetcode-render--obj-to-string (obj)
  "Covert a object to string.
OBJ: an object instance."
  (concat
   (leetcode-render--format (eieio-object-class obj))
   "\n\n"
   (string-join
    (mapcar
     (lambda (property)
       (format "%s: %s"
	       (leetcode-render--format (symbol-name property))
	       (leetcode-render--format
		(leetcode--hashtable-to-string
		 (leetcode--oref-with-default obj property)))))
     (leetcode-object-class-properties (eieio-object-class obj)))
    "\n")))

(defun leetcode--hashtable-to-string (hashtable)
"Leetcode  Hashtable To String.
HASHTABLE: the hashtable needed to convert."
  (if (hash-table-p hashtable)
      (progn
	(string-join
	 (mapcar
	  (lambda (key)
	    (format "%s: %s"
		    (leetcode-render--format key)
		    (leetcode-render--format (gethash key hashtable))))
	  (hash-table-keys hashtable))
	 " "))
    hashtable))

(defun leetcode-render--keymap-info ()
  "Leetcode Render Keymap Info."
  (leetcode-render--box-string
   (leetcode-render--align-string
    (concat
     (propertize "leetcode-keymaps" 'face 'bold-italic)
     "\n\n"
     (string-join
      (mapcar
       (lambda (keymap-info)
	 (format "%s: %s" (nth 0 keymap-info) (nth 1 keymap-info)))
       leetcode-render--keymap-list)
      "\n"))
    ":")
   2))

(defun leetcode--buttonize (key text func data)
"Leetcode wrapped Buttonize.
KEY: the key for saving alist: key -> button
TEXT: button string.
FUNC: button callback function.
DATA: the data for callback function input."
  (let ((button-str (buttonize text func data)))
    (setq leetcode-render--button-alist
	  (append leetcode-render--button-alist
		  (list (cons key button-str))))
    button-str))

(defun leetcode-render--page-info (leetcode-page-info-ins leetcode-query-info-ins)
"Leetcode Render Page Info.
LEETCODE-PAGE-INFO-INS: leetcode-page-info instance.
LEETCODE-QUERY-INFO-INS: leetcode-query-info instance."
  (concat
   (leetcode-render--box-string
    (leetcode-render--align-string
     (leetcode-render--obj-to-string leetcode-page-info-ins)
     ":")
    2)

   (leetcode--buttonize "Previous" "Previous Page"
			(lambda (data)
			  (leetcode--query-previous-page
			   (car data)
			   (cdr data)))
			(cons leetcode-page-info-ins leetcode-query-info-ins))
   " <--> "
   (leetcode--buttonize "Next" "Next Page"
			(lambda (data)
			  (leetcode--query-next-page
			   (car data)
			   (cdr data)))
			(cons leetcode-page-info-ins leetcode-query-info-ins))
   "\n"))

(defun leetcode-render--session-progress (session-progress-ins)
"Leetcode Render  Session Progress.
SESSION-PROGRESS-INS: leetcode-session-progress instance."
  (leetcode-render--box-string
   (leetcode-render--align-string
    (leetcode-render--obj-to-string session-progress-ins)
    ":")
   2))

(defun leetcode--digit-str-p (str)
"Check if STR is a digit."
  (string-match "^[0-9]+$" str))

(defun leetcode-render--page (problem-list-ins query-info-ins session-progress-ins)
"Leetcode Render Page.
PROBLEM-LIST-INS: a \='leetcode-problem-list instance.
QUERY-INFO-INS: a \='leetcode-query-info instance.
SESSION-PROGRESS-INS: a \='leetcode-session-progress instance."
  (setq leetcode-render--button-alist nil)
  (with-current-buffer (get-buffer-create "*LeetCode Problems Page*")

    (leetcode-problem-list--to-tabulated-list problem-list-ins
					      'titleSlug
					      leetcode-render--title-alist)

    (leetcode-render--embed
     (concat
      (leetcode-render--page-info
       (leetcode--oref-with-default problem-list-ins 'page-info)
       query-info-ins)
      (leetcode-render--query-info query-info-ins)
      (leetcode-render--session-progress session-progress-ins)
      (leetcode-render--keymap-info)))

    (switch-to-buffer (buffer-name))))

(defun leetcode-render--button-p (str)
"Check if the STR is a button."
  (with-temp-buffer (insert str) (button-at (point-min))))

(defun leetcode-render--query-info (leetcode-query-info-ins)
"Leetcode Render Query Info.
LEETCODE-QUERY-INFO-INS: a \='leetcode-query-info instance."
  (let ((new-copy (leetcode-object-copy leetcode-query-info-ins)))
    (dolist (property
	     (leetcode-object-class-properties (eieio-object-class new-copy)))
      (eieio-oset new-copy property
		  (leetcode--buttonize
		   (symbol-name property)
		   (format "%s"
			   (leetcode--oref-with-default new-copy property "nil"))
		   (lambda (data)
		     (funcall
		      (intern
		       (format "leetcode--query-by-%s" (car data)))
		      (cdr data)))
		   (cons property leetcode-query-info-ins))))
    (leetcode-render--box-string
     (leetcode-render--align-string
      (leetcode-render--obj-to-string new-copy)
      ":")
     2)))

(defun leetcode-render--box-string (str &optional margin)
  "Add box for STR.
MARGIN: the margion between str to the box."
  (let* ((lines (split-string str "\n"))
	 (max-length (seq-max (mapcar #'length lines))))
    (unless margin (setq margin 0))
    (with-temp-buffer
      (insert
       (format "+%s+\n"
	       (make-string (+ margin margin max-length) ?-)))
      (dolist (line lines)
	(insert
	 (format "|%s%s%s|\n"
		 (make-string margin ? )
		 line
		 (make-string
		  (+ margin (- max-length (length line)))
		  ? ))))
      (insert
       (format "+%s+\n"
	       (make-string (+ margin margin max-length) ?-)))
      (buffer-string))))

(defun leetcode-render--align-string (str &optional separator)
  "Align STR by SEPARATOR."
  (let* ((lines (split-string str "\n"))
	 (max-position
	  (seq-max
	   (mapcar
	    (lambda (line) (or (string-search separator line) 0))
	    lines)))
	 (fill-spaces
	  (mapcar
	   (lambda (line)
	     (cons
	      (string-search separator line)
	      (- max-position
		 (or (string-search separator line) max-position))))
	   lines)))
    (with-temp-buffer
      (insert str)
      (goto-char (point-min))
      (dolist (fill-space fill-spaces)
	(beginning-of-line 1)
	(when (car fill-space)
	  (forward-char (car fill-space))
	  (insert (make-string (cdr fill-space) ? )))
	(forward-line 1))
      (buffer-string))))

(defun leetcode-render-question-content (html-content)
"Leetcode Render Question Content.
HTML-CONTENT: the html content about question."
  (leetcode-render--text-in-right-window
   leetcode-render--problem-description-buffer-name
   (with-temp-buffer
     (shr-insert-document
       (with-temp-buffer
	 (insert html-content)
	 (libxml-parse-html-region (point-min) (point-max))))
     (buffer-string))))

(provide 'leetcode-render)
;;; leetcode-render.el ends here

