public with sharing class MRG_MergeCandidate {
    /***
    * @description merge candidate record id
    */ 
    @AuraEnabled public String recordId;
    /***
    * @description merge candidate keep contact id
    */
    @AuraEnabled public SObject keepRecord;
    /***
    * @description merge candidate merge contact
    */
    @AuraEnabled public SObject mergeRecord1;
    /***
    * @description merge candidate merge contact
    */
    @AuraEnabled public SObject mergeRecord2;
    /***
    * @description result of merge
    */
    @AuraEnabled public SObject mergeResultRecord;

    /***
    * @description result of merge
    */
    @AuraEnabled public List<fieldOverride> manualOverrides;

    /***
    * @description collection of fields that have different values
    */
    @AuraEnabled public List<String> fields;

    @AuraEnabled public String status;

    @AuraEnabled public MergeCandidate__c mergeCandidate;

    @AuraEnabled public List<MergeFieldHistory__c> fieldHistory;

    @AuraEnabled public List<MRG_MergeSettings_CTRL.previewField> previewFields;

    /*******************************************************************************************************
    * @description No parameter constructor to enable use as virtual class.
    */      
    public MRG_MergeCandidate() {

    }
    /*******************************************************************************************************
    * @description No parameter constructor to enable use as virtual class.
    * @param the record id of the merge candidate record
    */      
    public MRG_MergeCandidate(String recordId) {
        this.recordId = recordId;
    }
    /*******************************************************************************************************
    * @description No parameter constructor to enable use as virtual class.
    */      
    public MRG_MergeCandidate(MergeCandidate__c mergeCandidate, SObject keepRecord, List<SObject> mergeRecords, MRG_Merge_SVC.mergeHistoryResult mergeResult, Set<String> fields) {
        if(mergeCandidate.Status__c == 'Processed'
            && String.isNotBlank(mergeCandidate.Data__c)){
            mergeResult = (MRG_Merge_SVC.mergeHistoryResult) JSON.deserialize(mergeCandidate.Data__c, MRG_Merge_SVC.mergeHistoryResult.class);
            Set<Id> mergeRecordIds = new Set<Id>();
            if(String.isNotBlank(mergeCandidate.mergeRecordId__c))
                mergeRecordIds.add(Id.valueOf(mergeCandidate.mergeRecordId__c));
            if(String.isNotBlank(mergeCandidate.merge2RecordId__c))
                mergeRecordIds.add(Id.valueOf(mergeCandidate.merge2RecordId__c));
            if(String.isNotBlank(mergeCandidate.keepRecordId__c))
                keepRecord = mergeResult.objectMap.containsKey(Id.valueOf(mergeCandidate.keepRecordId__c)) ? mergeResult.objectMap.get(Id.valueOf(mergeCandidate.keepRecordId__c)) : keepRecord;
            for(Id mergeId:mergeRecordIds){
                if(mergeResult.objectMap.containsKey(mergeId))
                    mergeRecords.add(mergeResult.objectMap.get(mergeId));

            }

        }
        this.recordID = mergeCandidate.Id;
        this.keepRecord = keepRecord;
        String objectType = keepRecord.getSObjectType().getDescribe().getName();
        this.previewFields = new List<MRG_MergeSettings_CTRL.previewField>(MRG_MergeSettings_CTRL.getAllPreviewFields(objectType));
        this.mergeRecord1 = mergeRecords != null && mergeRecords.size() > 0 ? mergeRecords[0] : null;
        this.mergeRecord2 = mergeRecords != null && mergeRecords.size() > 1 ? mergeRecords[1] : null;
        this.mergeResultRecord =  mergeResult.updateRecords != null && mergeResult.updateRecords.size()>0 ? mergeResult.updateRecords[0] : keepRecord;
        this.fieldHistory = mergeResult.fieldHistory;
        if(String.isNotBlank(mergeCandidate.Override__c)){
            Map<String, Schema.SObjectField> objFieldMap = Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();
            List<fieldOverride> overrides = new List<fieldOverride>();
            Map<String, Object> overrideMap = (Map<String, Object>) JSON.deserializeUntyped(mergeCandidate.Override__c);
            for(String fieldName:overrideMap.keyset()){
                fieldOverride fOrd = new fieldOverride();
                fOrd.fieldName = fieldName;
                if(objFieldMap.containsKey(fieldName)){
                    fOrd.fieldType = objFieldMap.get(fieldName).getDescribe().getSOAPType().name();
                }
                fOrd.fieldValue = overrideMap.get(fieldName);
                fOrd.keepId = this.keepRecord.Id;
                overrides.add(fOrd);
            }
            this.manualOverrides = overrides;
        }
        this.fields = new List<String>();
        if(fields != null)
            this.fields.addAll(fields);
        this.status = mergeCandidate.Status__c;
        this.mergeCandidate = mergeCandidate;
    }


    public class fieldOverride {
        @auraEnabled public String fieldName {get;set;}
        @auraEnabled public Object fieldValue {get;set;}
        @auraEnabled public String fieldType {get;set;}
        @auraEnabled public Id keepId {get;set;}
    }

}
