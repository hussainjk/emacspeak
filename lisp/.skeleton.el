;;; emacspeak-<skeleton>.el --- Speech-enable <SKELETON>  -*- lexical-binding: t; -*-
;;; $Author: tv.raman.tv $
;;; Description:  Speech-enable <SKELETON> An Emacs Interface to <skeleton>
;;; Keywords: Emacspeak,  Audio Desktop <skeleton>
;;{{{  LCD Archive entry:

;;; LCD Archive Entry:
;;; emacspeak| T. V. Raman |raman@cs.cornell.edu
;;; A speech interface to Emacs |
;;;  $Revision: 4532 $ |
;;; Location undetermined
;;;

;;}}}
;;{{{  Copyright:
;;;Copyright (C) 1995 -- 2007, 2019, T. V. Raman
;;; All Rights Reserved.
;;;
;;; This file is not part of GNU Emacs, but the same permissions apply.
;;;
;;; GNU Emacs is free software; you can redistribute it and/or modify
;;; it under the terms of the GNU General Public License as published by
;;; the Free Software Foundation; either version 2, or (at your option)
;;; any later version.
;;;
;;; GNU Emacs is distributed in the hope that it will be useful,
;;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;;; MERCHANTABILITY or FITN<SKELETON> FOR A PARTICULAR PURPOSE.  See the
;;; GNU General Public License for more details.
;;;
;;; You should have received a copy of the GNU General Public License
;;; along with GNU Emacs; see the file COPYING.  If not, write to
;;; the Free Software Foundation, 51 Franklin Street, Fifth Floor, Boston,MA 02110-1301, USA.

;;}}}
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;;{{{  introduction

;;; Commentary:
;;; <SKELETON> == 

;;; Code:

;;}}}
;;{{{  Required modules

(require 'cl-lib)
(cl-declaim  (optimize  (safety 0) (speed 3)))
(require 'emacspeak-preamble)

;;}}}
;;{{{ Map Faces:

(let ((print-length 0)
      (faces (emacspeak-wizards-enumerate-unmapped-faces "^<skeleton>"))
      (start (point)))
  (insert "\n\n(voice-setup-add-map \n'(\n")
  (cl-loop for f in faces do 
           (insert (format "(%s)\n" f)))
  (insert "\n)\n)")
  (goto-char start)
  (backward-sexp)
  (kill-sexp)
  (goto-char (search-forward "("))
  (indent-pp-sexp))

;;}}}
;;{{{ Interactive Commands:

(let ((print-length nil)
      (start (point))
      (commands (emacspeak-wizards-enumerate-uncovered-commands "^<skeleton>")))
  (insert "'(\n")
  (cl-loop for c in commands do (insert (format "%s\n" c)))
  (insert ")\n")
  (goto-char start)
  (backward-sexp)
  (kill-sexp)
  (goto-char (search-forward "("))
  (indent-pp-sexp))

;;}}}
(provide 'emacspeak-<skeleton>)
;;{{{ end of file

;;; local variables:
;;; folded-file: t
;;; end:

;;}}}
