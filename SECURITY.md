# Security

Report vulnerabilities privately to the repository maintainers rather than in
a public issue. Do not include live credentials or private Discogs data in a
report.

RecordCatalogKit does not persist credentials. Applications should store tokens
in Keychain, avoid logging authentication values, and understand that a consumer
secret embedded in an iOS application cannot be fully protected. Revoke affected
Discogs tokens immediately if exposure is suspected.
