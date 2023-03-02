public with sharing class MRG_MergeCandidate_SVC {
    /*******************************************************************************************************
    * @description gets a merge candidate given a merge candidate recordId
    * @param recordId the merge candidate recordId
    * @return MRG_MergeCandidate the mergecandidate record
    */  
    public static MRG_MergeCandidate getMergeCandidate(String recordId) {
        MergeCandidate__c candidate = [
            SELECT Id,
            AutoMerge__c,
            Data__c,
            KeepName__c,
            KeepRecordId__c,
            Merge2Name__c,
            Merge2RecordId__c,
            MergeName__c,
            MergeRecordId__c,
            NotADuplicate__c,
            Object__c,
            Override__c,
            Rule__c,
            Status__c
            FROM MergeCandidate__c
            WHERE Id=:recordId
        ];
        
        return getMergeCandidate(candidate, candidate.Object__c);
    }

    /*******************************************************************************************************
    * @description gets a merge candidate given a merge candidate recordId
    * @param recordId the merge candidate recordId
    * @return MRG_MergeCandidate the mergecandidate record
    */  
    public static MRG_MergeCandidate getMergeCandidate(MergeCandidate__c candidate, String objectType) {

        Map<Id, Set<Id>> mergeKeyMap = MRG_Duplicate_SVC.getMergeKeyMap(candidate);
        Set<Id> recordIds = MRG_Duplicate_SVC.getAllIds(mergeKeyMap);
        MRG_Merge_SVC.mergeHistoryResult mergeResult = MRG_Merge_SVC.getMergeHistoryResult(new List<MergeCandidate__c>{candidate},objectType);
        Map<String, Schema.SObjectField> fieldmap = Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap();
        Set<String> fieldDifferences = new Set<String>();
        Set<String> writeableFields = MRG_Merge_SVC.getWriteableFields(objectType);
        Map<Id, SObject> objectMap = mergeResult.objectMap;
        SObject keepRecord;
        List<SObject> mergeRecords = new List<SObject>();
        for(Id keepId:mergeKeyMap.keyset()){
            if(objectMap.containsKey(keepId)){
                keepRecord = objectMap.get(keepId);
                Integer i=0;
                for(Id mergeRecordId:mergeKeyMap.get(keepId)){
                    if(objectMap.containsKey(mergeRecordId)){
                        SObject testRecord = objectMap.get(mergeRecordId);
                        mergeRecords.add(testRecord);
                        for(String field:writeableFields){
                            if(fieldDifferences.contains(field))
                                continue;
                            Object fieldVal = keepRecord.get(field);
                            if(testRecord.get(field) != fieldVal) {
                                String fieldApiName = fieldmap.containsKey(field) ? fieldmap.get(field).getDescribe().getName() : field;
                                fieldDifferences.add(fieldApiName);

                            }
                        }
                    }
                    i++;
                }
            }
        }

        return new MRG_MergeCandidate(candidate,keepRecord,mergeRecords,mergeResult,fieldDifferences);
    }
}
