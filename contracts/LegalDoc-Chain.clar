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
