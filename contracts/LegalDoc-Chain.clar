;; title: LegalDoc-Chain
;; version: 1.0
;; summary: Smart contract for legal document management
;; description: Enables law firms to store and verify legal documents with timestamping and access control

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-document-exists (err u101))
(define-constant err-document-not-found (err u102))

;; Data Maps
(define-map documents
    { doc-id: (string-ascii 36) }
    {
        owner: principal,
        hash: (string-ascii 64),
        timestamp: uint,
        version: uint
    }
)

(define-map document-access 
    { doc-id: (string-ascii 36), user: principal }
    { can-access: bool }
)

;; Public Functions
(define-public (store-document (doc-id (string-ascii 36)) (hash (string-ascii 64)))
    (let ((existing-doc (get-document doc-id)))
        (if (is-some existing-doc)
            err-document-exists
            (ok (map-set documents
                { doc-id: doc-id }
                {
                    owner: tx-sender,
                    hash: hash,
                    timestamp: stacks-block-height,
                    version: u1
                }
            ))
        )
    )
)

(define-public (update-document (doc-id (string-ascii 36)) (hash (string-ascii 64)))
    (let ((existing-doc (get-document doc-id)))
        (match existing-doc
            doc (if (is-eq (get owner doc) tx-sender)
                    (ok (map-set documents
                        { doc-id: doc-id }
                        {
                            owner: tx-sender,
                            hash: hash,
                            timestamp: stacks-block-height,
                            version: (+ (get version doc) u1)
                        }
                    ))
                    err-not-authorized)
            err-document-not-found
        )
    )
)

(define-public (grant-access (doc-id (string-ascii 36)) (user principal))
    (let ((existing-doc (get-document doc-id)))
        (match existing-doc
            doc (if (is-eq (get owner doc) tx-sender)
                    (ok (map-set document-access
                        { doc-id: doc-id, user: user }
                        { can-access: true }
                    ))
                    err-not-authorized)
            err-document-not-found
        )
    )
)

;; Read Only Functions
(define-read-only (get-document (doc-id (string-ascii 36)))
    (map-get? documents { doc-id: doc-id })
)

(define-read-only (can-access-document (doc-id (string-ascii 36)) (user principal))
    (let ((access-entry (map-get? document-access { doc-id: doc-id, user: user }))
          (doc (get-document doc-id)))
        (match doc
            existing-doc (or 
                (is-eq (get owner existing-doc) user)
                (match access-entry
                    entry (get can-access entry)
                    false
                )
            )
            false
        )
    )
)



;; Add to Data Maps
(define-map document-expiry 
    { doc-id: (string-ascii 36) }
    { expiry-height: uint }
)

;; New Public Function
(define-public (set-document-expiry (doc-id (string-ascii 36)) (expiry-blocks uint))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (ok (map-set document-expiry
                    { doc-id: doc-id }
                    { expiry-height: (+ stacks-block-height expiry-blocks) }))
                err-not-authorized)
            err-document-not-found
        )
    )
)



;; Add to Data Maps
(define-map document-categories
    { doc-id: (string-ascii 36) }
    { categories: (list 10 (string-ascii 20)) }
)

;; New Public Function
(define-public (add-document-categories (doc-id (string-ascii 36)) (categories (list 10 (string-ascii 20))))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (ok (map-set document-categories
                    { doc-id: doc-id }
                    { categories: categories }))
                err-not-authorized)
            err-document-not-found
        )
    )
)



;; Add to Data Maps
(define-map revoked-documents
    { doc-id: (string-ascii 36) }
    { is-revoked: bool, reason: (string-ascii 100) }
)

;; New Public Function
(define-public (revoke-document (doc-id (string-ascii 36)) (reason (string-ascii 100)))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (ok (map-set revoked-documents
                    { doc-id: doc-id }
                    { is-revoked: true, reason: reason }))
                err-not-authorized)
            err-document-not-found
        )
    )
)



;; Add to Data Maps
(define-map version-history
    { doc-id: (string-ascii 36), version: uint }
    { hash: (string-ascii 64), timestamp: uint, editor: principal }
)

;; Modify update-document function to store history
(define-public (store-version-history (doc-id (string-ascii 36)) (version uint) (hash (string-ascii 64)))
    (ok (map-set version-history
        { doc-id: doc-id, version: version }
        { hash: hash, timestamp: stacks-block-height, editor: tx-sender }
    ))
)



;; Add to Data Maps
(define-data-var next-log-id uint u0)

(define-map access-logs
    { doc-id: (string-ascii 36), log-id: uint }
    { user: principal, action: (string-ascii 20), timestamp: uint }
)

(define-private (get-next-log-id)
    (begin
        (var-set next-log-id (+ (var-get next-log-id) u1))
        (var-get next-log-id)
    )
)

;; New Public Function
(define-public (log-access (doc-id (string-ascii 36)) (action (string-ascii 20)))
    (ok (map-set access-logs
        { doc-id: doc-id, log-id: (get-next-log-id) }
        { user: tx-sender, action: action, timestamp: stacks-block-height }
    ))
)


;; Add to Data Maps
(define-map temporary-access
    { doc-id: (string-ascii 36), user: principal }
    { expiry-height: uint }
)

;; New Public Function
(define-public (grant-temporary-access (doc-id (string-ascii 36)) (user principal) (duration uint))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (ok (map-set temporary-access
                    { doc-id: doc-id, user: user }
                    { expiry-height: (+ stacks-block-height duration) }))
                err-not-authorized)
            err-document-not-found
        )
    )
)


;; Add to Data Maps
(define-map document-comments
    { doc-id: (string-ascii 36), comment-id: uint }
    { 
        author: principal,
        content: (string-ascii 500),
        timestamp: uint
    }
)

(define-data-var next-comment-id uint u0)

(define-private (get-next-comment-id)
    (begin
        (var-set next-comment-id (+ (var-get next-comment-id) u1))
        (var-get next-comment-id)
    )
)

(define-public (add-document-comment (doc-id (string-ascii 36)) (content (string-ascii 500)))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (can-access-document doc-id tx-sender)
                (ok (map-set document-comments
                    { doc-id: doc-id, comment-id: (get-next-comment-id) }
                    { author: tx-sender, content: content, timestamp: stacks-block-height }))
                err-not-authorized)
            err-document-not-found
        )
    )
)



(define-map groups 
    { group-id: uint }
    { 
        name: (string-ascii 50),
        owner: principal,
        members: (list 50 principal)
    }
)

(define-data-var next-group-id uint u0)

(define-public (create-group (name (string-ascii 50)))
    (let ((group-id (+ (var-get next-group-id) u1)))
        (begin
            (var-set next-group-id group-id)
            (ok (map-set groups
                { group-id: group-id }
                { name: name, owner: tx-sender, members: (list tx-sender) }))
        )
    )
)


(define-map document-tags
    { doc-id: (string-ascii 36) }
    { tags: (list 20 (string-ascii 20)) }
)

(define-public (add-document-tags (doc-id (string-ascii 36)) (tags (list 20 (string-ascii 20))))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (can-access-document doc-id tx-sender)
                (ok (map-set document-tags
                    { doc-id: doc-id }
                    { tags: tags }))
                err-not-authorized)
            err-document-not-found
        )
    )
)
(define-public (remove-document-tags (doc-id (string-ascii 36)) (tags (list 20 (string-ascii 20))))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (can-access-document doc-id tx-sender)
                (ok (map-set document-tags
                    { doc-id: doc-id }
                    { tags: tags }))
                err-not-authorized)
            err-document-not-found
        )
    )
)
(define-public (get-document-tags (doc-id (string-ascii 36)))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (ok (map-get? document-tags { doc-id: doc-id }))
            err-document-not-found
        )
    )
)
(define-public (get-group-members (group-id uint))
    (let ((group (map-get? groups { group-id: group-id })))
        (match group
            existing-group (ok (get members existing-group))
            err-document-not-found
        )
    )
)


(define-map document-priority
    { doc-id: (string-ascii 36) }
    { 
        level: uint,
        updated-at: uint
    }
)

(define-public (set-document-priority (doc-id (string-ascii 36)) (level uint))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (ok (map-set document-priority
                    { doc-id: doc-id }
                    { level: level, updated-at: stacks-block-height }))
                err-not-authorized)
            err-document-not-found
        )
    )
)


(define-map document-reviews
    { doc-id: (string-ascii 36), reviewer: principal }
    {
        status: (string-ascii 20),
        comments: (string-ascii 500),
        timestamp: uint
    }
)

(define-public (submit-review (doc-id (string-ascii 36)) (status (string-ascii 20)) (comments (string-ascii 500)))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (can-access-document doc-id tx-sender)
                (ok (map-set document-reviews
                    { doc-id: doc-id, reviewer: tx-sender }
                    { status: status, comments: comments, timestamp: stacks-block-height }))
                err-not-authorized)
            err-document-not-found
        )
    )
)



(define-map document-dependencies
    { doc-id: (string-ascii 36) }
    { dependent-docs: (list 10 (string-ascii 36)) }
)

(define-public (set-dependencies (doc-id (string-ascii 36)) (dependencies (list 10 (string-ascii 36))))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (ok (map-set document-dependencies
                    { doc-id: doc-id }
                    { dependent-docs: dependencies }))
                err-not-authorized)
            err-document-not-found
        )
    )
)



(define-map archived-documents
    { doc-id: (string-ascii 36) }
    {
        archive-date: uint,
        reason: (string-ascii 100),
        can-restore: bool
    }
)

(define-public (archive-document (doc-id (string-ascii 36)) (reason (string-ascii 100)))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (ok (map-set archived-documents
                    { doc-id: doc-id }
                    { archive-date: stacks-block-height, reason: reason, can-restore: true }))
                err-not-authorized)
            err-document-not-found
        )
    )
)
