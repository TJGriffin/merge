# Merge Control

The Merge Control app provides SF Administrators with the following tools related to merging:
1) Track merged field values:  when an account or contact is merged the field values of specific fields can be tracked and reported on in a custom object
2) Provide field value preservation rules:  when an account or contact is merged, preserve values of specific fields based on rules (oldest record, newest record, smallest value, largest value)
3) Manage bulk merging with duplicate rules including
- specify specific duplicate rules for auto merging
- provide a list interface to see all duplicates for a specific rule and allow admins to merge in the UI
4) a condensed UI where you can see the key differences between records as well as the resulting values post merge
- admins can control which fields should be hidden from this UI (particularly if you've already defined rules for preservation)

## Installation

Current release: **2.6.0** (unlocked package, `04tKb000000Eh0AIAS`)

Install via URL:
- Production / Developer Edition: https://login.salesforce.com/packaging/installPackage.apexp?p0=04tKb000000Eh0AIAS
- Sandbox: https://test.salesforce.com/packaging/installPackage.apexp?p0=04tKb000000Eh0AIAS

Or with the Salesforce CLI:

```
sf package install --package 04tKb000000Eh0AIAS --target-org <org-alias> --wait 10
```

After installing, assign the **Merge Control Administrator** permission set to administrators.

## Documentation

- [Administrator Guide](docs/user-guide.md) — how each functional area works and how to use it







