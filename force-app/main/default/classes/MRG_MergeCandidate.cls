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
    * @description collection of fields that have different values
    */
    @AuraEnabled public List<String> fields;

    @AuraEnabled public String status;

    @AuraEnabled public MergeCandidate__c mergeCandidate;

    @AuraEnabled public List<MergeFieldHistory__c> fieldHistory;

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
        this.recordID = mergeCandidate.Id;
        this.keepRecord = keepRecord;
        this.mergeRecord1 = mergeRecords[0];
        if(mergeRecords.size()>1)
            this.mergeRecord2 = mergeRecords[1];
        this.mergeResultRecord =  mergeResult.updateRecords != null && mergeResult.updateRecords.size()>0 ? mergeResult.updateRecords[0] : keepRecord;
        this.fieldHistory = mergeResult.fieldHistory;
        this.fields = new List<String>();
        this.fields.addAll(fields);
        this.status = mergeCandidate.Status__c;
        this.mergeCandidate = mergeCandidate;
    }

}
