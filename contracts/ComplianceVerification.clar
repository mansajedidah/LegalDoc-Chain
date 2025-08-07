;; title: Document Compliance Verification System
;; version: 1.0
;; summary: Regulatory compliance verification for legal documents
;; description: Enables verification of documents against regulatory frameworks and compliance standards

;; Constants for compliance system
(define-constant err-not-authorized (err u100))
(define-constant err-compliance-framework-exists (err u300))
(define-constant err-compliance-framework-not-found (err u301))
(define-constant err-compliance-requirement-exists (err u302))
(define-constant err-compliance-requirement-not-found (err u303))
(define-constant err-compliance-assessment-exists (err u304))
(define-constant err-compliance-assessment-not-found (err u305))
(define-constant err-invalid-compliance-status (err u306))
(define-constant err-compliance-deadline-passed (err u307))
(define-constant err-insufficient-verification-score (err u308))

;; Compliance framework registry - stores regulatory frameworks like GDPR, HIPAA, SOX
(define-map compliance-frameworks
    { framework-id: (string-ascii 20) }
    {
        name: (string-ascii 100),
        description: (string-ascii 300),
        jurisdiction: (string-ascii 50),
        created-by: principal,
        created-at: uint,
        active: bool
    }
)

;; Compliance requirements within each framework
(define-map compliance-requirements
    { framework-id: (string-ascii 20), requirement-id: (string-ascii 30) }
    {
        title: (string-ascii 150),
        description: (string-ascii 500),
        mandatory: bool,
        verification-criteria: (string-ascii 300),
        penalty-level: uint, ;; 1=low, 2=medium, 3=high, 4=critical
        created-at: uint
    }
)

;; Document compliance assessments - tracks compliance status per document
(define-map document-compliance
    { doc-id: (string-ascii 36), framework-id: (string-ascii 20) }
    {
        assessment-status: (string-ascii 15), ;; "pending", "compliant", "non-compliant", "partial"
        compliance-score: uint, ;; 0-100 percentage
        assessed-by: principal,
        assessed-at: uint,
        next-review-due: uint,
        critical-issues: uint,
        notes: (string-ascii 400)
    }
)

;; Individual requirement compliance for each document
(define-map requirement-compliance
    { doc-id: (string-ascii 36), framework-id: (string-ascii 20), requirement-id: (string-ascii 30) }
    {
        compliant: bool,
        verification-evidence: (string-ascii 200),
        verified-by: principal,
        verified-at: uint,
        expiry-date: (optional uint)
    }
)

;; Compliance audit log for tracking all verification activities
(define-map compliance-audit-log
    { doc-id: (string-ascii 36), audit-id: uint }
    {
        action: (string-ascii 50),
        framework-id: (string-ascii 20),
        performed-by: principal,
        timestamp: uint,
        details: (string-ascii 300),
        previous-status: (string-ascii 15),
        new-status: (string-ascii 15)
    }
)

;; Compliance deadlines and renewal tracking
(define-map compliance-deadlines
    { doc-id: (string-ascii 36), framework-id: (string-ascii 20) }
    {
        compliance-deadline: uint,
        renewal-required: bool,
        reminder-sent: bool,
        grace-period-blocks: uint,
        responsible-party: principal
    }
)

;; Data variables for system management
(define-data-var next-audit-id uint u0)
(define-data-var compliance-admin principal tx-sender)

;; Framework management functions
(define-public (create-compliance-framework 
    (framework-id (string-ascii 20))
    (name (string-ascii 100))
    (description (string-ascii 300))
    (jurisdiction (string-ascii 50)))
    (let ((existing-framework (map-get? compliance-frameworks { framework-id: framework-id })))
        (if (is-some existing-framework)
            err-compliance-framework-exists
            (ok (map-set compliance-frameworks
                { framework-id: framework-id }
                {
                    name: name,
                    description: description,
                    jurisdiction: jurisdiction,
                    created-by: tx-sender,
                    created-at: stacks-block-height,
                    active: true
                }))
        )
    )
)

(define-public (add-compliance-requirement
    (framework-id (string-ascii 20))
    (requirement-id (string-ascii 30))
    (title (string-ascii 150))
    (description (string-ascii 500))
    (mandatory bool)
    (verification-criteria (string-ascii 300))
    (penalty-level uint))
    (let ((framework (map-get? compliance-frameworks { framework-id: framework-id }))
          (existing-req (map-get? compliance-requirements { framework-id: framework-id, requirement-id: requirement-id })))
        (if (is-none framework)
            err-compliance-framework-not-found
            (if (is-some existing-req)
                err-compliance-requirement-exists
                (ok (map-set compliance-requirements
                    { framework-id: framework-id, requirement-id: requirement-id }
                    {
                        title: title,
                        description: description,
                        mandatory: mandatory,
                        verification-criteria: verification-criteria,
                        penalty-level: penalty-level,
                        created-at: stacks-block-height
                    }))
            )
        )
    )
)

;; Document compliance assessment functions
(define-public (assess-document-compliance
    (doc-id (string-ascii 36))
    (framework-id (string-ascii 20))
    (compliance-score uint)
    (status (string-ascii 15))
    (critical-issues uint)
    (notes (string-ascii 400))
    (review-interval-blocks uint))
    (let ((framework (map-get? compliance-frameworks { framework-id: framework-id })))
        (if (is-none framework)
            err-compliance-framework-not-found
            (if (> compliance-score u100)
                err-invalid-compliance-status
                (begin
                    (unwrap-panic (log-compliance-action doc-id framework-id "assessment" (unwrap-panic (as-max-len? notes u300)) "pending" status))
                    (ok (map-set document-compliance
                        { doc-id: doc-id, framework-id: framework-id }
                        {
                            assessment-status: status,
                            compliance-score: compliance-score,
                            assessed-by: tx-sender,
                            assessed-at: stacks-block-height,
                            next-review-due: (+ stacks-block-height review-interval-blocks),
                            critical-issues: critical-issues,
                            notes: notes
                        }))
                )
            )
        )
    )
)

(define-public (verify-requirement-compliance
    (doc-id (string-ascii 36))
    (framework-id (string-ascii 20))
    (requirement-id (string-ascii 30))
    (compliant bool)
    (evidence (string-ascii 200))
    (expiry-blocks (optional uint)))
    (let ((requirement (map-get? compliance-requirements { framework-id: framework-id, requirement-id: requirement-id })))
        (if (is-none requirement)
            err-compliance-requirement-not-found
            (begin
                (unwrap-panic (log-compliance-action doc-id framework-id "requirement-verification" (unwrap-panic (as-max-len? evidence u300))
                      (if compliant "non-compliant" "compliant") 
                      (if compliant "compliant" "non-compliant")))
                (ok (map-set requirement-compliance
                    { doc-id: doc-id, framework-id: framework-id, requirement-id: requirement-id }
                    {
                        compliant: compliant,
                        verification-evidence: evidence,
                        verified-by: tx-sender,
                        verified-at: stacks-block-height,
                        expiry-date: (match expiry-blocks
                            blocks (some (+ stacks-block-height blocks))
                            none)
                    }))
            )
        )
    )
)

(define-public (set-compliance-deadline
    (doc-id (string-ascii 36))
    (framework-id (string-ascii 20))
    (deadline-blocks uint)
    (grace-period-blocks uint)
    (responsible-party principal))
    (let ((compliance (map-get? document-compliance { doc-id: doc-id, framework-id: framework-id })))
        (if (is-none compliance)
            err-compliance-assessment-not-found
            (ok (map-set compliance-deadlines
                { doc-id: doc-id, framework-id: framework-id }
                {
                    compliance-deadline: (+ stacks-block-height deadline-blocks),
                    renewal-required: true,
                    reminder-sent: false,
                    grace-period-blocks: grace-period-blocks,
                    responsible-party: responsible-party
                }))
        )
    )
)

;; Audit and logging functions
(define-private (log-compliance-action
    (doc-id (string-ascii 36))
    (framework-id (string-ascii 20))
    (action (string-ascii 50))
    (details (string-ascii 300))
    (previous-status (string-ascii 15))
    (new-status (string-ascii 15)))
    (let ((audit-id (+ (var-get next-audit-id) u1)))
        (begin
            (var-set next-audit-id audit-id)
            (ok (map-set compliance-audit-log
                { doc-id: doc-id, audit-id: audit-id }
                {
                    action: action,
                    framework-id: framework-id,
                    performed-by: tx-sender,
                    timestamp: stacks-block-height,
                    details: details,
                    previous-status: previous-status,
                    new-status: new-status
                }))
        )
    )
)

;; Read-only functions for querying compliance data
(define-read-only (get-compliance-framework (framework-id (string-ascii 20)))
    (map-get? compliance-frameworks { framework-id: framework-id })
)

(define-read-only (get-compliance-requirement (framework-id (string-ascii 20)) (requirement-id (string-ascii 30)))
    (map-get? compliance-requirements { framework-id: framework-id, requirement-id: requirement-id })
)

(define-read-only (get-document-compliance (doc-id (string-ascii 36)) (framework-id (string-ascii 20)))
    (map-get? document-compliance { doc-id: doc-id, framework-id: framework-id })
)

(define-read-only (get-requirement-compliance 
    (doc-id (string-ascii 36)) 
    (framework-id (string-ascii 20)) 
    (requirement-id (string-ascii 30)))
    (map-get? requirement-compliance { doc-id: doc-id, framework-id: framework-id, requirement-id: requirement-id })
)

(define-read-only (get-compliance-deadline (doc-id (string-ascii 36)) (framework-id (string-ascii 20)))
    (map-get? compliance-deadlines { doc-id: doc-id, framework-id: framework-id })
)

(define-read-only (get-audit-entry (doc-id (string-ascii 36)) (audit-id uint))
    (map-get? compliance-audit-log { doc-id: doc-id, audit-id: audit-id })
)

(define-read-only (is-compliance-deadline-passed (doc-id (string-ascii 36)) (framework-id (string-ascii 20)))
    (match (map-get? compliance-deadlines { doc-id: doc-id, framework-id: framework-id })
        deadline-info (> stacks-block-height (get compliance-deadline deadline-info))
        false
    )
)

(define-read-only (calculate-overall-compliance-score (doc-id (string-ascii 36)))
    ;; This would typically aggregate scores across all frameworks for a document
    ;; Simplified implementation returns average compliance score
    u75 ;; Placeholder - real implementation would calculate across all frameworks
)

;; Administrative functions
(define-public (deactivate-framework (framework-id (string-ascii 20)))
    (let ((framework (map-get? compliance-frameworks { framework-id: framework-id })))
        (if (is-none framework)
            err-compliance-framework-not-found
            (if (is-eq tx-sender (var-get compliance-admin))
                (ok (map-set compliance-frameworks
                    { framework-id: framework-id }
                    (merge (unwrap-panic framework) { active: false })))
                err-not-authorized
            )
        )
    )
)

(define-public (update-compliance-admin (new-admin principal))
    (if (is-eq tx-sender (var-get compliance-admin))
        (ok (var-set compliance-admin new-admin))
        err-not-authorized
    )
)

