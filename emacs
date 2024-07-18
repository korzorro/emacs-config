
;;;;;;;;;;;;;;;;;;;; CONTACT ;;;;;;;;;;;;;;;;;;;;
(setq user-mail-address "mkorzon@scsprotect.com")
(setq user-full-name "Michael Korzon")


;;;;;;;;;;;;;;;;;;;; PRODUCTIVITY ;;;;;;;;;;;;;;;;;;;;
;;(prefer-coding-system 'utf-8-unix) ; encoding for input and writing files
;;(global-font-lock-mode 't) ; enable syntax highlighting by default
(column-number-mode 't) ; show current column in status bar

(global-whitespace-mode) ; enable whitespace handling by default
(setq
  whitespace-style ; see (apropos 'whitespace-style)
  '(face ; viz via faces
    trailing ; trailing blanks visualized
    lines-tail ; lines beyond whitespace-line-column visualized
    space-before-tab
    space-after-tab
    newline ; lines with only blanks visualized
    indentation ; spaces used for indent when config wants tabs
    empty ; empty lines at beginning or end or buffer
    )
  whitespace-line-column 100) ; column at which whitespace-mode says the line is too long

;; Spell check - install "aspell" and aspell dictionaries.
(setq
  ispell-program-name "aspell"
  ispell-extra-args '("--sug-mode=ultra"))


;;;;;;;;;;;;;;;;;;;; REPOSITORY ;;;;;;;;;;;;;;;;;;;;
(require 'package)
(setq package-archives
      '(("elpy" . "http://jorgenschaefer.github.io/packages/")
        ("melpa" . "https://melpa.org/packages/")
        ("gnu" . "http://elpa.gnu.org/packages/")
        ("melpa-stable" . "https://stable.melpa.org/packages/")))
(package-initialize)
(package-refresh-contents)

;;;;;;;;;;;;;;;;;;;;;;;; PROJECT MANAGEMENT ;;;;;;;;;;;;;;;;;;;;;;;;;

;; Advanced per-language checks.
(require 'flycheck)
(global-flycheck-mode 1)
(setq flycheck-checker-error-threshold 1000) ; for large go files and the escape checker

;; Advanced git interface.
(require 'magit)
(setq magit-fetch-modules-jobs 16)

;; Navigation inside code project
(require 'projectile)
(projectile-mode "1.0")

;; Helm: incremental completion and selection narrowing inside menus/lists
(require 'helm)
(require 'helm-projectile)
(helm-mode 1)
(helm-projectile-on)

(setq helm-split-window-inside-p            t ; open helm buffer inside current window, not occupy whole other window
      helm-move-to-line-cycle-in-source     t ; move to end or beginning of source when reaching top or bottom of source.
      helm-ff-search-library-in-sexp        t ; search for library in `require' and `declare-function' sexp.
      helm-scroll-amount                    8 ; scroll 8 lines other window using M-<next>/M-<prior>
      helm-ff-file-name-history-use-recentf t
      helm-echo-input-in-header-line t)

(require 'company) ; code completion framework
(require 'compile) ; per-language builds
(require 'yasnippet)
(yas-global-mode 1)

(require 'lsp-mode) ; language server
;;(add-hook 'lsp-mode-hook 'lsp-ui-mode) ; display contextual overlay
;;(with-eval-after-load 'flycheck
;;  (add-to-list 'flycheck-checkers 'lsp-ui))

;;;;;;;;;;;;;;;;;;;;;;;; Python ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

;; Requires: anaconda, company

(add-hook 'python-mode-hook 'anaconda-mode)
(add-hook 'python-mode-hook 'anaconda-eldoc-mode)
(eval-after-load "company"
  '(add-to-list 'company-backends 'company-anaconda))
(eval-after-load "company"
  '(add-to-list 'company-backends '(company-anaconda :with company-capf)))
(add-hook 'python-mode-hook #'lsp)


;;;;;;;;;;;;;;;;;;;;;;;; Go ;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(require 'go-projectile)
(go-projectile-tools-add-path)
(setq go-projectile-tools
  '((gocode    . "github.com/mdempsky/gocode")
    (golint    . "golang.org/x/lint/golint")
    (godef     . "github.com/rogpeppe/godef")
    (errcheck  . "github.com/kisielk/errcheck")
    (godoc     . "golang.org/x/tools/cmd/godoc")
    (gogetdoc  . "github.com/zmb3/gogetdoc")
    (goimports . "golang.org/x/tools/cmd/goimports")
    (gorename  . "golang.org/x/tools/cmd/gorename")
    (gomvpkg   . "golang.org/x/tools/cmd/gomvpkg")
    (guru      . "golang.org/x/tools/cmd/guru")))

;;(require 'company-go) ; obsolete with company-lsp
(require 'go-mode)
(add-hook 'go-mode-hook #'lsp)
(add-hook 'go-mode-hook (lambda ()
  (company-mode) ; enable company upon activating go
  ;;(set (make-local-variable 'company-backends) '(company-go))

  ;; Code layout.
  (setq tab-width 2 indent-tabs-mode 1) ; std go whitespace configuration
  (add-hook 'before-save-hook 'gofmt-before-save) ; run gofmt on each save

  ;; Shortcuts for common go-test invocations.
  (let ((map go-mode-map))
    (define-key map (kbd "C-c a") 'go-test-current-project) ;; current package, really
    (define-key map (kbd "C-c m") 'go-test-current-file)
    (define-key map (kbd "C-c .") 'go-test-current-test)
    )

  ;; Fix parsing of error and warning lines in compiler output.
  (setq compilation-error-regexp-alist-alist ; first remove the standard conf; it's not good.
        (remove 'go-panic
                (remove 'go-test compilation-error-regexp-alist-alist)))
  ;; Make another one that works better and strips more space at the beginning.
  (add-to-list 'compilation-error-regexp-alist-alist
               '(go-test . ("^[[:space:]]*\\([_a-zA-Z./][_a-zA-Z0-9./]*\\):\\([0-9]+\\):.*$" 1 2)))
  (add-to-list 'compilation-error-regexp-alist-alist
               '(go-panic . ("^[[:space:]]*\\([_a-zA-Z./][_a-zA-Z0-9./]*\\):\\([0-9]+\\)[[:space:]].*$" 1 2)))
  ;; override.
  (add-to-list 'compilation-error-regexp-alist 'go-test t)
  (add-to-list 'compilation-error-regexp-alist 'go-panic t)
  ))

;; Bonus: escape analysis.
(flycheck-define-checker go-build-escape
  "A Go escape checker using `go build -gcflags -m'."
  :command ("go" "build" "-gcflags" "-m"
            (option-flag "-i" flycheck-go-build-install-deps)
            ;; multiple tags are listed as "dev debug ..."
            (option-list "-tags=" flycheck-go-build-tags concat)
            "-o" null-device)
  :error-patterns
  (
   (warning line-start (file-name) ":" line ":"
          (optional column ":") " "
          (message (one-or-more not-newline) "escapes to heap")
          line-end)
   (warning line-start (file-name) ":" line ":"
          (optional column ":") " "
          (message "moved to heap:" (one-or-more not-newline))
          line-end)
   (info line-start (file-name) ":" line ":"
          (optional column ":") " "
          (message "inlining call to " (one-or-more not-newline))
          line-end)
  )
  :modes go-mode
  :predicate (lambda ()
               (and (flycheck-buffer-saved-p)
                    (not (string-suffix-p "_test.go" (buffer-file-name)))))
  :next-checkers ((warning . go-errcheck)
                  (warning . go-unconvert)
                  (warning . go-staticcheck)))

(with-eval-after-load 'flycheck
   (add-to-list 'flycheck-checkers 'go-build-escape)
   (flycheck-add-next-checker 'go-gofmt 'go-build-escape))

;;;;;;;;;;;; Personal preferences ;;;;;;;;;;;;;;;;;;;;;;;

(menu-bar-mode 0)
(show-paren-mode t) ; highlight matching open and close parentheses
(global-hl-line-mode) ; highlight current line
(global-visual-line-mode t) ; wrap long lines
(setq split-window-preferred-function
  'visual-fill-column-split-window-sensibly) ; wrap at window boundary

(require 'ido)
(require 'ido-vertical-mode)
(ido-mode) ; intelligent C-x C-f
(ido-vertical-mode)
(setq magit-completing-read-function 'magit-ido-completing-read)

(require 'swiper) ; better interactive search
;; Predefined: ((kbd "M-g g") 'goto-line)
;; Predefined: (kbd "C-c r t")  rectangle insert
;; Predefined: ((kbd "C-x c i") 'helm-semantic-or-imenu)
;; Predefined: ((kbd "C-x c /") 'helm-find)

(global-set-key (kbd "C-c <left>")  'windmove-left)
(global-set-key (kbd "C-c <right>") 'windmove-right)
(global-set-key (kbd "C-c <up>")    'windmove-up)
(global-set-key (kbd "C-c <down>")  'windmove-down)
(global-set-key "\M-#" 'query-replace-regexp)
(global-set-key "\M-," 'flyspell-goto-next-error)
(global-set-key "\M- " 'set-mark-command)
(global-set-key "\M-*" 'pop-tag-mark)
(global-set-key "\M-x" 'helm-M-x)
(global-set-key "\C-s" 'swiper)
(global-set-key "\C-r" 'swiper-backward)
(global-set-key (kbd "C-x g") 'magit-status)
(global-set-key (kbd "C-x M-g") 'magit-dispatch-popup)
(global-set-key (kbd "C-x f") 'helm-projectile-find-file)
(global-set-key (kbd "M-y") 'helm-show-kill-ring)
(global-set-key (kbd "C-x b") 'helm-mini)
(global-set-key (kbd "C-x c o") 'helm-occur)
(global-set-key [f9] 'projectile-test-project)
(define-key projectile-mode-map (kbd "C-c p") 'projectile-command-map)
(add-hook 'go-mode-hook (lambda ()
  (go-guru-hl-identifier-mode) ; higlight all occurrences of identifier at point
  (local-set-key (kbd "M-.") #'godef-jump) ; M-. is jump-to-definition
  (define-key projectile-command-map (kbd "G") 'vc-git-grep)
  ))

;; Indent 4 spaces by default. Use the "BSD" style for C-like languages.
(setq c-default-style
      (quote ((java-mode . "java")
              (awk-mode . "awk")
              (other . "bsd")))
      c-basic-offset 4)

;; Use 4 spaces for one tab visually.
(setq tab-width 4)


;; Theme
(load-theme 'leuven t)

;; Variables Set through Emacs
(custom-set-variables
 ;; custom-set-variables was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 '(Custom-enabled-themes '(leuven))
 '(ansi-color-names-vector
   ["#242424" "#e5786d" "#95e454" "#cae682" "#8ac6f2" "#333366" "#ccaa8f" "#f6f3e8"])
 '(c-basic-offset 2)
 '(column-number-mode t)
 '(css-indent-offset 2)
 '(custom-safe-themes
   '("eafda598b275a9d68cc1fbe1689925f503cab719ee16be23b10a9f2cc5872069" default))
 '(elpy-rpc-backend "jedi")
 '(go-indent-offset 2)
 '(go-ts-mode-indent-offset 2)
 '(inhibit-startup-screen t)
 '(js-indent-level 2)
 '(js2-basic-offset 2)
 '(js2-indent-switch-body t)
 '(js2-mode-indent-ignore-first-tab nil)
 '(markdown-command "/usr/bin/pandoc")
 '(package-selected-packages
   '(swiper ido-vertical-mode go-projectile helm-projectile helm flycheck yasnippet lsp-ui company lsp-mode typescript-mode dockerfile-mode go-eldoc go-mode elpy edit-indirect js-comint prettier flycheck-color-mode-line web-mode-edit-element markdown-mode impatient-mode use-package emacsql-sqlite3 emacsql-sqlite org-roam direnv projectile dash-functional quelpa transient python-pytest ace-window auto-complete anaconda-mode ## rjsx-mode autopair company-tern js2-refactor js2-mode yaml-mode web-mode rainbow-delimiters pyenv-mode paredit nodejs-repl magit cider))
 '(python-indent-guess-indent-offset nil)
 '(tool-bar-mode nil)
 '(typescript-indent-level 2)
 '(web-mode-attr-indent-offset 2)
 '(web-mode-code-indent-offset 2)
 '(web-mode-enable-auto-pairing t)
 '(web-mode-markup-indent-offset 2))

(custom-set-faces
 ;; custom-set-faces was added by Custom.
 ;; If you edit it by hand, you could mess it up, so be careful.
 ;; Your init file should contain only one such instance.
 ;; If there is more than one, they won't work right.
 )


;; Custom Bindings Here
(global-set-key (kbd "C-x r") 'replace-string)
(global-set-key (kbd "M-o") 'ace-window)

;; Relocate backups and autosaves (causing problems with node)
(setq backup-directory-alist
      `(("." . ,(expand-file-name
                 (concat user-emacs-directory "backups")))))
(setq auto-save-file-name-transforms
      `((".*" ,(expand-file-name
                (concat user-emacs-directory "auto-save")) t)))


;; Supress lockfile creation
(setq create-lockfiles nil)

