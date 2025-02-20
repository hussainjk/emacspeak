;;; g-utils.el --- Google Client Utilities  -*- lexical-binding: t; -*-
;;;$Id$
;;; $Author: raman $
;;; Description:  Google Client utilities
;;; Keywords: Google   Atom API, Google Services
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; g-client| T. V. Raman |tv.raman.tv@gmail.com
;;; An emacs interface to Google Services|
;;; $Date: 2006/10/13 01:38:19 $ |
;;;  $Revision: 1.14 $ |
;;; Location undetermined
;;; License: GPL
;;;

;;}}}
;;{{{ Copyright:

;;; Copyright (c) 2006 and later, Google Inc.
;;; All rights reserved.

;;; Redistribution and use in source and binary forms, with or without modification,
;;; are permitted provided that the following conditions are met:

;;;     * Redistributions of source code must retain the above copyright notice,
;;;       this list of conditions and the following disclaimer.
;;;     * Redistributions in binary form must reproduce the above copyright notice,
;;;       this list of conditions and the following disclaimer in the documentation
;;;       and/or other materials provided with the distribution.
;;;     * The name of the author may not be used to endorse or promote products
;;;       derived from this software without specific prior written permission.

;;; THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS"
;;; AND ANY EXPRESS OR IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE
;;; IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE
;;; ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE
;;; LIABLE FOR ANY DIRECT, INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR
;;; CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE
;;; GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
;;; HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT,
;;; STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY
;;; WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF
;;; SUCH DAMAGE.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{  introduction
;;; Commentary:
;;; Common Code  e.g. helper functions.
;;; Used by modules like gphoto, gblogger etc.
;;; Code:
;;}}}
;;{{{  Required modules

(require 'cl-lib)
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'json)

;;}}}
;;{{{ Customizations:

(defvar g-scratch-buffer" *g scratch*"
  "Scratch buffer we do authentication work.")

(defvar g-curl-program (executable-find "curl")
  "Name of CURL executable.")

(defcustom g-atom-view-xsl
  (eval-when-compile
    (require 'emacspeak-xslt)
    (emacspeak-xslt-get "atom-view.xsl"))
  "XSLT transform to convert Atom feed to HTML."
  :type 'string
  :group 'g)

(defcustom g-curl-common-options
  "--http1.0 --compressed --silent --location --location-trusted --max-time 4 --connect-timeout 1"
  "Common options to pass to all Curl invocations."
  :type 'string
  :group 'g)

(defvar g-html-handler 'browse-url-of-buffer
  "Function that processes HTML.
Receives buffer containing HTML as its argument.")

(defcustom g-xslt-program "xsltproc"
  "XSLT Processor."
  :type 'string
  :group 'g)

(defcustom g-cookie-jar
  nil
  "Cookie jar used for Google services.
Customize this to live on your local disk."
  :type 'file
  :set #'(lambda (sym val)
         (cl-declare (special g-cookie-options))
         (setq g-cookie-options
               (format "--cookie %s --cookie-jar %s"
                       val val))
         (set-default sym val))
  :group 'g)

(defun g-cookie-jar ()
  "Return our cookie jar."
  (cl-declare (special g-cookie-jar))

  (unless g-cookie-jar (setq g-cookie-jar (make-temp-file ".g-cookie-jar")))
  g-cookie-jar)

(defvar g-cookie-options
  (format "--cookie %s --cookie-jar %s"
          g-cookie-jar g-cookie-jar)
  "Options to pass for using our cookie jar.")

(defun g-cookie-options ()
  "Return cookie jar options."
  (cl-declare (special g-cookie-options))
  (unless g-cookie-options
    (setq g-cookie-options
          (format "--cookie %s --cookie-jar %s"
                  (g-cookie-jar) (g-cookie-jar))))
  g-cookie-options)

(defcustom g-curl-debug nil
  "Set to T to see Curl stderr output."
  :type 'boolean
  :group 'g)

;;}}}
;;{{{  buffer bytes rather than buffer size

;;; buffer-size returns number of chars.
;;; this helper returns number of bytes.
(defun g-buffer-bytes (&optional buffer)
  "Return number of bytes in a buffer."
  (save-excursion
    (and buffer (set-buffer buffer))
    (1- (position-bytes (point-max)))))

;;}}}
;;{{{ debug helpers

(defun g-curl-debug ()
  "Determines if we show stderr output."
  (cl-declare (special g-curl-debug))
  (if g-curl-debug
      ""
    " 2>/dev/null"))

;;}}}
;;{{{ url encode:

(defun g-url-encode (str)
  "URL encode  string."
  (mapconcat #'(lambda (c)
                 (cond ((= c 32) "+")
                       ((or (and (>= c ?a) (<= c ?z))
                            (and (>= c ?A) (<= c ?Z))
                            (and (>= c ?0) (<= c ?9)))
                        (char-to-string c))
                       (t (upcase (format "%%%02x" c)))))
             str
             ""))

;;}}}
;;{{{ transform region

(defun g-xsl-transform-region (start end xsl)
  "Replace region by result of transforming via XSL."
  (cl-declare (special g-xslt-program))
  (call-process-region
   start end
   g-xslt-program
   t t nil
   xsl
   "-"))

;;}}}
;;{{{ html unescape

(defvar g-html-charent-alist
  '(("&lt;" . "<")
    ("&gt;" . ">")
    ("&quot;" . "\"")
    ("&apos;" . "'") ("&amp;" . "&"))
  "Alist of HTML character entities to unescape.")

(defun g-html-unescape-region (start end)
  "Unescape HTML entities."
  (cl-declare (special g-html-charent-alist))
  (save-excursion
    (cl-loop for entry in g-html-charent-alist
             do
             (let ((entity (car  entry))
                   (replacement (cdr entry)))
               (goto-char start)
               (while (search-forward entity end t)
                 (replace-match replacement nil t))))))

(defun g-html-escape-region (start end)
  "Escape HTML entities."
  (cl-declare (special g-html-charent-alist))
  (save-excursion
    (cl-loop for entry in g-html-charent-alist
             do
             (let ((entity (cdr  entry))
                   (replacement (car entry)))
               (goto-char start)
               (while (search-forward entity end t)
                 (replace-match replacement nil t))))))

;;}}}
;;{{{ json conveniences:

(defun g-json-get (key object)
  "Return object.key from json object or nil if not found.
Key must be a symbol.
For using string keys, use g-json-lookup."
  (cdr (assq key object)))
(defun g-json-get-string (key object)
  "Return empty string instead of nil for false."
  (or (g-json-get key object) ""))

;;; Make sure to call json-read
;;; with json-key-type bound to 'string before using this:

(defun g-json-lookup (key object)
  "Return object.key from json object or nil if not found.
Key  is a string of  the form a.b.c"
  (let ((name  (mapcar #'intern (split-string key "\\." 'omit-null)))
        (v object))
    (while (and name
                (setq v (cdr (assq (car name) v))))
      (setq name (cdr name)))
    (cond
     ((null name) v)
     (t nil))))

(defun g-json-path-lookup (path object)
  "Return objectat path from json object or nil if not
found. Path is a string of the form a.b.[1].c. [n] denotes array
references, poor-man's xpath."
  (let ((name    (split-string path "\\." 'omit-null))
        (key nil)
        (v object))
    (while (and name
                (setq key (car name)))
      (cond
       ((char-equal  (aref  key 0) ?\[)
        (setq v (aref  v (read (substring    key 1 -1)))))
       (t
        (setq key (intern key))
        (setq v (cdr (assq key v)))))
      (setq name (cdr name)))
    (cond
     ((null name) v)
     (t nil))))

(defun g-json-lookup-string  (key object)
  "Like g-json-lookup, but returns empty string for nil."
  (or (g-json-lookup key object) ""))

(defalias 'g-json-aref 'aref)

;;}}}
;;{{{ helper macros

(defmacro g-using-scratch(&rest body)
  "Evaluate forms in a  ready to use temporary buffer."
  (declare (indent 1) (debug t))
  `(let ((buffer (get-buffer-create g-scratch-buffer))
         (default-process-coding-system (cons 'utf-8 'utf-8))
         (coding-system-for-read 'binary)
         (coding-system-for-write 'binary)
         (buffer-undo-list t))
     (with-current-buffer buffer 
       (kill-all-local-variables)
       (erase-buffer)
       ,@body)))

(defun g-get-result (command)
  "Run command and return its output."
  (cl-declare (special shell-file-name shell-command-switch))
  (g-using-scratch
   (call-process shell-file-name nil t nil
                 shell-command-switch command)
   (set-buffer-multibyte nil) ;return raw binary string
   (buffer-string)))

(defun g-json-get-result (command)
  "Get command results and return json object read from string."
  (cond
   ((fboundp 'json-parse-string)        ; emacs 27.1
    (json-parse-string (g-get-result command) :object-type 'alist))
   (t
    (json-read-from-string (g-get-result command)))))

(defun g-json-from-url (url)
  "Return JSON read from URL."
  (g-json-get-result
   (format "%s  %s '%s'" g-curl-program g-curl-common-options url)))

(defun g-display-result (command style)
  "Display result retrieved by command using specified style.
Typically, content is pulled using Curl , converted to HTML using style  and
  previewed via `g-html-handler'."
  (cl-declare (special g-xslt-program g-html-handler))
  (g-using-scratch
   (call-process shell-file-name nil t
                 nil shell-command-switch
                 command)
   (when style
     (g-xsl-transform-region (point-min) (point-max) style))
   (funcall g-html-handler (current-buffer))))

(defun g-display-xml-string (string style)
  "Display XML string  using specified style.
XML string is transformed via style
  and previewed via `g-html-handler'."
  (cl-declare (special g-xslt-program g-html-handler))
  (g-using-scratch
   (insert string)
   (when style
     (g-xsl-transform-region (point-min) (point-max) style))
   (funcall g-html-handler (current-buffer))))

(defun g-display-xml-buffer (buffer style)
  "Display XML buffer  using specified style.
XML  is transformed via style
  and previewed via `g-html-handler'."
  (cl-declare (special g-xslt-program g-html-handler))
  (with-current-buffer buffer
    (when style
      (g-xsl-transform-region (point-min) (point-max) style))
    (funcall g-html-handler (current-buffer))))

;;}}}
;;{{{  HTTP Headers:
(defvar g-curl-atom-header
  "--header 'Content-Type: application/atom+xml' --header 'GData-Version: 2'"
  "Content type header for application/atom+xml")

(defvar g-curl-data-binary
  "--data-binary"
  "Curl option for binary data.")

(defvar g-mime-separator
  "--===-=-="
  "Mime separator.")

(defvar g-curl-image-options
  "--http1.0 --data-binary @%s -H 'Content-Type: image/jpeg' -H 'Slug: %s'"
  "Curl options for uploading images.")

(defvar g-crlf-pair
  (format "%c%c%c%c" 13 10 13  10)
  "HTTP headers are ended by a CRLF pair.
Note that in the Curl output, we see lf rather than crlf.")

(defun g-http-headers (start end)
  "Parse HTTP headers in region and return an alist."
  (cl-declare (special g-crlf-pair))
  (goto-char start)
  (when (search-forward g-crlf-pair end 'no-error)
    (setq end (point)))
  (save-restriction
    (narrow-to-region start end)
    (let ((headers nil)
          (pos nil)
          (fields nil))    (goto-char (point-min))
          (when (looking-at "HTTP/[0-9.]+")
            (skip-syntax-forward "^ ")
            (skip-syntax-forward " ")
            (setq pos (point))
            (skip-syntax-forward "^ ")
            (push
             (cons "Status"
                   (buffer-substring-no-properties
                    pos (point)))
             headers)
            (forward-line 1))
          (while (not (eobp))
            (setq fields
                  (split-string (buffer-substring-no-properties
                                 (line-beginning-position)
                                 (line-end-position))
                                ": "))
            (when (= 2 (length fields))
              (push
               (cons (cl-first fields) (cl-second fields))
               headers))
            (forward-line 1))
          headers)))

(defun g-http-body (start end)
  "Return body from HTTP response."
  (cl-declare (special g-crlf-pair))
  (goto-char start)
  (cond
   ((search-forward g-crlf-pair end 'no-error)
    (buffer-substring-no-properties (point) end))
   (t "")))

(defun g-http-header (name header-alist)
  "Return specified header from headers-alist."
  (when (assoc name header-alist) (cdr (assoc name header-alist))))

;;}}}
;;{{{ collect content from user via special buffer:
(defvar g-user-edit-buffer " *User Input*"
  "Special buffer used to read  user input.")

(defun g-get-user-input ()
  "Pop up a temporary buffer and collect user input."
  (cl-declare (special g-user-edit-buffer))
  (let ((annotation nil))
    (pop-to-buffer (get-buffer-create g-user-edit-buffer))
    (erase-buffer)
    (message "Exit recursive edit when done.")
    (recursive-edit)
    (local-set-key "\C-c\C-c" 'exit-recursive-edit)
    (setq annotation (buffer-string))
    (bury-buffer)
    annotation))

;;}}}
;;{{{ convert html to text

(defun g-html-string (html-string)
  "Return formatted string."
  (with-temp-buffer
    (insert html-string)
    (shr-render-region  (point-min) (point-max))
    (buffer-string)))
;;}}}
(provide 'g-utils)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; end:

;;}}}
