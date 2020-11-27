# Merge Control

The Merge Control app provides SF Administrators the ability to do two things:
1) Track merged field values:  when an account or contact is merged the field values of specific fields can be tracked and reported on in a custom object
2) Provide field value preservation rules:  when an account or contact is merged, preserve values of specific fields based on rules (oldest record, newest record, smallest value, largest value)

Note:  this app requires Lightning Experience


## Installation

## Configuration
1) After installation, open the Merge Control app by going to the application menu and selecting Merge Control.

### Merge

## Package Contents

The following contents are in this package

### Objects
#### MergeFieldHistory__c
The Merge Object allows you to report on values for fields that have been merged away.
##### Fields
1) Kept Contact Id:  the Salesforce Id of the contact that was kept
2) Kept Value:  the value of the field on the kept record
3) Merge Value:  the value of the field on the merged record
4) Merge Value Type: the field that the values exist on
#### ContactMergeField__mdt
Custom metadata type to store rules for whether fields should be tracked or values preserved during merge
##### Fields
1) Disable:  this field disables the tracking or preserving of the field
2) Field:  the field to track or preserve
3) Object:  the SObject (Account or Contact)
4) Preservation Rule:  the rule for preserving the value (oldest record's value, newest record's value, largest value, smallest value)
5) Type:  the type of rule to apply (either Track or Preserve)
#### MergeControlSettings__c
Custom settings to control firing of the merge triggers
##### Fields
1) Disable Account Trigger:  disables the account trigger completely
2) Disable Contact Trigger:  disables the contact trigger completely
3) Disable For Profiles:  semi-colon delimited string of profile Ids, disables the triggers from firing for specific profiles
4) Disable For Users:  semi-colon delimited string of user Ids, disables the triggers from firing for specific users
#### MergeRecordSave__e
Platform Event for tracking metadata save completion
##### Fields
1) IsSuccess: whether or not save is successful
2) JobId:  tbd
3) Message: error message if metadata deploy fails

### Classes
#### CON_Merge_SVC.cls
Service class for handling merges for records

#### CON_Merge_QUEUE.cls
Queuable for processing merge rules asynchronously after delete

#### CON_Merge_TEST.cls
Test class for merge service and queuable

#### CON_MergeSettings_CTRL.cls
Page controller for the merge settings lightning component

#### CON_MergeSettings_TEST.cls
Test class for merge settings

#### CON_Metadata_SVC.cls
Service class for handling metadata retreival and saving

### Triggers

#### ContactMerge.trigger
Trigger that fires on Contact Delete

#### AccountMerge.trigger
Trigger that fires on Account Delete

### LWC
#### mergeMain
the landing page for the merge application

#### mergeRecordList
component for intercting with the contactmergefield metadata

#### mergeSingleRecord
component for interacting with a single contactMergefield metadata record

#### mergeSettings
component for interacting with MergeControlSettings__c custom settings
