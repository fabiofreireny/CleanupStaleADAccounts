# CleanupStaleADAccounts
Disables and/or deletes stale computer and user accounts. Stale is defined as not having logged in X days in any OU.

It will only delete objects located within the pre-defined Disabled OUs. It assumes that if you've disabled an account by hand and not moved it that you'll want to keep it where it is

- (optional) Supports an exception list
- (optional) Adds "Disabled on YY-MM-DD" to user-defined AD property
- (optional) Sends out status email
- Supports WhatIf

### This script is not a replacement for having a proper off-boarding process! 
### It is meant to catch objects that have "fallen through the cracks"!
