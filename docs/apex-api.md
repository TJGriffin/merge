# Apex API — Custom Merge Rules

Merge Control resolves most field values with declarative preservation rules (Oldest, Newest, Longest, Complex, and so on). When a field needs logic those rules can't express, the **Apex Defined** preservation rule hands the decision to your own Apex class.

This document covers the hook: the interface, the context it receives, where it runs in the merge pipeline, and what it may and may not do.

> Audience: developers extending Merge Control in a subscriber org or in a fork of this package. For declarative configuration, see the [Administrator Guide](user-guide.md).

## Contents

1. [Quick start](#quick-start)
2. [Interface reference](#interface-reference)
3. [Context reference](#context-reference)
4. [Where the resolver runs](#where-the-resolver-runs)
5. [Contract and guarantees](#contract-and-guarantees)
6. [Failure handling](#failure-handling)
7. [Limits and performance](#limits-and-performance)
8. [Testing a resolver](#testing-a-resolver)
9. [Examples](#examples)
10. [Registering a rule in metadata](#registering-a-rule-in-metadata)

---

## Quick start

**1. Write a class that implements `MRG_FieldKeepRule`.**

```apex
global class AcmeAccountNameRule implements MRG_FieldKeepRule {
    global Object resolveValue(MRG_FieldKeepContext context) {
        // prefer a value that is not all-uppercase; otherwise leave the rule-decided value alone
        for(SObject losing : context.mergeRecords) {
            String value = (String) losing.get(context.fieldName);
            if(String.isNotBlank(value) && value != value.toUpperCase())
                return value;
        }
        return context.currentValue;
    }
}
```

The class must be `global` or `public`, have a no-argument constructor, and be visible to the Merge Control package at runtime (it is instantiated with `Type.forName`). In a subscriber org, a `public` class in the default namespace is fine.

**2. Deploy it to the org.**

```
sf project deploy start --source-dir force-app/main/default/classes/AcmeAccountNameRule.cls --target-org <alias>
```

**3. Register it on a field.** In the Merge Control app, open **Merge → Field Settings**, add or edit a setting for the object and field, then:

- **Type** = `Preserve`
- **Preservation Rule** = `Apex Defined Rule`
- **Apex Class** = the class name, e.g. `AcmeAccountNameRule`

Save. The preview screen reflects the resolver's decision immediately — no merge required to verify it.

See [Registering a rule in metadata](#registering-a-rule-in-metadata) to ship the same configuration as source.

---

## Interface reference

[`MRG_FieldKeepRule`](../force-app/main/default/classes/MRG_FieldKeepRule.cls)

```apex
global interface MRG_FieldKeepRule {
    Object resolveValue(MRG_FieldKeepContext context);
}
```

One method, called once per kept record per registered field. The return value becomes the field's value on the surviving record.

| Return | Effect |
| --- | --- |
| `context.currentValue` | No change. The value chosen by the built-in rules stands. |
| Any other value | Written to `context.fieldName` on the kept record and logged to Merge Field History. |
| `null` | Blanks the field, if it currently has a value. This is a real change, not a no-op. |

The returned value is written with `SObject.put()`, so it must be the Apex type the field expects (`String`, `Decimal`, `Date`, `Datetime`, `Boolean`, `Id`, …). A type mismatch throws, and the field is [skipped](#failure-handling).

---

## Context reference

[`MRG_FieldKeepContext`](../force-app/main/default/classes/MRG_FieldKeepContext.cls)

| Member | Type | Description |
| --- | --- | --- |
| `objectType` | `String` | The SObject API name being merged (`Account`, `Contact`). |
| `fieldName` | `String` | The field this call decides. One resolver class can serve many fields — branch on this. |
| `keepRecord` | `SObject` | The surviving record with every value resolved so far. |
| `keepOriginal` | `SObject` | The surviving record's pre-merge values. |
| `mergeRecords` | `List<SObject>` | The losing records, at their original values. Never `null`; may be empty. |
| `currentValue` | `Object` | The value the built-in rules chose for `fieldName` — a snapshot of `keepRecord.get(fieldName)` taken when the context was constructed. |

### Which fields are populated

The records in the context carry the fields Merge Control queried, which is **every accessible, updateable field** on the object, plus `Id`, `CreatedDate`, and `LastModifiedDate`.

Non-updateable fields — formulas, roll-up summaries, `SystemModstamp`, most audit fields — are **not** in the query and reading them throws `SObjectException: SObject row was retrieved via SOQL without querying the requested field`.

Two ways to work around that:

- Configure a **Complex** preservation rule on the same object that references the field in a condition or tie-break. Those referenced fields are added to the query for the whole merge.
- Query it yourself in the resolver. Cheap in a single-group preview, expensive in a batch — see [Limits and performance](#limits-and-performance).

Guard defensively if you're unsure:

```apex
Map<String, Object> populated = context.keepRecord.getPopulatedFieldsAsMap();
Object score = populated.containsKey('Health_Score__c') ? populated.get('Health_Score__c') : null;
```

### Group size

A merge handles up to three records, so `mergeRecords` normally holds one or two records. Don't assume a fixed size, and handle the empty case.

---

## Where the resolver runs

Field values are resolved in [`MRG_Merge_SVC.getMergesFromDeletedRecords`](../force-app/main/default/classes/MRG_Merge_SVC.cls) in this order:

1. **Pairwise pass** — each losing record is compared with the kept record. Track settings log changes; Preserve settings (Oldest, Newest, Largest, Smallest, Longest, Shortest, Contains, Combine, Concatenate, Priority Order, Related Field) apply. Fallback fields are routed. Fields owned by Complex or Apex Defined rules are excluded from this pass entirely.
2. **Manual overrides** — values a user edited on the preview screen are applied to the kept record.
3. **Complex pass** — group-wide, evaluated against the pre-merge values of the whole group.
4. **Apex Defined pass** — your resolver, group-wide, last.

Running last is the point: `context.currentValue` is the outcome of everything above, so a resolver can accept, adjust, or replace it with full knowledge of what the declarative rules decided.

Two consequences worth knowing:

- **A resolver overrides a user's manual preview edit.** Step 4 runs after step 2. If a resolver should defer to a hand-entered value, compare `currentValue` against `keepOriginal` and return `currentValue` when they differ.
- **Resolvers see each other's output only through `keepRecord`.** Each field's context is constructed immediately before its own call, so a resolver for field B sees field A's resolved value if A was processed first. Ordering across fields is the metadata query order — do not depend on it.

### Invocation paths

The pass runs on every path that computes a merge result:

| Path | Entry point | Notes |
| --- | --- | --- |
| Preview screen | `MRG_MergeCandidate_SVC` → `getMergeHistoryResult` | Read-only preview. Runs on every preview render. |
| Merge from the UI or batch | `MRG_Merge_SVC.processMergesFromBatch` | Resolved values are applied to the survivor after the `merge` DML. |
| Merge performed outside the app | `MRG_MergeCandidate_TRG` → `MRG_Merge_QUEUE` → `createMergeRecords` | Detected post-merge from `MasterRecordId`. Here the kept record is re-queried **after** the native merge, so `keepOriginal` and `keepRecord` both hold post-merge values and only `mergeRecords` carries the losing values. Write resolvers that read from `mergeRecords`, not from a pre/post comparison of the survivor, if you need them to behave identically on this path. |

### History records

A value your resolver changes is written to Merge Field History like any other change:

| Field | Value |
| --- | --- |
| `KeptRecordId__c` | The surviving record. |
| `MergedRecordId__c` | The surviving record's Id — not a losing record, because the value came from code. |
| `KeptValue__c` | The value you returned. |
| `MergeValue__c` | The value the built-in rules had chosen (`currentValue`). |
| `MergeValueType__c` | The field API name. |

History is written whether or not the field also has a Track setting.

---

## Contract and guarantees

**Return the value; do not mutate the record.** `context.keepRecord` is the live surviving record, but only `fieldName` is read back, and the record is only queued for update when your return value differs from `currentValue`. Writing to other fields on it is unsupported: the change is untracked, absent from history, and may or may not be saved depending on what else changed in the same merge.

**Be deterministic and side-effect free.** The same resolver runs on every preview render and again at merge time. It must return the same answer for the same inputs, or the preview will lie about the outcome.

**No DML, no callouts.** The preview path executes in an `@AuraEnabled` read context, and the merge path runs inside batch and queueable transactions with DML already in flight. Callouts after DML throw. Keep resolvers to pure computation over the context.

**Stay bulk-safe.** The resolver is called once per kept record per field for the whole batch, inside a loop. SOQL in `resolveValue` is SOQL per group.

**One instance per transaction.** The class is instantiated once by name and cached for the transaction, then reused across every group and field. Instance state leaks between records — keep resolvers stateless.

---

## Failure handling

A misconfigured or broken resolver never fails a merge. Each of these is logged at `ERROR` and skipped, leaving the built-in rule's value in place:

| Condition | Result |
| --- | --- |
| Apex Class is blank | The setting is ignored; the field is not treated as Apex Defined. |
| Class name doesn't resolve (`Type.forName` returns null) | Logged once, cached, skipped for the transaction. |
| Class doesn't implement `MRG_FieldKeepRule` | Logged once, cached, skipped. |
| Constructor throws | Logged once, cached, skipped. |
| `resolveValue` throws | Logged per field per group; that field keeps its existing value. Other fields and other groups continue. |
| Returned value has the wrong type for the field | Throws on `put`, caught as above. |

Because these are debug-log-only, a silently ineffective rule looks identical to a correctly configured one that chose not to change anything. When a rule appears to do nothing, run the merge with a debug log at `ERROR` on Apex Code and search for `Apex Defined rule`.

---

## Limits and performance

- **Called** once per kept record per registered field. A batch of 200 candidate groups with two Apex Defined fields makes 400 calls in one transaction.
- **Instantiation** happens once per class per transaction, including failed instantiations.
- **Governor limits** are shared with the whole merge transaction — the queries that loaded the records, the `merge` DML, history inserts, and candidate updates. Treat the resolver's budget as near zero.
- **The preview path** runs the same code for a single group on every render. Logic that is affordable there can still blow the batch path.

If a resolver genuinely needs data beyond the merged records, query it once outside the merge and expose it through a static cache on your own class, keyed so it stays correct across groups.

---

## Testing a resolver

Two levels, both worth having.

**Unit — call the resolver directly.** No DML, no configuration, fast:

```apex
@isTest
static void testKeepsMixedCaseName() {
    Account keep   = new Account(Name='ACME INDUSTRIES');
    Account losing = new Account(Name='Acme Industries');
    MRG_FieldKeepContext ctx = new MRG_FieldKeepContext(
        'Account', 'Name', keep, keep, new List<SObject>{ losing });

    Object result = new AcmeAccountNameRule().resolveValue(ctx);

    System.assertEquals('Acme Industries', (String) result);
}
```

**Integration — run a merge with the setting registered.** `MRG_TestFactory` injects merge field settings without deploying custom metadata, since `MergeFieldSetting__mdt` records can't be inserted in a test:

```apex
@isTest
static void testApexRuleAppliesDuringMerge() {
    List<Account> accts = MRG_TestFactory.accounts(2);
    Id keepId = accts[0].Id, mergeId = accts[1].Id;
    update new List<Account>{
        new Account(Id=keepId,  Name='ACME INDUSTRIES'),
        new Account(Id=mergeId, Name='Acme Industries')
    };

    MergeFieldSetting__mdt setting =
        MRG_TestFactory.mergeField('Account', 'Name', 'Preserve', 'Apex Defined');
    setting.ApexClass__c = 'AcmeAccountNameRule';
    setting.Disable__c   = false;   // required — a null Disable__c throws when the rule is collected

    MRG_Merge_SVC.mergeFields  = new List<MergeFieldSetting__mdt>{ setting };
    MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();
    MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Account');

    Test.startTest();
    MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Account');
    Test.stopTest();

    System.assertEquals('Acme Industries',
        (String) MRG_TestFactory.keptValue(keepId, 'Account', 'Name'));
}
```

`MRG_TestFactory.mergeField` leaves `Disable__c` null, and the rule collector evaluates it as a primitive — set it explicitly or the test fails with a null-pointer exception rather than a useful assertion. [`MRG_ApexFieldKeepRule_TEST`](../force-app/main/default/classes/MRG_ApexFieldKeepRule_TEST.cls) is the working reference for both test levels, including a self-contained setting builder.

Assert the failure modes too — a resolver that throws should leave the field untouched, not abort the merge.

---

## Examples

### Keep the longest value

Shipped as [`MRG_SampleFieldKeepRule`](../force-app/main/default/classes/MRG_SampleFieldKeepRule.cls) and usable as-is. (The declarative `Longest Text` rule does the same thing; this exists as a reference implementation.)

```apex
global class MRG_SampleFieldKeepRule implements MRG_FieldKeepRule {
    global Object resolveValue(MRG_FieldKeepContext context) {
        Object best = context.currentValue;
        Integer bestLen = best == null ? -1 : String.valueOf(best).length();
        for(SObject record : context.mergeRecords) {
            Object value = record.get(context.fieldName);
            Integer len = value == null ? -1 : String.valueOf(value).length();
            if(len > bestLen) {
                best = value;
                bestLen = len;
            }
        }
        return best;
    }
}
```

### One class, several fields

```apex
global class AcmeMergeRules implements MRG_FieldKeepRule {
    global Object resolveValue(MRG_FieldKeepContext context) {
        switch on context.fieldName.toLowerCase() {
            when 'phone'          { return firstNonBlank(context); }
            when 'annualrevenue'  { return maxRevenue(context); }
            when else             { return context.currentValue; }
        }
    }

    private Object firstNonBlank(MRG_FieldKeepContext context) {
        if(String.isNotBlank((String) context.currentValue))
            return context.currentValue;
        for(SObject record : context.mergeRecords) {
            String value = (String) record.get(context.fieldName);
            if(String.isNotBlank(value))
                return value;
        }
        return context.currentValue;
    }

    private Object maxRevenue(MRG_FieldKeepContext context) {
        Decimal best = (Decimal) context.currentValue;
        for(SObject record : context.mergeRecords) {
            Decimal value = (Decimal) record.get(context.fieldName);
            if(value != null && (best == null || value > best))
                best = value;
        }
        return best;
    }
}
```

### Defer to a manual preview override

```apex
global class AcmeDeferringRule implements MRG_FieldKeepRule {
    global Object resolveValue(MRG_FieldKeepContext context) {
        Object original = context.keepOriginal.get(context.fieldName);
        Boolean userEdited = !equalValues(original, context.currentValue);
        if(userEdited)
            return context.currentValue;   // a rule or a person already decided; leave it
        return decide(context);
    }

    private Boolean equalValues(Object a, Object b) {
        return a == null ? b == null : a.equals(b);
    }

    private Object decide(MRG_FieldKeepContext context) {
        // ...
        return context.currentValue;
    }
}
```

Note the limitation: this can't distinguish a manual override from a value a declarative preservation rule changed. Both show up as `currentValue != keepOriginal`.

---

## Registering a rule in metadata

The Field Settings UI writes a `MergeFieldSetting__mdt` record through the Metadata API. To version-control the same configuration, add the record as source:

`force-app/main/default/customMetadata/MergeFieldSetting.AccountNameA.md-meta.xml`

```xml
<?xml version="1.0" encoding="UTF-8"?>
<CustomMetadata xmlns="http://soap.sforce.com/2006/04/metadata">
    <label>Account Name</label>
    <protected>false</protected>
    <values>
        <field>Object__c</field>
        <value xsi:type="xsd:string">Account</value>
    </values>
    <values>
        <field>Field__c</field>
        <value xsi:type="xsd:string">Account.Name</value>
    </values>
    <values>
        <field>Type__c</field>
        <value xsi:type="xsd:string">Preserve</value>
    </values>
    <values>
        <field>PreservationRule__c</field>
        <value xsi:type="xsd:string">Apex Defined</value>
    </values>
    <values>
        <field>ApexClass__c</field>
        <value xsi:type="xsd:string">AcmeAccountNameRule</value>
    </values>
    <values>
        <field>Disable__c</field>
        <value xsi:type="xsd:boolean">false</value>
    </values>
</CustomMetadata>
```

`PreservationRule__c` must be exactly `Apex Defined` — the picklist API name, not the `Apex Defined Rule` label shown in the UI. A setting is only picked up when `Type__c` is `Preserve`, `Disable__c` is false, and `ApexClass__c` is non-blank; miss any of those and the field falls through to the pairwise pass with no rule.

### Relevant `MergeFieldSetting__mdt` fields

| Field | Role for Apex Defined |
| --- | --- |
| `Object__c` | Entity the rule applies to. Must match the merge's object. |
| `Field__c` | The field the resolver decides. |
| `Type__c` | Must be `Preserve`. `Track` settings never reach the Apex pass. |
| `PreservationRule__c` | Must be `Apex Defined`. |
| `ApexClass__c` | Class name implementing `MRG_FieldKeepRule`. |
| `Disable__c` | `true` skips the setting entirely. |
| `FallbackField__c` | Ignored for Apex Defined fields — fallback routing happens in the pairwise pass, which skips these fields. |
| `RelatedField__c`, `TieBreakField__c`, `Conditions__c`, `FilterLogic__c`, `ContainsValue__c`, `ConcatenateCharacter__c`, `PriorityOrder__c` | Belong to other preservation rules; unused here. |
