;; title: LegalDoc Templates
;; version: 1.0
;; summary: Legal document template management system
;; description: Enables law firms to create, manage, and share standardized legal document templates

;; Constants
(define-constant contract-owner tx-sender)
(define-constant err-not-authorized (err u100))
(define-constant err-template-exists (err u200))
(define-constant err-template-not-found (err u201))
(define-constant err-invalid-category (err u202))
(define-constant err-invalid-status (err u203))
(define-constant err-template-not-approved (err u204))
(define-constant err-usage-limit-exceeded (err u205))

;; Valid template categories
(define-constant valid-categories (list 
    "contract"
    "nda"
    "agreement"
    "lease"
    "employment"
    "intellectual-property"
    "corporate"
    "litigation"
    "real-estate"
    "other"
))

;; Valid template statuses
(define-constant valid-statuses (list
    "draft"
    "under-review"
    "approved"
    "deprecated"
    "archived"
))

;; Template registry - stores template metadata and content
(define-map legal-templates
    { template-id: (string-ascii 36) }
    {
        name: (string-ascii 100),
        description: (string-ascii 300),
        category: (string-ascii 20),
        content-hash: (string-ascii 64),
        creator: principal,
        created-at: uint,
        last-modified: uint,
        version: uint,
        status: (string-ascii 15),
        usage-count: uint,
        max-usage: (optional uint)
    }
)

;; Template versions - track template history
(define-map template-versions
    { template-id: (string-ascii 36), version: uint }
    {
        content-hash: (string-ascii 64),
        modified-by: principal,
        modified-at: uint,
        change-notes: (string-ascii 200)
    }
)

;; Template approvals - track approval workflow
(define-map template-approvals
    { template-id: (string-ascii 36) }
    {
        approved-by: principal,
        approved-at: uint,
        approval-notes: (string-ascii 200),
        expiry-date: (optional uint)
    }
)

;; Template usage tracking
(define-map template-usage
    { template-id: (string-ascii 36), usage-id: uint }
    {
        used-by: principal,
        used-at: uint,
        document-id: (string-ascii 36),
        purpose: (string-ascii 100)
    }
)

;; Template favorites for users
(define-map user-favorites
    { user: principal, template-id: (string-ascii 36) }
    { favorited-at: uint }
)

;; Template access permissions
(define-map template-permissions
    { template-id: (string-ascii 36), user: principal }
    {
        can-view: bool,
        can-edit: bool,
        can-approve: bool,
        granted-by: principal,
        granted-at: uint
    }
)

;; Data variables
(define-data-var next-usage-id uint u0)

;; Helper functions
(define-read-only (is-valid-category (category (string-ascii 20)))
    (is-some (index-of valid-categories category))
)

(define-read-only (is-valid-status (status (string-ascii 12)))
    (is-some (index-of valid-statuses status))
)

(define-private (get-next-usage-id)
    (begin
        (var-set next-usage-id (+ (var-get next-usage-id) u1))
        (var-get next-usage-id)
    )
)

;; Public functions

;; Create a new template
(define-public (create-template 
    (template-id (string-ascii 36))
    (name (string-ascii 100))
    (description (string-ascii 300))
    (category (string-ascii 20))
    (content-hash (string-ascii 64))
    (max-usage (optional uint)))
    (let ((existing-template (map-get? legal-templates { template-id: template-id })))
        (if (is-some existing-template)
            err-template-exists
            (if (not (is-valid-category category))
                err-invalid-category
                (begin
                    (map-set legal-templates
                        { template-id: template-id }
                        {
                            name: name,
                            description: description,
                            category: category,
                            content-hash: content-hash,
                            creator: tx-sender,
                            created-at: stacks-block-height,
                            last-modified: stacks-block-height,
                            version: u1,
                            status: "draft",
                            usage-count: u0,
                            max-usage: max-usage
                        }
                    )
                    (map-set template-versions
                        { template-id: template-id, version: u1 }
                        {
                            content-hash: content-hash,
                            modified-by: tx-sender,
                            modified-at: stacks-block-height,
                            change-notes: "Initial template creation"
                        }
                    )
                    (ok true)
                )
            )
        )
    )
)

;; Update existing template
(define-public (update-template
    (template-id (string-ascii 36))
    (content-hash (string-ascii 64))
    (change-notes (string-ascii 200)))
    (let ((template (map-get? legal-templates { template-id: template-id })))
        (match template
            existing-template 
                (if (or (is-eq (get creator existing-template) tx-sender)
                        (has-edit-permission template-id tx-sender))
                    (let ((new-version (+ (get version existing-template) u1)))
                        (map-set legal-templates
                            { template-id: template-id }
                            (merge existing-template {
                                content-hash: content-hash,
                                last-modified: stacks-block-height,
                                version: new-version,
                                status: "draft"
                            })
                        )
                        (map-set template-versions
                            { template-id: template-id, version: new-version }
                            {
                                content-hash: content-hash,
                                modified-by: tx-sender,
                                modified-at: stacks-block-height,
                                change-notes: change-notes
                            }
                        )
                        (ok new-version)
                    )
                    err-not-authorized)
            err-template-not-found
        )
    )
)

;; Approve template
(define-public (approve-template
    (template-id (string-ascii 36))
    (approval-notes (string-ascii 200))
    (expiry-blocks (optional uint)))
    (let ((template (map-get? legal-templates { template-id: template-id })))
        (match template
            existing-template
                (if (has-approval-permission template-id tx-sender)
                    (begin
                        (map-set legal-templates
                            { template-id: template-id }
                            (merge existing-template { status: "approved" })
                        )
                        (map-set template-approvals
                            { template-id: template-id }
                            {
                                approved-by: tx-sender,
                                approved-at: stacks-block-height,
                                approval-notes: approval-notes,
                                expiry-date: (match expiry-blocks
                                    blocks (some (+ stacks-block-height blocks))
                                    none)
                            }
                        )
                        (ok true)
                    )
                    err-not-authorized)
            err-template-not-found
        )
    )
)

;; Use template to create document
(define-public (use-template
    (template-id (string-ascii 36))
    (document-id (string-ascii 36))
    (purpose (string-ascii 100)))
    (let ((template (map-get? legal-templates { template-id: template-id })))
        (match template
            existing-template
                (if (is-eq (get status existing-template) "approved")
                    (if (or (is-none (get max-usage existing-template))
                            (< (get usage-count existing-template) 
                               (unwrap-panic (get max-usage existing-template))))
                        (let ((usage-id (get-next-usage-id)))
                            (map-set legal-templates
                                { template-id: template-id }
                                (merge existing-template {
                                    usage-count: (+ (get usage-count existing-template) u1)
                                })
                            )
                            (map-set template-usage
                                { template-id: template-id, usage-id: usage-id }
                                {
                                    used-by: tx-sender,
                                    used-at: stacks-block-height,
                                    document-id: document-id,
                                    purpose: purpose
                                }
                            )
                            (ok usage-id)
                        )
                        err-usage-limit-exceeded)
                    err-template-not-approved)
            err-template-not-found
        )
    )
)

;; Add template to favorites
(define-public (favorite-template (template-id (string-ascii 36)))
    (let ((template (map-get? legal-templates { template-id: template-id })))
        (if (is-some template)
            (ok (map-set user-favorites
                { user: tx-sender, template-id: template-id }
                { favorited-at: stacks-block-height }
            ))
            err-template-not-found
        )
    )
)

;; Grant template permissions
(define-public (grant-template-permission
    (template-id (string-ascii 36))
    (user principal)
    (can-view bool)
    (can-edit bool)
    (can-approve bool))
    (let ((template (map-get? legal-templates { template-id: template-id })))
        (match template
            existing-template
                (if (is-eq (get creator existing-template) tx-sender)
                    (ok (map-set template-permissions
                        { template-id: template-id, user: user }
                        {
                            can-view: can-view,
                            can-edit: can-edit,
                            can-approve: can-approve,
                            granted-by: tx-sender,
                            granted-at: stacks-block-height
                        }
                    ))
                    err-not-authorized)
            err-template-not-found
        )
    )
)

;; Read-only functions

(define-read-only (get-template (template-id (string-ascii 36)))
    (map-get? legal-templates { template-id: template-id })
)

(define-read-only (get-template-version (template-id (string-ascii 36)) (version uint))
    (map-get? template-versions { template-id: template-id, version: version })
)

(define-read-only (get-template-approval (template-id (string-ascii 36)))
    (map-get? template-approvals { template-id: template-id })
)

(define-read-only (is-template-approved (template-id (string-ascii 36)))
    (match (map-get? legal-templates { template-id: template-id })
        template (is-eq (get status template) "approved")
        false
    )
)

(define-read-only (has-edit-permission (template-id (string-ascii 36)) (user principal))
    (match (map-get? template-permissions { template-id: template-id, user: user })
        permissions (get can-edit permissions)
        false
    )
)

(define-read-only (has-approval-permission (template-id (string-ascii 36)) (user principal))
    (or (is-eq tx-sender contract-owner)
        (match (map-get? template-permissions { template-id: template-id, user: user })
            permissions (get can-approve permissions)
            false
        )
    )
)

(define-read-only (get-template-usage-stats (template-id (string-ascii 36)))
    (match (map-get? legal-templates { template-id: template-id })
        template (some {
            usage-count: (get usage-count template),
            max-usage: (get max-usage template),
            remaining-usage: (match (get max-usage template)
                max-uses (some (- max-uses (get usage-count template)))
                none)
        })
        none
    )
)

(define-read-only (is-user-favorite (user principal) (template-id (string-ascii 36)))
    (is-some (map-get? user-favorites { user: user, template-id: template-id }))
)
