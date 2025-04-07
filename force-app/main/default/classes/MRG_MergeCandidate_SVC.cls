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
    /*******************************************************************************************************
    * @description gets a soql query for the batch job
    * @return String
    */ 
    public static String getBatchSoql(){
        String soql = 'SELECT Id'
        +', KeepRecordId__c'
        +', MergeRecordId__c'
        +', Merge2RecordId__c'
        +', Object__c'
        +', Status__c'
        +' FROM MergeCandidate__c'
        +' WHERE Status__c !=\'Processed\'';

        return soql;
    }

    /*******************************************************************************************************
    * @description processes the records from the batch job
    * @param mergeCandidates a list of merge candidates
    */ 
    public static void processMergeCandidatesFromBatch(List<MergeCandidate__c> mergeCandidates){
        Map<Id, List<SObject>> recordMap = getObjectsFromMergeCandidates(mergeCandidates);
        List<MergeCandidate__c> updateRecords = new List<MergeCandidate__c>();
        for(MergeCandidate__c mc:mergeCandidates){
            if(mc.Status__c == 'Processed'){
                continue;
            }
            List<SObject> records = !recordMap.containsKey(mc.Id) ? new List<SObject>() : recordMap.get(mc.Id);
            if(records.size() <= 1){
                String keepRecordId = records[0].Id;
                mc.Status__c = 'Processed';
                if(mc.KeepRecordId__c != keepRecordId){
                    mc.MergeRecordId__c = mc.KeepRecordId__c;
                    mc.KeepRecordId__c = keepRecordId;
                }
                updateRecords.add(mc);
            }
        }

        database.update(updateRecords);
    }

    /*******************************************************************************************************
    * @description queries the database for records associated with the merge candidate
    * @param mergeCandidates
    * @return MRG_MergeCandidate the mergecandidate record
    */ 
    public static Map<Id, List<SObject>> getObjectsFromMergeCandidates(List<MergeCandidate__c> mergeCandidates){
        Map<Id, List<SObject>> recordMap = new Map<Id, List<SObject>>();

        Map<String, List<Id>> idsByObjectType = new Map<String, List<Id>>();

        for(MergeCandidate__c mc:mergeCandidates){
            String objectType = mc.Object__c;
            Set<Id> ids = MRG_Duplicate_SVC.getAllIds(MRG_Duplicate_SVC.getMergeKeyMap(mc));

            for(Id id:ids){
                if(!idsByObjectType.containsKey(objectType)){
                    idsByObjectType.put(objectType, new List<Id>());
                }
                idsByObjectType.get(objectType).add(id);
            }
        }

        List<SObject> records = new List<SObject>();

        for(String objectType:idsByObjectType.keySet()){
            List<Id> ids = idsByObjectType.get(objectType);
            String soqlQuery = 'SELECT Id FROM ' + objectType + ' WHERE Id IN :ids';
            records.addAll(Database.query(soqlQuery));
        }

        Map<Id, SObject> mergeRecordMap = new Map<Id, SObject>(records);

        for(MergeCandidate__c mc:mergeCandidates){
            Id mcId = mc.Id;
            recordMap.put(mcId, new List<SObject>());
            Set<Id> ids = MRG_Duplicate_SVC.getAllIds(MRG_Duplicate_SVC.getMergeKeyMap(mc));

            for(Id recordId:ids){
                if(mergeRecordMap.containsKey(recordId)){
                    SObject record = mergeRecordMap.get(recordId);
                    recordMap.get(mcId).add(record);
                }
            }
        }
        return recordMap;
    }



}