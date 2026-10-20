# Merge Control — Administrator Guide

Merge Control helps Salesforce administrators find duplicate Accounts and Contacts, merge them safely, and keep a record of what changed. This guide explains each part of the app and how to use it.

## Contents

1. [Where to find the app](#where-to-find-the-app)
2. [How a merge works](#how-a-merge-works)
3. [Finding and merging duplicates](#finding-and-merging-duplicates)
4. [Field settings: tracking and preserving values](#field-settings-tracking-and-preserving-values)
5. [Auto-merge settings](#auto-merge-settings)
6. [Global settings](#global-settings)
7. [Reviewing what changed](#reviewing-what-changed)
8. [Common questions](#common-questions)

---

## Where to find the app

Open the **App Launcher** and select **Merge Control**. The app has three tabs:

- **Merge** — the main workspace. It contains four sub-tabs: *Merge Candidates*, *Field Settings*, *Auto Merge Settings*, and *Global Settings*.
- **Merge Candidates** — the list of duplicate groups the app has found.
- **Merge Field History** — the log of field values that changed during merges.

Merge Control builds on Salesforce's standard **Duplicate Rules**. You define which records count as duplicates using the normal Setup → Duplicate Rules screens; Merge Control uses those rules to do the finding and merging.

---

## How a merge works

When two or three records are merged, Salesforce keeps one record (the **kept record**) and deletes the others (the **merged records**). By default the kept record's values win.

Merge Control adds two things on top of that:

- **Preservation rules** let you override the default and pull specific field values from a losing record onto the kept record (for example, always keep the oldest "Customer Since" date).
- **Tracking** writes a before-and-after log of selected fields so you have an audit trail of what each merge changed.

Which record is kept is decided by the **Keep Record Rules** (see below). Without rules, the records in a duplicate group are sorted by Id and the first one is kept. You can change individual field values before merging using the preview screen (see below).

> **Note:** A single merge handles up to three records at once. If a duplicate group contains more than three records, run the merge again after the first merge to clean up the remainder.

---

## Finding and merging duplicates

### Scanning for duplicates

A background **scan** looks through your Accounts and Contacts, applies your active duplicate rules, and creates a **Merge Candidate** for each duplicate group it finds. Each Merge Candidate records the kept record, the record(s) to merge into it, and which duplicate rule matched.

Scans normally run on a schedule. New candidates appear with a status of **New**.

### Working the Merge Candidates list

Open the **Merge Candidates** sub-tab on the Merge tab. You can:

- **Filter** by object (Account or Contact) and by duplicate rule.
- **Page through** large lists of candidates.
- **Preview** a candidate to see the records side by side before merging.
- **Merge** a candidate immediately.
- **Mark as "Not a Duplicate"** to dismiss a candidate you don't want merged. Dismissed candidates are hidden from the list and skipped by auto-merge.

### The preview screen

Preview shows the kept record and the records being merged into it, side by side, highlighting the fields that differ. It also shows the **resulting values after the merge**, taking your preservation rules into account.

If you want to change a value before merging, you can set a **manual override** on the preview screen. Overrides apply to the kept record at merge time and take priority over the default behavior.

You control which fields appear on this screen in **Field Settings** — useful for hiding fields you've already handled with a preservation rule, or fields that aren't meaningful to compare.

---

## Field settings: tracking and preserving values

Open the **Field Settings** sub-tab. Here you choose, per object, how individual fields behave during a merge. Each field setting has a **type**:

### Track

A **tracked** field is logged whenever its value changes during a merge. The before value (from the losing record) and the after value (kept record) are written to **Merge Field History**. Tracking does not change which value wins — it only records what happened.

Use tracking for fields where you want an audit trail, such as Phone, Email, or Status.

### Preserve

A **preserved** field can override the default merge behavior and bring a value from a losing record onto the kept record. You choose a **preservation rule** that decides which value wins:

| Rule | Keeps the value from… |
|------|------------------------|
| **Oldest** | the record created earliest |
| **Newest** | the record created most recently |
| **Largest** | the record with the largest value (highest number, latest date, A–Z) |
| **Smallest** | the record with the smallest value (lowest number, earliest date, Z–A) |
| **Related Field** | a paired field — see below |

A preserved field is also tracked automatically when its value changes, so preserved changes show up in Merge Field History too.

**Default behavior for fields you don't configure:** if the kept record's field is blank and a losing record has a value, the value is filled in. Checkbox (true/false) fields are also brought over if any record has it checked. Otherwise the kept record's value stays.

### Apex Defined

When no built-in rule expresses what a field needs, the **Apex Defined** rule hands the decision to a custom Apex class. Set the rule to *Apex Defined Rule* and enter the class name in **Apex Class**. Developers: see the [Apex API guide](apex-api.md) for how to write and register one.

### Related Field

The **Related Field** rule keeps two fields in sync so they always come from the *same* record. Pair a field with a related field — for example, "Primary Contact" and "Primary Contact Phone." When the merge decides which record's primary contact to keep, the related phone comes from that same record rather than being chosen independently.

### Hiding fields from the preview

Each field can be marked **hidden** so it does not appear on the preview screen. Hide fields you've already covered with a preservation rule, or that aren't useful to compare, to keep the preview focused.

---

## Auto-merge settings

Open the **Auto Merge Settings** sub-tab. This lists your active duplicate rules and lets you turn on **auto-merge** for any of them.

When a rule has auto-merge enabled, candidates found by that rule are merged automatically by a background job — no manual review needed. Your tracking and preservation rules still apply, and the changes are still logged to Merge Field History.

Turn on auto-merge only for rules you trust to match real duplicates. Leave it off for rules where you want a person to review each candidate first. Candidates marked "Not a Duplicate" are never auto-merged.

---

## Keep Record Rules

The **Keep Record Rules** tab decides which record of a duplicate group survives a merge, separately for Accounts and Contacts. A rule is one comparative preference on one field, and the rules form an ordered list:

1. The first rule narrows the group to the records it prefers.
2. If exactly one record is left, that record is kept.
3. If several are left, the next rule chooses among those. If no record satisfies a rule, the rule is skipped and the next one sees the same group.
4. When the rules never single out a record, the record with the lowest Id is kept.

Example for Accounts: **1. Relationship Manager has a value**, **2. Created Date is the oldest**. A household with a relationship manager beats one without; between two that both have one (or both lack one), the older household wins.

Preferences: *has a value*, *is blank*, *is checked*, *is unchecked*, *is the oldest*, *is the newest*, *is the largest*, *is the smallest*, *is the longest text*, *is the shortest text*, *equals*, *does not equal* and *contains* (the last three take a value; text comparisons ignore case). Any readable field can be used, including Created Date and formula fields.

Use the arrows to reorder rules, **Add Rule** and the trash icon to add and remove them, then **Save**. Rules are stored as custom metadata records and deployed in the background; a toast confirms the save. Removed rules are deactivated rather than deleted. Rules built with the previous version of this tab (condition lists) are no longer evaluated; recreate them here.

Where the rules apply:
- when the scan creates duplicate candidates (the kept record of each candidate),
- when a Contact candidate's Accounts are merged instead of the contacts (Auto-Merge Accounts),
- when a household is merged after a Contact merge, if **Household merge uses the Account keep record rules** is on in Global Settings.

---

## Global settings

Open the **Global Settings** sub-tab to control when Merge Control's automation runs.

- **Disable Account Trigger / Disable Contact Trigger** — turn off Merge Control's automatic processing for that object. Use this if you need to pause the app temporarily.
- **Disable for Profiles** — choose profiles whose users' changes won't trigger Merge Control processing.
- **Disable for Users** — choose specific users whose changes won't trigger Merge Control processing.
- **Automatically merge orphaned households** — a comma-delimited list of Account record type API names (for example `Household_Account,HH_Account,Household,Individual`, the default when left blank). After a Contact merge, if the merged contact's Account has no Contacts left and both it and the kept contact's Account have one of these record types, the empty Account is merged into the kept contact's Account and logged as an Account merge candidate with rule "Orphaned Household Merge". Matching ignores case and spaces. Enter a value that matches no record type, such as `NONE`, to turn this off.
- **Disable NPSP triggers on orphaned household merge** — for orgs with the Nonprofit Success Pack (NPSP). When on, Merge Control turns off the NPSP triggers just before it merges an orphaned household, so NPSP's address sync does not overwrite the address your merge rules gave the kept contact. Addresses that already differed between the contact and the household before the merge are left as they were. Things to know:
  - It turns off **all** NPSP triggers, not only the address ones, and they stay off until that merge transaction finishes. Other users and other transactions are not affected, and your NPSP Trigger Handler records are not changed.
  - NPSP's own follow-up work for the surviving household is skipped for that merge — for example, recalculating rollups for donations moved over from the empty household.
  - It only applies when an orphaned household is actually merged. A Contact merge that leaves no empty household runs with NPSP triggers on as usual.
  - While the triggers are off, Merge Control clears the Default flag on the empty household's NPSP Address records before merging, so the surviving household keeps a single default address.
  - Off by default. It has no effect in orgs without NPSP.
- **Reset default address on orphaned household merge** — for orgs with NPSP. When on, after an orphaned household is merged, the kept contact's mailing address becomes the household's default NPSP Address. If the household already has an Address that matches, it is reused; otherwise a new one is created. The contact's Current Address and the Account's billing address are pointed at it. Things to know:
  - It is skipped, and the household's default address is left as it was, when the household has more than one contact, the contact has address override turned on, the household has seasonal addresses, or the contact has no mailing address.
  - It only works together with **Disable NPSP triggers on orphaned household merge**. With that setting off, this one does nothing.
  - Off by default. It has no effect in orgs without NPSP.
- **Merge households with members** — goes one step further than the orphaned household merge. When on, after a Contact merge the merged contact's household is merged into the kept contact's household even when other contacts still live in it, as long as both Accounts have one of the record types listed under **Automatically merge orphaned households**. The remaining members, their records and the household's donations move to the kept household. Each merge is logged as an Account merge candidate with rule "Household Member Merge". Why you might want this: when the kept contact lives alone and the merged contact lived with a spouse, merging only the contact moves the person out of the shared household, and NPSP then removes their household soft credits on the spouse's gifts; merging the households keeps the family together. Things to know:
  - It merges households, not people: whoever else lives in the merged contact's household moves along. Use the two safeguards below.
  - The kept contact's household always survives. Household naming, member counts and soft credits are recalculated by NPSP's own follow-up work after the merge.
  - Address records move with the household. With **Disable NPSP triggers on orphaned household merge** on, the moved Address records lose their Default flag so the surviving household keeps a single default; the moved members keep their own mailing addresses until NPSP next syncs them. **Reset default address on orphaned household merge** is skipped for households that end up with more than one contact.
  - Off by default. Emptied households are still merged as before whatever this setting says.
- **Merge households with members: require same address** — with the setting above on, merge a household that still has members only when every remaining member's mailing street (first line) and five-digit postal code match the kept contact's mailing address after the merge. Case, punctuation, a second street line and ZIP+4 are ignored. A kept contact with no mailing street never matches, so such households are left alone. Off by default; recommended on.
- **Merge households with members: max other members** — with the setting above on, the most contacts the merged contact's household may still have and be merged. `1` means a spouse only. Leave blank for no limit.
- **Household merge uses the Account keep record rules** — when a household is merged after a Contact merge (orphaned household or household with members), choose the surviving household with the Account **Keep Record Rules** instead of always keeping the kept contact's household. If the rules prefer the other household, the kept contact moves into it and the Account candidate records that household as kept. Falls back to the kept contact's household when the rules do not decide, and when a kept contact has more than one household to merge in the same run. Off by default.

The profile and user lists show only profiles and users that have delete permission on Accounts or Contacts, since merging requires delete access.

---

## Reviewing what changed

Open the **Merge Field History** tab to see the audit log. Each entry records, for one merge:

- the **kept record** and the **merged (deleted) record**,
- the **field** that changed,
- the **kept value** (what's on the surviving record now), and
- the **merged value** (what was on the deleted record).

Use this object in list views and reports to review merge activity over time. Only fields you marked **Track** (and preserved fields that changed) are logged here.

---

## Common questions

**Which record survives a merge?**
The Keep Record Rules decide (see that section). Without rules, the records in a group are sorted by Id and the first is kept. You can override individual field values before merging using the preview screen.

**What happens to more than three duplicates in one group?**
Salesforce merges up to three at a time. Run the merge again on the remaining candidate to finish.

**Will Merge Control merge records on its own?**
Only for duplicate rules where you've turned on auto-merge. Everything else waits for you to merge it from the Merge Candidates list.

**How do I stop a candidate from ever being merged?**
Open it and mark it **Not a Duplicate**. It will be hidden from the list and skipped by auto-merge.

**Do preservation and tracking rules apply to auto-merges too?**
Yes. They apply to every merge Merge Control performs, manual or automatic.

**How do I pause the app?**
Use **Global Settings** to disable the Account and/or Contact triggers, or disable processing for specific profiles or users.
