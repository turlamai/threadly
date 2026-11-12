#lang racket/base

;; Parser tests against recorded forum responses (tests/fixtures/) — no
;; network. The fixtures are real racket.discourse.group payloads; if the
;; parser needs a new field, re-capture the fixture and extend the check.

(require json
         rackunit
         racket/list
         racket/runtime-path
         racket/string
         "../racket/core/discourse.rkt")

(define-runtime-path fixtures-dir "fixtures")

(define (load-fixture name)
  (call-with-input-file (build-path fixtures-dir name) read-json))

;; ---- parse-latest -----------------------------------------------------------

(test-case "parse-latest: topic_list.topics"
  (define topics (parse-latest (load-fixture "latest.json")))
  (check-true ((length topics) . > . 0) "fixture should contain topics")
  (define t (first topics))
  (check-true (exact-positive-integer? (topic-summary-id t)))
  (check-true (string? (topic-summary-title t)))
  (check-true ((string-length (topic-summary-title t)) . > . 0))
  (check-true (exact-nonnegative-integer? (topic-summary-posts-count t)))
  (check-true (exact-nonnegative-integer? (topic-summary-views t)))
  (check-true (string? (or (topic-summary-created-at t) ""))))

(test-case "parse-latest: rejects a non-object"
  (check-exn exn:fail? (lambda () (parse-latest '[1 2 3]))))

;; ---- parse-topic ------------------------------------------------------------

(test-case "parse-topic: topic + post stream"
  (define-values (topic posts) (parse-topic (load-fixture "topic.json")))
  (check-true (exact-positive-integer? (topic-summary-id topic)))
  (check-true ((length posts) . > . 0))
  (define p (first posts))
  (check-true (exact-positive-integer? (forum-post-id p)))
  (check-true ((string-length (forum-post-username p)) . > . 0))
  ;; cooked posts are HTML
  (check-true (string-contains? (forum-post-cooked p) "<"))
  ;; post numbering starts at 1
  (check-equal? (forum-post-post-number p) 1)
  ;; like state comes from actions_summary (the like action is id 2);
  ;; `acted` marks "you liked this" and only appears when signed in
  (check-equal? (forum-post-like-count p) 3)
  (check-true (forum-post-liked? p))
  (define q (second posts))
  (check-equal? (forum-post-like-count q) 1)
  (check-false (forum-post-liked? q)))

;; ---- parse-search -----------------------------------------------------------

(test-case "parse-search: top-level topics"
  (define results (parse-search (load-fixture "search.json")))
  (check-true ((length results) . > . 0) "fixture should contain hits")
  (define r (first results))
  (check-true (exact-positive-integer? (search-result-id r)))
  (check-true ((string-length (search-result-title r)) . > . 0)))

;; ---- parse-categories ---------------------------------------------------------

(test-case "parse-notifications: signed-in rows"
  (define ns (parse-notifications (load-fixture "notifications.json")))
  (check-equal? (length ns) 3)
  (define first-n (first ns))
  (check-equal? (notification-type-label 2) "reply")
  (check-false (forum-notification-read? first-n))
  (check-true ((forum-notification-topic-id first-n) . > . 0))
  (check-equal? (notification-type-label 5) "like")
  (check-equal? (notification-type-label 1) "mention")
  (check-equal? (notification-type-label 999) "notification"))

(test-case "parse-categories: category_list.categories"
  (define cats (parse-categories (load-fixture "categories.json")))
  (check-true ((length cats) . > . 0))
  (define c (first cats))
  (check-true (exact-positive-integer? (forum-category-id c)))
  (check-true ((string-length (forum-category-name c)) . > . 0)))

;; ---- fetch-category-topics shape (same topic_list as latest) -------------------

(test-case "parse-latest over a category page fixture"
  (define topics (parse-latest (load-fixture "category-general.json")))
  (check-true ((length topics) . > . 0))
  ;; a pinned welcome topic with no replies carries last_posted_at: null —
  ;; it must surface as #f, never the 'null symbol (which would fail the
  ;; RPC's (List (List String)) contract)
  (for ([t (in-list topics)])
    (check-true (or (string? (topic-summary-last-posted-at t))
                    (not (topic-summary-last-posted-at t)))
                "last-posted-at is a string or #f")))

;; ---- html->text ---------------------------------------------------------------

(test-case "html->text: tags and entities"
  (check-equal? (html->text "<p>a &amp; b</p>") "a & b")
  (check-equal? (html->text "1 &lt; 2 &gt; 0") "1 < 2 > 0")
  (check-equal? (html->text "<p>one</p><p>two</p>") "one\n\ntwo")
  (check-equal? (html->text "line<br>break") "line\nbreak")
  (check-equal? (html->text "x&nbsp;&hellip;y") "x …y"))

;; ---- fetch-topic-all ------------------------------------------------------------
;; The whole thread: the head comes from the cached /t/<id>.json, the rest
;; from post_ids[] batches that must carry every remaining id. A loopback
;; forum plays both endpoints and records each request line.

(require racket/file
         racket/string
         racket/tcp
         (file "../racket/core/paths.rkt")
         (only-in "../racket/core/cache.rkt" current-cache-ttl-seconds))

(define (read-request in)
  (define request-line (read-line in 'any))
  (let loop ()
    (define line (read-line in 'any))
    (unless (or (eof-object? line) (string=? line ""))
      (loop)))
  request-line)

;; accepts exactly one connection per response body, in order; each
;; request line is collected into the returned box (newest first)
(define (serve-jsons! listener responses)
  (define requests (box (list)))
  (define server
    (thread
     (lambda ()
       (for ([body (in-list responses)])
         (define-values (in out) (tcp-accept listener))
         (set-box! requests (cons (read-request in) (unbox requests)))
         (display
          (format "HTTP/1.1 200 OK\r\nContent-Type: application/json\r\nContent-Length: ~a\r\n\r\n~a"
                  (bytes-length (string->bytes/utf-8 body)) body)
          out)
         (close-input-port in)
         (close-output-port out))
       (tcp-close listener)))
    )
  (values server requests))

(define (post-json id number author)
  (format "{\"id\":~a,\"username\":\"~a\",\"cooked\":\"<p>post ~a</p>\",\"post_number\":~a,\"actions_summary\":[]}"
          id author id number))

(test-case "fetch-topic-all: batches the stream tail into post_ids[] calls"
  (define (open-loopback-listener)
    (let loop ([tries 20])
      (define p (+ 20000 (random 40000)))
      (with-handlers ([exn:fail?
                       (lambda (_)
                         (when (zero? tries) (error 'discourse-test "no free port"))
                         (loop (sub1 tries)))])
        (values (tcp-listen p 4 #f "127.0.0.1") p))))
  (define-values (listener port) (open-loopback-listener))
  (define head
    (format "{\"id\":4416,\"title\":\"Long thread\",\"posts_count\":5,\"post_stream\":{\"posts\":[~a,~a],\"stream\":[11,12,13,14,15]}}"
            (post-json 11 1 "alice") (post-json 12 2 "bob")))
  (define batch-1
    (format "{\"post_stream\":{\"posts\":[~a,~a]}}"
            (post-json 13 3 "carol") (post-json 14 4 "dave")))
  (define batch-2 (format "{\"post_stream\":{\"posts\":[~a]}}" (post-json 15 5 "erin")))
  (define-values (server requests)
    (serve-jsons! listener (list head batch-1 batch-2)))
  (define-values (topic posts)
    (parameterize ([current-forum-base-url (format "http://127.0.0.1:~a" port)]
                   [current-data-dir (make-temporary-file "threadly-all-~a" 'directory)]
                   [current-cache-ttl-seconds 300]
                   [fetch-topic-all-batch-size 2])
      (fetch-topic-all 4416)))
  (sync/timeout 5 server)

  (check-equal? (topic-summary-posts-count topic) 5)
  (check-equal? (map forum-post-post-number posts) (list 1 2 3 4 5)
                "stream order preserved across the batches")
  (check-equal? (map forum-post-id posts) (list 11 12 13 14 15))

  (define lines (reverse (unbox requests)))
  (check-equal? (length lines) 3 "one head fetch plus two batches of ≤2")
  (check-true (string-contains? (first lines) "GET /t/4416.json"))
  (check-true (string-contains? (second lines)
                                "GET /t/4416/posts.json?post_ids[]=13&post_ids[]=14")
              (string-append "first batch carries two ids; got: " (second lines)))
  (check-true (string-contains? (third lines)
                                "GET /t/4416/posts.json?post_ids[]=15")
              "second batch carries the remainder"))

;; ---- fetch-topic-posts-page ---------------------------------------------------
;; The reader's next batch: the host's loaded count indexes into the
;; cached topic doc's stream; each call fetches exactly one ≤batch slice
;; past it. Empty list at the end; negative counts clamp to zero.

(test-case "fetch-topic-posts-page: pages by loaded-count, ends empty"
  (define (open-loopback-listener)
    (let loop ([tries 20])
      (define p (+ 20000 (random 40000)))
      (with-handlers ([exn:fail?
                       (lambda (_)
                         (when (zero? tries) (error 'discourse-test "no free port"))
                         (loop (sub1 tries)))])
        (values (tcp-listen p 4 #f "127.0.0.1") p))))
  (define-values (listener port) (open-loopback-listener))
  (define head
    (format "{\"id\":4417,\"title\":\"Paged thread\",\"posts_count\":5,\"post_stream\":{\"posts\":[~a,~a],\"stream\":[21,22,23,24,25]}}"
            (post-json 21 1 "alice") (post-json 22 2 "bob")))
  (define slice-1
    (format "{\"post_stream\":{\"posts\":[~a,~a]}}"
            (post-json 23 3 "carol") (post-json 24 4 "dave")))
  (define slice-2 (format "{\"post_stream\":{\"posts\":[~a]}}" (post-json 25 5 "erin")))
  (define slice-0
    (format "{\"post_stream\":{\"posts\":[~a,~a]}}"
            (post-json 21 1 "alice") (post-json 22 2 "bob")))
  (define-values (server requests)
    (serve-jsons! listener (list head slice-1 slice-2 slice-0)))
  ;; one shared data dir: the topic doc must come from cache after the
  ;; first page call — only the posts.json slices hit the wire again
  (define data-dir (make-temporary-file "threadly-page-~a" 'directory))
  (define (page loaded-count)
    (parameterize ([current-forum-base-url (format "http://127.0.0.1:~a" port)]
                   [current-data-dir data-dir]
                   [current-cache-ttl-seconds 300]
                   [fetch-topic-all-batch-size 2])
      (fetch-topic-posts-page 4417 loaded-count)))
  (define-values (posts-1 total-1) (page 2))
  (define-values (posts-2 total-2) (page 4))
  (define-values (posts-3 total-3) (page 5))
  (define-values (posts-4 total-4) (page -3))
  (sync/timeout 5 server)

  (check-equal? (map forum-post-post-number posts-1) (list 3 4) "the two ids past the loaded count")
  (check-equal? total-1 5)
  (check-equal? (map forum-post-post-number posts-2) (list 5) "short final slice")
  (check-equal? posts-3 (list) "at the end of the stream: empty, no fetch")
  (check-equal? (map forum-post-post-number posts-4) (list 1 2) "negative counts clamp to zero")

  (define lines (reverse (unbox requests)))
  ;; head (cached after the first page call) + one posts.json per
  ;; non-empty page; the end-of-stream call performs no request at all
  (check-equal? (length lines) 4 "head + slice-1 + slice-2 + slice-0")
  (check-true (string-contains? (second lines) "post_ids[]=23&post_ids[]=24"))
  (check-true (string-contains? (third lines) "post_ids[]=25"))
  (check-true (string-contains? (fourth lines) "post_ids[]=21&post_ids[]=22")))
