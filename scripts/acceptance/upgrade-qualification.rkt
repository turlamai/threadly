#lang racket/base

;; Qualification driver for the published-upgrade workflow
;; (.github/workflows/appimage-upgrade-qualification.yml): drives the
;; shipped updater entry points against the real feed. The feed carries
;; the portable entries only (macos zip, windows zip, linux tar.gz — no
;; AppImage), so the Linux leg is the tar.gz: download verification + SHA
;; check, and the host installs by extracting the archive over the app
;; directory. Two modes:
;;
;; upgrade (default) — update-check-result for the checkout's own version
;;   against the live signed feed (releases/latest/download/
;;   update-manifest.json), then start-download! into the data directory
;;   and wait for the terminal phase. Emits one JSON object with the
;;   offered version, the downloaded path and its SHA-256. The 4-hour
;;   silent-check throttle lives in the hosts; these entry points never
;;   consult it.
;;
;; bad-signature (TAMPER_BYTES_PATH set) — the workflow hands us the real
;;   published feed bytes with one payload byte flipped (PRISTINE_BYTES_PATH
;;   carries the untampered bytes as the positive control). Verification is
;;   the first gate fetch-update-manifest applies, before selection or
;;   download; the pristine bytes must verify, the tampered bytes must be
;;   refused, and the updates directory must stay empty — a refused
;;   manifest can never reach disk as an artifact.
;;
;; The data directory comes from THREADLY_DATA_DIR, which the workflow
;; fixes for this driver and every packaged boot.
;;
;; Inputs (environment):
;;   THREADLY_DATA_DIR   data directory
;;   EXPECTED_VERSION    N+1 version string (upgrade mode)
;;   PRISTINE_BYTES_PATH real feed bytes (bad-signature mode, positive control)
;;   TAMPER_BYTES_PATH   tampered feed bytes (bad-signature mode)
;;   OUTPUT_JSON         where to write the result object
;;
;; Prints or writes one JSON object and exits non-zero on any mismatch.

(require crypto
         json
         net/base64
         racket/file
         racket/string
         (only-in rivet/distribution
                  base64-string->bytes
                  sha256-file/hex
                  verify-signed-manifest)
         "../../racket/update.rkt"
         "../../racket/version.rkt")

(define (need name)
  (or (getenv name)
      (error 'upgrade-qualification "~a is not set" name)))

(define (fail fmt . args)
  (apply error 'upgrade-qualification fmt args))

(define data-dir (need "THREADLY_DATA_DIR"))
(define output-json (getenv "OUTPUT_JSON"))
(define pristine-path (getenv "PRISTINE_BYTES_PATH"))
(define tamper-path (getenv "TAMPER_BYTES_PATH"))

;; raw 32-byte key + fixed SPKI prefix, the same assembly
;; racket/update.rkt performs (it is not exported, so the driver rebuilds it
;; from current-update-public-key)
(define embedded-public-key
  (datum->pk-key
   (bytes-append (hex->bytes "302a300506032b6570032100")
                 (base64-string->bytes current-update-public-key))
   'SubjectPublicKeyInfo))

(define updates-dir (build-path data-dir "updates"))
(define (landed-artifacts)
  (if (directory-exists? updates-dir)
      (directory-list updates-dir)
      '()))

(define result
  (cond
    ;; ---------- bad-signature mode ----------
    [tamper-path
     ;; positive control: the pristine published bytes must verify, so the
     ;; refusal below is attributable to the flipped byte alone
     (define pristine-ok
       (with-handlers ([exn:fail? (lambda (_) #f)])
         (verify-signed-manifest (open-input-bytes (file->bytes pristine-path))
                                 embedded-public-key
                                 #:key-id current-update-key-id)
         #t))
     (unless pristine-ok
       (fail "the pristine live feed bytes did not verify — the environment, not the tamper, is broken"))
     (define tampered-accepted?
       (with-handlers ([exn:fail? (lambda (_) #f)])
         (verify-signed-manifest (open-input-bytes (file->bytes tamper-path))
                                 embedded-public-key
                                 #:key-id current-update-key-id)
         #t))
     (when tampered-accepted?
       (fail "one-byte-tampered live feed bytes were ACCEPTED — signature enforcement is broken"))
     (define left (landed-artifacts))
     (unless (null? left)
       (fail "a refused manifest must not reach download; updates/ holds: ~a" left))
     (hasheq 'mode "bad-signature"
             'pristineVerified #t
             'tamperedRefused #t
             'updatesDirEntries '())]
    ;; ---------- upgrade mode ----------
    [else
     (define expected-version (need "EXPECTED_VERSION"))
     (define checked (update-check-result app-version))
     (unless (equal? checked (list 'available expected-version))
       (fail "feed did not offer the expected update: ~a" checked))
     (start-download! data-dir)
     (define snapshot
       (let loop ([n 0])
         (define s (update-state-snapshot))
         (define phase (hash-ref s 'phase #f))
         (cond
           [(member phase '("downloaded" "error")) s]
           [(> n 600) s]
           [else (sleep 0.2) (loop (add1 n))])))
     (define phase (hash-ref snapshot 'phase #f))
     (unless (equal? phase "downloaded")
       (fail "download ended in phase ~a (message: ~a)"
             phase (hash-ref snapshot 'message #f)))
     (define downloaded-path (hash-ref snapshot 'downloadedPath #f))
     (unless (string? downloaded-path)
       (fail "downloadedPath is not a string: ~a" downloaded-path))
     (hasheq 'mode "upgrade"
             'status "downloaded"
             'availableVersion (hash-ref snapshot 'availableVersion #f)
             'feedUrl (manifest-url)
             'downloadedPath downloaded-path
             'downloadedSha256 (sha256-file/hex downloaded-path)
             'percent (hash-ref snapshot 'percent #f))]))

(if output-json
    (call-with-output-file output-json
      (lambda (out) (write-json result out) (newline out))
      #:exists 'truncate)
    (begin (write-json result) (newline)))
