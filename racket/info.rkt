#lang info

(define name "threadly")
(define collection 'multi)
;; Direct requires only: backend.rkt and schema.rkt ride on rivet/backend,
;; update.rkt on rivet/distribution + crypto + net/url, core/http.rkt and
;; auth.rkt on net/* (net-lib). json and racket/* live in base.
;; Naming follows rivet's own info.rkt (runtime "-lib" packages).
(define deps '("base"
               "crypto-lib"
               "net-lib"
               "rivet"))
(define build-deps '("rackunit-lib"))
(define pkg-desc "Threadly Racket engine: Discourse client core, RVT1 backend and updater")
(define version "0.15.0")
(define pkg-authors '("turlamai"))
