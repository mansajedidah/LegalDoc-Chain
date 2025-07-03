;; title: LegalDoc-Chain
;; version: 1.0
;; summary: Smart contract for legal document management
;; description: Enables law firms to store and verify legal documents with timestamping and access control

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-document-exists (err u101))
(define-constant err-document-not-found (err u102))


(define-constant err-signature-exists (err u103))
(define-constant err-signature-not-required (err u104))
(define-constant err-invalid-signature-order (err u105))
(define-constant err-document-already-signed (err u106))


(define-constant err-notarization-exists (err u200))
(define-constant err-notarization-not-found (err u201))
(define-constant err-witness-already-verified (err u202))
(define-constant err-insufficient-witnesses (err u203))
(define-constant err-notarization-expired (err u204))
(define-constant err-dispute-exists (err u205))
(define-constant err-insufficient-fee (err u206))
(define-constant err-witness-not-qualified (err u207))

(define-constant notarization-fee u100)
(define-constant witness-reward u20)
(define-constant min-witnesses u2)
(define-constant max-witnesses u5)
(define-constant notarization-validity-blocks u144000)

(define-map notarization-requests
    { doc-id: (string-ascii 36) }
    {
        requester: principal,
        requested-at: uint,
        expires-at: uint,
        witnesses-required: uint,
        fee-paid: uint,
        status: (string-ascii 20)
    }
)

(define-map witness-qualifications
    { witness: principal }
    {
        verified: bool,
        reputation-score: uint,
        total-notarizations: uint,
        successful-disputes: uint
    }
)

(define-map notarization-witnesses
    { doc-id: (string-ascii 36), witness: principal }
    {
        verified-at: uint,
        witness-signature: (string-ascii 64),
        witness-statement: (string-ascii 200)
    }
)

(define-map completed-notarizations
    { doc-id: (string-ascii 36) }
    {
        notarized-at: uint,
        notary-seal: (string-ascii 64),
        witness-count: uint,
        valid-until: uint,
        certificate-hash: (string-ascii 64)
    }
)

(define-map notarization-disputes
    { doc-id: (string-ascii 36) }
    {
        disputed-by: principal,
        disputed-at: uint,
        dispute-reason: (string-ascii 300),
        resolution-status: (string-ascii 20),
        resolved-at: (optional uint)
    }
)

(define-data-var contract-balance uint u0)

(define-map document-signature-requirements
    { doc-id: (string-ascii 36) }
    {
        required-signers: (list 10 principal),
        require-order: bool,
        deadline: uint,
        created-by: principal
    }
)

(define-map document-signatures
    { doc-id: (string-ascii 36), signer: principal }
    {
        signature-hash: (string-ascii 64),
        signed-at: uint,
        signature-order: uint
    }
)

(define-map signature-status
    { doc-id: (string-ascii 36) }
    {
        total-required: uint,
        total-signed: uint,
        is-complete: bool,
        completed-at: (optional uint)
    }
)


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



(define-map document-workflow-states
    { doc-id: (string-ascii 36) }
    {
        current-state: (string-ascii 20),
        last-updated: uint,
        updated-by: principal
    }
)

(define-constant valid-states (list 
    "draft"
    "review"
    "approved" 
    "executed"
    "rejected"
))

(define-read-only (is-valid-state (state (string-ascii 8)))
    (is-some (index-of valid-states state))
)

(define-public (update-document-state (doc-id (string-ascii 36)) (new-state (string-ascii 8)))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (and 
                    (can-access-document doc-id tx-sender)
                    (is-valid-state new-state))
                (ok (map-set document-workflow-states
                    { doc-id: doc-id }
                    {
                        current-state: new-state,
                        last-updated: stacks-block-height,
                        updated-by: tx-sender
                    }))
                err-not-authorized)
            err-document-not-found
        )
    )
)



(define-map sharing-links
    { link-id: (string-ascii 64) }
    {
        doc-id: (string-ascii 36),
        creator: principal,
        expiry: uint,
        uses-left: uint
    }
)

(define-public (create-sharing-link 
    (doc-id (string-ascii 36)) 
    (link-id (string-ascii 64))
    (expiry-blocks uint)
    (max-uses uint))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (can-access-document doc-id tx-sender)
                (ok (map-set sharing-links
                    { link-id: link-id }
                    {
                        doc-id: doc-id,
                        creator: tx-sender,
                        expiry: (+ stacks-block-height expiry-blocks),
                        uses-left: max-uses
                    }))
                err-not-authorized)
            err-document-not-found
        )
    )
)

(define-read-only (validate-sharing-link (link-id (string-ascii 64)))
    (let ((link-data (map-get? sharing-links { link-id: link-id })))
        (match link-data
            link (if (and
                    (> (get expiry link) stacks-block-height)
                    (> (get uses-left link) u0))
                (ok true)
                (err u403))
            (err u404)
        )
    )
)


(define-public (register-witness (witness principal))
    (ok (map-set witness-qualifications
        { witness: witness }
        {
            verified: true,
            reputation-score: u100,
            total-notarizations: u0,
            successful-disputes: u0
        }))
)

(define-public (request-notarization (doc-id (string-ascii 36)) (witnesses-needed uint))
    (let ((doc (get-document doc-id))
          (existing-request (map-get? notarization-requests { doc-id: doc-id })))
        (if (is-some existing-request)
            err-notarization-exists
            (match doc
                existing-doc (if (and
                        (is-eq (get owner existing-doc) tx-sender)
                        (>= witnesses-needed min-witnesses)
                        (<= witnesses-needed max-witnesses))
                    (begin
                        (try! (stx-transfer? notarization-fee tx-sender (as-contract tx-sender)))
                        (var-set contract-balance (+ (var-get contract-balance) notarization-fee))
                        (ok (map-set notarization-requests
                            { doc-id: doc-id }
                            {
                                requester: tx-sender,
                                requested-at: stacks-block-height,
                                expires-at: (+ stacks-block-height u1440),
                                witnesses-required: witnesses-needed,
                                fee-paid: notarization-fee,
                                status: "pending"
                            })))
                    err-not-authorized)
                err-document-not-found)
        )
    )
)

(define-public (witness-verify (doc-id (string-ascii 36)) (witness-signature (string-ascii 64)) (statement (string-ascii 200)))
    (let ((request (map-get? notarization-requests { doc-id: doc-id }))
          (witness-qual (map-get? witness-qualifications { witness: tx-sender }))
          (existing-witness (map-get? notarization-witnesses { doc-id: doc-id, witness: tx-sender })))
        (if (is-some existing-witness)
            err-witness-already-verified
            (match request
                req (if (< stacks-block-height (get expires-at req))
                    (match witness-qual
                        qual (if (get verified qual)
                            (ok (map-set notarization-witnesses
                                { doc-id: doc-id, witness: tx-sender }
                                {
                                    verified-at: stacks-block-height,
                                    witness-signature: witness-signature,
                                    witness-statement: statement
                                }))
                            err-witness-not-qualified)
                        err-witness-not-qualified)
                    err-notarization-expired)
                err-notarization-not-found)
        )
    )
)

(define-public (complete-notarization (doc-id (string-ascii 36)) (notary-seal (string-ascii 64)) (certificate-hash (string-ascii 64)))
    (let ((request (map-get? notarization-requests { doc-id: doc-id }))
          (witness-count (count-witnesses doc-id)))
        (match request
            req (if (and
                    (is-eq (get requester req) tx-sender)
                    (>= witness-count (get witnesses-required req)))
                (begin
                    (map-set notarization-requests
                        { doc-id: doc-id }
                        {
                            requester: (get requester req),
                            requested-at: (get requested-at req),
                            expires-at: (get expires-at req),
                            witnesses-required: (get witnesses-required req),
                            fee-paid: (get fee-paid req),
                            status: "completed"
                        })
                    (map-set completed-notarizations
                        { doc-id: doc-id }
                        {
                            notarized-at: stacks-block-height,
                            notary-seal: notary-seal,
                            witness-count: witness-count,
                            valid-until: (+ stacks-block-height notarization-validity-blocks),
                            certificate-hash: certificate-hash
                        })
                    (ok (distribute-witness-rewards doc-id)))
                err-insufficient-witnesses)
            err-notarization-not-found)
    )
)

(define-public (dispute-notarization (doc-id (string-ascii 36)) (reason (string-ascii 300)))
    (let ((notarization (map-get? completed-notarizations { doc-id: doc-id }))
          (existing-dispute (map-get? notarization-disputes { doc-id: doc-id })))
        (if (is-some existing-dispute)
            err-dispute-exists
            (match notarization
                notary (if (< stacks-block-height (get valid-until notary))
                    (ok (map-set notarization-disputes
                        { doc-id: doc-id }
                        {
                            disputed-by: tx-sender,
                            disputed-at: stacks-block-height,
                            dispute-reason: reason,
                            resolution-status: "pending",
                            resolved-at: none
                        }))
                    err-notarization-expired)
                err-notarization-not-found)
        )
    )
)

(define-private (count-witnesses (doc-id (string-ascii 36)))
    (let ((witness-list (get-all-witnesses doc-id)))
        (len witness-list)
    )
)

(define-private (get-all-witnesses (doc-id (string-ascii 36)))
    (list)
)

(define-private (distribute-witness-rewards (doc-id (string-ascii 36)))
    (let ((total-reward (* witness-reward (count-witnesses doc-id))))
        (if (>= (var-get contract-balance) total-reward)
            (begin
                (var-set contract-balance (- (var-get contract-balance) total-reward))
                true)
            false)
    )
)

(define-read-only (get-notarization-request (doc-id (string-ascii 36)))
    (map-get? notarization-requests { doc-id: doc-id })
)

(define-read-only (get-notarization-certificate (doc-id (string-ascii 36)))
    (map-get? completed-notarizations { doc-id: doc-id })
)

(define-read-only (is-document-notarized (doc-id (string-ascii 36)))
    (match (map-get? completed-notarizations { doc-id: doc-id })
        cert (< stacks-block-height (get valid-until cert))
        false
    )
)

(define-read-only (get-witness-verification (doc-id (string-ascii 36)) (witness principal))
    (map-get? notarization-witnesses { doc-id: doc-id, witness: witness })
)

(define-read-only (get-notarization-dispute (doc-id (string-ascii 36)))
    (map-get? notarization-disputes { doc-id: doc-id })
)

(define-read-only (get-witness-qualifications (witness principal))
    (map-get? witness-qualifications { witness: witness })
)

(define-read-only (calculate-notarization-cost (witnesses-needed uint))
    (+ notarization-fee (* witness-reward witnesses-needed))
)


(define-public (use-sharing-link (link-id (string-ascii 64)))
    (let ((link-data (map-get? sharing-links { link-id: link-id })))
        (match link-data
            link (if (and
                    (> (get expiry link) stacks-block-height)
                    (> (get uses-left link) u0))
                (begin
                    (map-set sharing-links
                        { link-id: link-id }
                        {
                            doc-id: (get doc-id link),
                            creator: (get creator link),
                            expiry: (get expiry link),
                            uses-left: (- (get uses-left link) u1)
                        })
                    (ok true))
                (err u403))
            (err u404)
        )
    )
)


(define-public (get-sharing-link-doc (link-id (string-ascii 64)))
    (let ((link-data (map-get? sharing-links { link-id: link-id })))
        (match link-data
            link (if (> (get expiry link) stacks-block-height)
                (ok (get doc-id link))
                (err u403))
            (err u404)
        )
    )
)


;; Public Functions
(define-public (setup-signature-requirements 
    (doc-id (string-ascii 36))
    (required-signers (list 10 principal))
    (require-order bool)
    (deadline-blocks uint))
    (let ((doc (get-document doc-id)))
        (match doc
            existing-doc (if (is-eq (get owner existing-doc) tx-sender)
                (begin
                    (map-set document-signature-requirements
                        { doc-id: doc-id }
                        {
                            required-signers: required-signers,
                            require-order: require-order,
                            deadline: (+ stacks-block-height deadline-blocks),
                            created-by: tx-sender
                        })
                    (ok (map-set signature-status
                        { doc-id: doc-id }
                        {
                            total-required: (len required-signers),
                            total-signed: u0,
                            is-complete: false,
                            completed-at: none
                        })))
                err-not-authorized)
            err-document-not-found
        )
    )
)

(define-public (sign-document (doc-id (string-ascii 36)) (signature-hash (string-ascii 64)))
    (let ((requirements (map-get? document-signature-requirements { doc-id: doc-id }))
          (existing-signature (map-get? document-signatures { doc-id: doc-id, signer: tx-sender }))
          (current-status (map-get? signature-status { doc-id: doc-id })))
        (if (is-some existing-signature)
            err-signature-exists
            (match requirements
                reqs (if (is-some (index-of (get required-signers reqs) tx-sender))
                    (match current-status
                        status (let ((new-signed-count (+ (get total-signed status) u1))
                                   (is-now-complete (is-eq new-signed-count (get total-required status))))
                            (begin
                                (map-set document-signatures
                                    { doc-id: doc-id, signer: tx-sender }
                                    {
                                        signature-hash: signature-hash,
                                        signed-at: stacks-block-height,
                                        signature-order: new-signed-count
                                    })
                                (ok (map-set signature-status
                                    { doc-id: doc-id }
                                    {
                                        total-required: (get total-required status),
                                        total-signed: new-signed-count,
                                        is-complete: is-now-complete,
                                        completed-at: (if is-now-complete (some stacks-block-height) none)
                                    }))))
                        err-document-not-found)
                    err-not-authorized)
                err-signature-not-required)
        )
    )
)

(define-public (revoke-signature (doc-id (string-ascii 36)))
    (let ((existing-signature (map-get? document-signatures { doc-id: doc-id, signer: tx-sender }))
          (current-status (map-get? signature-status { doc-id: doc-id })))
        (match existing-signature
            signature (match current-status
                status (begin
                    (map-delete document-signatures { doc-id: doc-id, signer: tx-sender })
                    (ok (map-set signature-status
                        { doc-id: doc-id }
                        {
                            total-required: (get total-required status),
                            total-signed: (- (get total-signed status) u1),
                            is-complete: false,
                            completed-at: none
                        })))
                err-document-not-found)
            err-document-not-found
        )
    )
)

;; Read-Only Functions
(define-read-only (get-signature-requirements (doc-id (string-ascii 36)))
    (map-get? document-signature-requirements { doc-id: doc-id })
)

(define-read-only (get-document-signature (doc-id (string-ascii 36)) (signer principal))
    (map-get? document-signatures { doc-id: doc-id, signer: signer })
)

(define-read-only (get-signature-status (doc-id (string-ascii 36)))
    (map-get? signature-status { doc-id: doc-id })
)

(define-read-only (is-document-fully-signed (doc-id (string-ascii 36)))
    (match (map-get? signature-status { doc-id: doc-id })
        status (get is-complete status)
        false
    )
)

(define-read-only (has-user-signed (doc-id (string-ascii 36)) (user principal))
    (is-some (map-get? document-signatures { doc-id: doc-id, signer: user }))
)

(define-read-only (get-pending-signers (doc-id (string-ascii 36)))
    (match (map-get? document-signature-requirements { doc-id: doc-id })
        reqs (ok (filter check-unsigned-status (get required-signers reqs)))
        err-document-not-found
    )
)

(define-private (check-unsigned-status (signer principal))
    (not (has-user-signed "temp-doc-id" signer))
)