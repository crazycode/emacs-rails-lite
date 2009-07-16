;;; rails-lib.el ---

;; Copyright (C) 2006 Dmitry Galinsky <dima dot exe at gmail dot com>

;; Authors: Dmitry Galinsky <dima dot exe at gmail dot com>,
;;          Rezikov Peter <crazypit13 (at) gmail.com>
;;          Howard Yeh <hayeah at gmail dot com>

;; Keywords: ruby rails languages oop
;; $URL$
;; $Id$

;;; License

;; This program is free software; you can redistribute it and/or
;; modify it under the terms of the GNU General Public License
;; as published by the Free Software Foundation; either version 2
;; of the License, or (at your option) any later version.

;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.

;; You should have received a copy of the GNU General Public License
;; along with this program; if not, write to the Free Software
;; Foundation, Inc., 59 Temple Place - Suite 330, Boston, MA  02111-1307, USA.

;;; Code:

(defun rails-lib:run-primary-switch ()
  "Run the primary switch function."
  (interactive)
  (if rails-primary-switch-func
      (apply rails-primary-switch-func nil)))

(defun rails-lib:run-secondary-switch ()
  "Run the secondary switch function."
  (interactive)
  (if rails-secondary-switch-func
      (apply rails-secondary-switch-func nil)))

;;;;; Non Rails realted helper functions ;;;;;

;; Syntax macro

(defmacro* when-bind ((var expr) &rest body)
  "Binds VAR to the result of EXPR.
If EXPR is not nil exeutes BODY.

 (when-bind (var (func foo))
  (do-somth (with var)))."
  `(let ((,var ,expr))
     (when ,var
       ,@body)))

;; Lists

(defun list->alist (list)
  "Convert ((a . b) c d) to ((a . b) (c . c) (d . d))."
  (mapcar
   #'(lambda (el)
       (if (listp el) el(cons el el)))
   list))

(defun uniq-list (list)
  "Return a list of unique elements."
  (let ((result '()))
    (dolist (elem list)
      (when (not (member elem result))
        (push elem result)))
    (nreverse result)))

;; Strings

(defun string-repeat (char num)
  (let ((len num)
        (str ""))
  (while (not (zerop len))
    (setq len (- len 1))
    (setq str (concat char str)))
  str))


(defmacro string=~ (regex string &rest body)
  "regex matching similar to the =~ operator found in other languages."
  (let ((str (gensym)))
    `(lexical-let ((,str ,string))
       ;; Use lexical-let to make closures (in flet).
       (when (string-match ,regex ,str)
         (symbol-macrolet ,(loop for i to 9 collect
                                 (let ((sym (intern (concat "$" (number-to-string i)))))
                                   `(,sym (match-string ,i ,str))))
           (flet (($ (i) (match-string i ,str))
                  (sub (replacement &optional (i 0) &key fixedcase literal-string)
                       (replace-match replacement fixedcase literal-string ,str i)))
             (symbol-macrolet ( ;;before
                               ($b (substring ,str 0 (match-beginning 0)))
                               ;;match
                               ($m (match-string 0 ,str))
                               ;;after
                               ($a (substring ,str (match-end 0) (length ,str))))
               ,@body)))))))

(defun decamelize (string)
  "Convert from CamelCaseString to camel_case_string."
  (let ((case-fold-search nil))
    (downcase
     (replace-regexp-in-string
      "\\([A-Z]+\\)\\([A-Z][a-z]\\)" "\\1_\\2"
      (replace-regexp-in-string
       "\\([a-z0-9]\\)\\([A-Z]\\)" "\\1_\\2"
       string)))))

(defun string-not-empty (str) ;(+)
  "Return t if string STR is not empty."
  (and (stringp str) (not (or (string-equal "" str)
                              (string-match "^ +$" str)))))

(defun yml-value (name)
  "Return the value of the parameter named NAME in the current
buffer or an empty string."
  (save-excursion
    (goto-char (point-min))
    (if (search-forward-regexp (format "%s:[ ]*\\(.*\\)[ ]*$" name) nil t)
        (match-string 1)
      "")))

(defun current-line-string ()
  "Return the string value of the current line."
  (buffer-substring-no-properties
   (progn (beginning-of-line) (point))
   (progn (end-of-line) (point))))

(defun remove-prefix (word prefix)
  "Remove the PREFIX string in WORD if it exists.
PrefixBla -> Bla."
  (replace-regexp-in-string (format "^%s" prefix) "" word))

(defun remove-postfix (word postfix)
  "Remove the POSTFIX string in WORD if it exists.
BlaPostfix -> Bla."
  (replace-regexp-in-string (format "%s$" postfix) "" word))

(defun strings-join (separator strings)
  "Join all STRINGS using a SEPARATOR."
  (mapconcat 'identity strings separator))

(defalias 'string-join 'strings-join)

(defun capital-word-p (word)
  "Return t if first letter of WORD is uppercased."
  (= (elt word 0)
     (elt (capitalize word) 0)))

;;; Define keys

(defmacro define-keys (key-map &rest key-funcs)
  "Define key bindings for KEY-MAP (create KEY-MAP, if it does
not exist."
  `(progn
     (unless (boundp ',key-map)
       (setf ,key-map (make-sparse-keymap)))
     ,@(mapcar
  #'(lambda (key-func)
      `(define-key ,key-map ,(first key-func) ,(second key-func)))
  key-funcs)))

;; Files

(defun append-string-to-file (file string)
  "Append a string to end of a file."
  (write-region string nil file t))

(defun write-string-to-file (file string)
  "Write a string to a file (erasing the previous content)."
  (write-region string nil file))

(defun read-from-file (file-name)
  "Read sexpr from a file named FILE-NAME."
  (with-temp-buffer
    (insert-file-contents file-name)
    (read (current-buffer))))

;; File hierarchy functions

(defun find-recursive-files (file-regexp directory)
  "Return a list of files, found in DIRECTORY and match them to FILE-REGEXP."
  (find-recursive-filter-out
   find-recursive-exclude-files
   (find-recursive-directory-relative-files directory "" file-regexp)))

(defun directory-name (path)
  "Return the name of a directory with a given path.
For example, (path \"/foo/bar/baz/../\") returns bar."
  ;; Rewrite me
  (let ((old-path default-directory))
    (cd path)
    (let ((dir (pwd)))
      (cd old-path)
      (replace-regexp-in-string "^Directory[ ]*" "" dir))))

(defun find-or-ask-to-create (question file)
  "Open file if it exists. If it does not exist, ask to create
it."
    (if (file-exists-p file)
  (find-file file)
      (when (y-or-n-p question)
  (when (string-match "\\(.*\\)/[^/]+$" file)
    (make-directory (match-string 1 file) t))
  (find-file file))))

(defun directory-of-file (file-name)
  "Return the parent directory of a file named FILE-NAME."
  (replace-regexp-in-string "[^/]*$" "" file-name))

(defmacro* in-directory ((directory) &rest body)
  (let ((before-directory (gensym)))
  `(let ((,before-directory default-directory)
         (default-directory ,directory))
       (cd ,directory)
       ,@body
       (cd ,before-directory))))


;; Buffers

(defun buffer-string-by-name (buffer-name)
  "Return the content of buffer named BUFFER-NAME as a string."
  (interactive)
  (save-excursion
    (set-buffer buffer-name)
    (buffer-string)))

(defun buffer-visible-p (buffer-name)
  (if (get-buffer-window buffer-name) t nil))

;; Misc

(defun rails-browse-api-url (url)
  "Browse preferentially with Emacs w3m browser."
  (if rails-browse-api-with-w3m
      (when (fboundp 'w3m-find-file)
        (w3m-find-file (remove-prefix url "file://")))
    (rails-alternative-browse-url url)))

(defun rails-alternative-browse-url (url &rest args)
  "Fix a problem with Internet Explorer not being able to load
URLs with anchors via ShellExecute. It will only be invoked it
the user explicit sets `rails-use-alternative-browse-url'."
  (if (and (eq system-type 'windows-nt) rails-use-alternative-browse-url)
      (w32-shell-execute "open" "iexplore" url)
    (browse-url url args)))

;; abbrev
;; from http://www.opensource.apple.com/darwinsource/Current/emacs-59/emacs/lisp/derived.el
(defun merge-abbrev-tables (old new)
  "Merge an old abbrev table into a new one.
This function requires internal knowledge of how abbrev tables work,
presuming that they are obarrays with the abbrev as the symbol, the expansion
as the value of the symbol, and the hook as the function definition."
  (when old
    (mapatoms
     (lambda(it)
       (or (intern-soft (symbol-name it) new)
           (define-abbrev new
             (symbol-name it)
             (symbol-value it)
             (symbol-function it)
             nil
             t)))
     old)))

;; Colorize

(defun apply-colorize-to-buffer (name)
  (let ((buffer (current-buffer)))
    (set-buffer name)
    (make-local-variable 'after-change-functions)
    (add-hook 'after-change-functions
              '(lambda (start end len)
                 (ansi-color-apply-on-region start end)))
    (set-buffer buffer)))

;; completion-read
(defun rails-completing-read (prompt table history require-match)
  (let ((history-value (symbol-value history)))
  (list (completing-read
         (format "%s?%s: "
                 prompt
                 (if (car history-value)
                     (format " (%s)" (car history-value))
                   ""))
         (list->alist table) ; table
         nil ; predicate
         require-match ; require-match
         nil ; initial input
         history ; hist
         (car history-value))))) ;def

;; railsy-replace
(defun camelized-p (string)
  "Return nil unless string is in camelized format (first character is capital, there is at least on lower capital and all characters are letters of numbers"
  (let ((case-fold-search nil))
      (string-match "^[A-Z][A-Za-z0-9]*[a-z]+[A-Za-z0-9]*$" string)))

(defun underscored-p (string)
  "Return nil unless string is in underscored format (containing only lower case characters, numbers or underscores)"
  (let ((case-fold-search nil))
    (string-match "^[a-z][a-z0-9_]*$" string)))

(defun replace-rails-variable ()
  (interactive)
)

;; Cross define functions from my rc files

(provide 'rails-lib)
