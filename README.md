# Merge App

The Merge App provides SF Administrators the ability to do ttwo things:
1) Track merged field values:  when a contact is merged away the field values of specific fields can be tracked
2) Provide field value preservation rules:  when two contacts are merged, preserve values of specific fields based on rules that you choose

## Part 1: Package Contents

The following contents are in this package

### Objects
#### Merge__c
The Merge Object allows you to report on values for fields that have been merged away.
##### Fields
1) Kept Contact Id:  the Salesforce Id of the contact that was kept
2) Kept Value:  the value of the field on the kept record
3) Merge Value:  the value of the field on the merged record
4) Merge Value Type: the field that the values exist on

### Classes
#### CON_Merge_SVC.cls

#### CON_Merge_TEST.cls

### Triggers

#### ContactMerge.trigger
