#lang racket/base

(provide unify
         replace-occur
         make-subst
         subst-resolve)

(require racket/syntax
         racket/match
         "subst.rkt")

(define (full-expand exp occurs)
  (match exp
    [`(,e* ...)
     (map (λ (e) (full-expand e occurs)) e*)]
    [v (let ([new-v (hash-ref occurs v #f)])
         (if new-v (full-expand new-v occurs) v))]))
(define (unify exp act
               stx precise-stx
               #:subst [subst (make-subst)]
               #:solve? [solve? #t])
  (match* {exp act}
    [{(? freevar?) _} (subst-set! precise-stx subst exp act)]
    [{_ (? freevar?)} (unify act exp
                             stx precise-stx
                             #:subst subst #:solve? solve?)]
    [{`(,t1* ...) `(,t2* ...)}
     (unless (= (length t1*) (length t2*))
       (raise-syntax-error 'semantic (format "cannot unify `~a` and `~a`" exp act)
                           stx
                           precise-stx))
     (map (λ (t1 t2) (unify t1 t2
                            stx precise-stx
                            #:subst subst #:solve? solve?))
          t1* t2*)]
    [{_ _} (unless (equal? exp act)
             (raise-syntax-error 'semantic
                                 (format "type mismatched, expected: ~a, but got: ~a" exp act)
                                 stx
                                 precise-stx))])
  (if solve?
      (full-expand exp (subst-resolve subst stx))
      exp))
(define (replace-occur target #:occur occurs)
  (match target
    [`(,e* ...)
     (map (λ (e) (replace-occur e #:occur occurs)) e*)]
    [v (let ([new-v (hash-ref occurs v #f)])
         (if new-v new-v v))]))