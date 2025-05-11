# LegalDoc Chain

A decentralized legal document management system built on Stacks blockchain that enables law firms to securely store, verify, and manage access to legal documents.

## Features

- Document storage with unique IDs and cryptographic hashes
- Built-in version control and document history
- Automatic timestamping using blockchain height
- Granular access control and permission management
- Document ownership verification
- Secure document updates with authorization checks

## Smart Contract Functions

### Public Functions

- `store-document`: Store a new legal document with hash and metadata
- `update-document`: Update an existing document while maintaining version history  
- `grant-access`: Grant document access permissions to other users/principals

### Read-Only Functions

- `get-document`: Retrieve document metadata and current version
- `can-access-document`: Check if a user has access permissions

## Error Codes

- `100`: Not authorized
- `101`: Document already exists  
- `102`: Document not found

## Development

### Prerequisites

- [Clarinet](https://github.com/hirosystems/clarinet)
- Node.js and npm

### Testing

The contract includes a comprehensive test suite covering:

- Document storage and retrieval
- Version control
- Access management
- Authorization checks
- Error handling
