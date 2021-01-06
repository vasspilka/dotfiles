;;; $DOOMDIR/config.el -*- lexical-binding: t; -*-

;; Place your private configuration here! Remember, you do not need to run 'doom
;; sync' after modifying this file!
;;
;;

;; Setup ENV for MAC
(when (memq window-system '(mac ns x))
  (exec-path-from-shell-initialize))

;; Some functionality uses this to identify you, e.g. GPG configuration, email
;; clients, file templates and snippets.
(setq user-full-name "Vasilis Spilka"
      user-mail-address "vasspilka@gmail.com"
      projectile-project-search-path '("~/Work" "~/Work/utrust")
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
(setq doom-font (font-spec :family "Source Code Pro" :size 18))
(setq display-line-numbers-type nil)


;; There are two ways to load a theme. Both assume the theme is installed and
;; available. You can either set `doom-theme' or manually load a theme with the
;; `load-theme' function. This is the default:
(setq doom-theme 'doom-dracula)

;; If you use `org' and don't want your org files in the default location below,
;; change `org-directory'. It must be set before org loads!
(setq org-directory "~/org/")

;; This determines the style of line numbers in effect. If set to `nil', line
;; numbers are disabled. For relative line numbers, set this to `relative'.
(setq display-line-numbers-type t)

;; Sort keys
(setq which-key-sort-order 'which-key-key-order-alpha)

(add-to-list 'default-frame-alist '(fullscreen . maximized))

(defun test-vas()
  (evil-end-of-line)
  (insert " |> IO.inspect"))

(global-set-key (kbd "C-s") 'save-buffer)

;; Configure exunit
(use-package! exunit)

;; Taken off https://gist.github.com/darioghilardi/f3415a3d70d4fee5a20bfad862534a37
;; Elixir configuration


;; I should do instead
;; (add-to-list 'exec-path "${elixir-lsp}/bin")
;; (setq lsp-clients-elixir-server-executable "elixir-ls")

;; (after! lsp-clients
;;   (lsp-register-client
;;    (make-lsp-client :new-connection
;;     (lsp-stdio-connection
;;         (expand-file-name
;;           "~/elixir-ls/release/language_server.sh"))
;;         :major-modes '(elixir-mode)
;;         :priority -1
;;         :server-id 'elixir-ls
;;         :initialized-fn (lambda (workspace)
;;             (with-lsp-workspace workspace
;;              (let ((config `(:elixirLS
;;                              (:mixEnv "dev"
;;                                      :dialyzerEnabled
;;                                      :json-false))))
;;              (lsp--set-configuration config)))))))

;; Configure LSP-ui to define when and how to display informations.
(after! lsp-ui
  (setq lsp-ui-doc-max-height 20
        lsp-ui-doc-max-width 80
        lsp-ui-sideline-ignore-duplicate t
        lsp-ui-doc-header t
        lsp-ui-doc-include-signature t
        lsp-ui-doc-position 'bottom
        lsp-ui-doc-use-webkit nil
        lsp-ui-flycheck-enable t
        lsp-ui-imenu-kind-position 'left
        lsp-ui-sideline-code-actions-prefix "💡"
        ;; fix for completing candidates not showing after “Enum.”:
        company-lsp-match-candidate-predicate #'company-lsp-match-candidate-prefix
        ))

(set-file-template! "\\.html$"
  :mode 'web-mode
  :ignore t)

(set-file-template! "**"
  :mode 'web-mode
  :ignore t)

;; Setup some keybindings for exunit and lsp-ui
(map! :mode elixir-mode
        :leader
        :desc "iMenu" :nve  "c/"    #'lsp-ui-imenu
        :desc "Toggle Test" :nve  "cT"    #'exunit-toggle-file-and-test
        :desc "Inspect" :nve  "cI"    #'test-vas)

(keychain-refresh-environment)


;; Here are some additional functions/macros that could help you configure Doom:
;;
;; - `load!' for loading external *.el files relative to this one
;; - `use-package' for configuring packages
;; - `after!' for running code after a package has loaded
;; - `add-load-path!' for adding directories to the `load-path', relative to
;;   this file. Emacs searches the `load-path' when you load packages with
;;   `require' or `use-package'.
;; - `map!' for binding new keys
;;
;; To get information about any of these functions/macros, move the cursor over
;; the highlighted symbol at press 'K' (non-evil users must press 'C-c g k').
;; This will open documentation for it, including demos of how they are used.
;;
;; You can also try 'gd' (or 'C-c g d') to jump to their definition and see how
;; they are implemented.
