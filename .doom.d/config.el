;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!


;; Setup ENV for MAC
;; (when (memq window-system '(mac ns x))
;;   (exec-path-from-shell-initialize))

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Vasilis Spilka"
      user-mail-address "vasspilka@gmail.com"
      )

;; Doom exposes five (optional) variables for controlling fonts in Doom. Here
;; are the three important ones:
;;
;; + `doom-font'
;; + `doom-variable-pitch-font'
;; + `doom-big-font' -- used for `doom-big-font-mode'; use this for
;;   presentations or streaming.
;;
;; They all accept either a font-spec, font string ("Input Mono-12"), or xlfd
;; font string. You generally only need these two:
;; (setq doom-font (font-spec :family "monospace" :size 12 :weight 'semi-light)
;;       doom-variable-pitch-font (font-spec :family "sans" :size 13))

;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-font (font-spec :family "Source Code Pro" :size 16))
(setq display-line-numbers-type nil)
(setq doom-theme 'doom-one)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; (use-package! tree-sitter
;;   :init
;;   (defface tree-sitter-hl-face:warning
;;     '((default :inherit font-lock-warning-face))
;;     "Face for parser errors"
;;     :group 'tree-sitter-hl-faces)

;;   (defun hook/tree-sitter-common ()
;;     (unless font-lock-defaults
;;       (setq font-lock-defaults '(nil)))
;;     (setq tree-sitter-hl-use-font-lock-keywords nil)
;;     (tree-sitter-mode +1)
;;     (tree-sitter-hl-mode +1))

;;   (defun hook/elixir-tree-sitter ()
;;     (require 'f)
;;     (require 's)

;;     (setq tree-sitter-hl-default-patterns
;;      (read
;;       (concat
;;        "["
;;        (s-replace "#match?" ".match?"
;;                   (f-read-text (expand-file-name "~/tree-sitter-elixir/queries/highlights.scm")))
;;        "]")))
;;     (hook/tree-sitter-common))

;;   :hook ((elixir-mode . hook/elixir-tree-sitter))
;;   :custom-face
;;   (tree-sitter-hl-face:operator ((t)))
;;   (tree-sitter-hl-face:variable ((t)))
;;   (tree-sitter-hl-face:function.method.call ((t)))
;;   (tree-sitter-hl-face:property ((t))))
;;
;; (use-package! tree-sitter
;;   :config
;;   (require 'tree-sitter-langs)
;;   (global-tree-sitter-mode)
;;   (add-hook 'tree-sitter-after-on-hook #'tree-sitter-hl-mode))


;; (use-package! tree-sitter-langs
;;   :after tree-sitter
;;   :config
;;   (add-to-list 'tree-sitter-major-mode-language-alist '(elixir-mode . elixir)))


;; (add-to-list 'default-frame-alist '(fullscreen . maximized))


(defun elixir-append-inspect ()
  (interactive)
  (evil-append-line nil)
  (insert " |> dbg")
  (evil-normal-state)
  )

(global-set-key (kbd "C-s") 'save-buffer)
(global-set-key (kbd "s-s") 'save-buffer)

;; (setq-hook! 'elixir-mode-hook +format-with 'lsp-format-buffer)

;; Setup some keybindings for exunit and lsp-ui
(map! :mode elixir-mode
      :leader
      :desc "Sort Lines" :nve  "l"    #'sort-lines
      :desc "Toggle Test" :nve  "cT"    #'exunit-toggle-file-and-test
      :desc "Inspect" :nve  "cI"    #'elixir-append-inspect)


(setq mouse-wheel-tilt-scroll t)

(keychain-refresh-environment)

;; Here are some additional functions/macros that could help you configure Doom:
                                        ;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package!' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c c k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c c d') to jump to their definition and see how
;; they are implemented.
