# Authentication and local sessions

## Implemented

- The application now starts behind `AuthGate`; the warehouse home is not constructed until a user authenticates or a valid local session is restored.
- First launch with an empty users table offers a first-administrator account setup. It requires a full name, unique username, and password of at least eight characters.
- Existing account password compatibility is preserved: the password digest uses the current per-user salt and SHA-256 format already used by the user administration screen.
- A single local session is stored in SQLite table `user_sessions` (schema version 12). It survives app restarts and remains valid until explicit sign-out, account deactivation, or password-hash change.
- Session restoration joins the session to the current user record and requires `users.is_active=1` and an exact match between the stored password-hash snapshot and the current hash.
- Deactivating a user deletes that user's local session immediately. Password reset invalidates an existing session at the next session validation because the password-hash snapshot no longer matches.
- Login, first-account setup, language selection, and sign-out are available in Arabic, English, and French.

## Data flow

1. On app startup, `AuthGate` calls `restoreUserSession()`.
2. If no valid session exists and there are no users, the first-administrator setup is shown.
3. Otherwise, the login screen calls `authenticateUser()`.
4. Successful authentication replaces the single local session row.
5. Sign-out deletes that row and returns to the login screen.

## Security boundary and remaining work

- This is a local-device authentication layer for the current offline-first SQLite application. It is not a central identity provider and does not synchronize sessions between devices.
- The current password digest format is retained for compatibility with existing accounts; a future credential migration should move to a deliberately slow password KDF with a versioned hash format.
- Market intelligence repository methods continue to require explicit permission keys. The first administrator is not silently granted confidential competitor access.
- The next integration step is to pass the authenticated user ID into permission-aware navigation and market analytics screens, then add automated SQLite migration/session tests and verify the Android CI build.
