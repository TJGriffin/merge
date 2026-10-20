# Merge Control

The Merge Control app provides SF Administrators with the following tools related to merging:
1) Track merged field values:  when an account or contact is merged the field values of specific fields can be tracked and reported on in a custom object
2) Provide field value preservation rules:  when an account or contact is merged, preserve values of specific fields based on rules (oldest record, newest record, smallest value, largest value)
3) Manage bulk merging with duplicate rules including
- specify specific duplicate rules for auto merging
- provide a list interface to see all duplicates for a specific rule and allow admins to merge in the UI
4) a condensed UI where you can see the key differences between records as well as the resulting values post merge
- admins can control which fields should be hidden from this UI (particularly if you've already defined rules for preservation)
5) Automatically merge orphaned household Accounts: when a contact merge leaves its old household Account empty, the empty Account is merged into the kept contact's Account (configurable by record type in Global Settings). In NPSP orgs, an optional setting disables the NPSP triggers for that transaction so NPSP address sync does not overwrite the kept contact's address. The surviving household keeps a single default NPSP Address, and a second optional setting resets it to the kept contact's address
6) Optionally merge households that still have members: with "Merge households with members" on, the merged contact's household is merged into the kept contact's household even when other contacts remain in it, so a person is not merged out of their family's household. Two safeguards are configurable: require every remaining member to share the kept contact's street and ZIP, and a maximum number of other members
7) Keep Record Rules: an ordered list of comparative preferences per object (for example "prefer the Account whose Relationship Manager has a value, then the oldest Account") that decides which record of a duplicate group survives, at scan time and, optionally, when households are merged after a Contact merge

## Installation

Current release: **2.14.0** (unlocked package, `04tbm000000qzPBAAY`)

Install via URL:
- Production / Developer Edition: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tbm000000qzPBAAY
- Sandbox: https://test.salesforce.com/packaging/installPackage.apexp?p0=04tbm000000qzPBAAY

Or with the Salesforce CLI:

```
sf package install --package 04tbm000000qzPBAAY --target-org <org-alias> --wait 10
```

After installing, assign the **Merge Control Administrator** permission set to administrators.

## Documentation

- [Administrator Guide](docs/user-guide.md) — how each functional area works and how to use it
- [Apex API](docs/apex-api.md) — writing custom merge rules in Apex against the `MRG_FieldKeepRule` hook







