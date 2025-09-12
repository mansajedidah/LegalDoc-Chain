(define-constant contract-owner tx-sender)
(define-constant err-not-auth (err u100))
(define-constant err-limit (err u101))
(define-constant err-invalid-rating (err u102))

(define-constant max-genres u5)
(define-constant max-authors u5)
(define-constant catalog-cap u200)
(define-constant reco-cap u20)
(define-constant ttl-blocks u5000)

(define-data-var allowed-caller (optional principal) none)
(define-data-var catalog (list 200 uint) (list))

(define-map user-prefs principal
  { min-rating: uint, genres: (list 5 (string-ascii 32)), authors: (list 5 (string-ascii 32)) })
(define-map user-borrowed { user: principal, book-id: uint } bool)
(define-map book-meta uint { genre: (string-ascii 32), author: (string-ascii 32), rating: uint })
(define-map user-genre-count { user: principal, genre: (string-ascii 32) } uint)
(define-map user-author-count { user: principal, author: (string-ascii 32) } uint)
(define-map last-recos principal { block: uint, items: (list 20 uint) })
(define-map reco-stats principal { shown: uint, accepted: uint })

(define-private (is-allowed (user principal))
  (or (is-eq tx-sender user)
      (match (var-get allowed-caller) caller (is-eq tx-sender caller) false)))

(define-public (set-allowed-caller (caller principal))
  (begin 
    (asserts! (is-eq tx-sender contract-owner) err-not-auth)
    (ok (var-set allowed-caller (some caller)))))

(define-public (set-preferences (min-rating uint) (fav-genres (list 5 (string-ascii 32))) (fav-authors (list 5 (string-ascii 32))))
  (begin
    (asserts! (and (>= min-rating u0) (<= min-rating u100)) err-invalid-rating)
    (map-set user-prefs tx-sender { min-rating: min-rating, genres: fav-genres, authors: fav-authors })
    (ok true)))

(define-read-only (get-preferences (user principal))
  (default-to { min-rating: u0, genres: (list), authors: (list) } (map-get? user-prefs user)))


(define-private (not-borrowed (user principal) (book-id uint))
  (is-none (map-get? user-borrowed { user: user, book-id: book-id })))





(define-read-only (get-last-recommendations (user principal))
  (default-to { block: u0, items: (list) } (map-get? last-recos user)))

(define-read-only (get-book-metadata (book-id uint))
  (map-get? book-meta book-id))

(define-read-only (get-recommendation-stats (user principal))
  (default-to { shown: u0, accepted: u0 } (map-get? reco-stats user)))

(define-read-only (get-user-genre-count (user principal) (genre (string-ascii 32)))
  (default-to u0 (map-get? user-genre-count { user: user, genre: genre })))

(define-read-only (get-user-author-count (user principal) (author (string-ascii 32)))
  (default-to u0 (map-get? user-author-count { user: user, author: author })))

(define-read-only (get-catalog-size)
  (len (var-get catalog)))

(define-read-only (has-borrowed (user principal) (book-id uint))
  (is-some (map-get? user-borrowed { user: user, book-id: book-id })))
