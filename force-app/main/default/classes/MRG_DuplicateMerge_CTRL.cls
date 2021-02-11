/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Service for dealing with duplicate identification and merging
*/
public with sharing class MRG_DuplicateMerge_CTRL {
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<mergeGroup> 
	*/
    @AuraEnabled(cacheable=TRUE)
    public static Integer getCount(String objectType, String ruleName){
        String soqlQuery= 'SELECT Count() FROM MergeCandidate__c ';
        soqlQuery+=MRG_Duplicate_SVC.getWhereClause(objectType, ruleName);
        Integer result = (Integer) Database.countQuery(soqlQuery);
        return result;
    }

	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<mergeGroup> 
	*/
    @AuraEnabled(cacheable=TRUE)
    public static List<mergeGroup> getMergeGroups(String objectType, String ruleName, Integer limitAmt, Integer offsetAmt){
        system.debug('object: '+objectType+' / ruleName: '+ruleName+' / limitAmt: '+limitAmt+' / offsetAmt: '+offsetAmt);
        limitAmt = limitAmt == null ? 200 : limitAmt;
        String soqlQuery= MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
        soqlQuery+=MRG_Duplicate_SVC.getWhereClause(objectType,ruleName);
        soqlQuery+=' ORDER BY CreatedDate DESC, Id ASC';
        soqlQuery+=' LIMIT '+limitAmt;
        if(offsetAmt != null
            && offsetAmt < 2000
            && offsetAmt > 0)
            soqlQuery+=' OFFSET :offsetAmt';
        List<MergeCandidate__c> mergeCandidates = (List<MergeCandidate__c>) Database.query(soqlQuery);
        return getMergeGroupsFromCandidates(mergeCandidates);
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<mergeGroup> 
	*/
    @AuraEnabled(cacheable=TRUE)
    public static List<MRG_Duplicate_SVC.dupeRule> getRules(String objectType){
        return MRG_Duplicate_SVC.getActiveDuplicateRules(objectType);
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param recordId recordId to merge
	* @return String response
	*/
    @AuraEnabled
    public static String mergeRecord(String recordId){
        system.debug('merge record: '+recordId);
        String response;
        String soqlQuery  = MRG_Duplicate_SVC.getMergeCandidateFieldSOQL();
        soqlQuery+=' WHERE Id=:recordId';
        List<MergeCandidate__c> mergeCandidates = (List<MergeCandidate__c>) database.query(soqlQuery);
        if(mergeCandidates.size()>0) {
            MRG_Merge_SVC.processMergesFromBatch(mergeCandidates, mergeCandidates[0].Object__c,false);
            response = 'Records merged';
        } else {
            response = 'an error occurred';
        }
        return response;
    }

	/*******************************************************************************************************
	* @description returns the records for preview
	* @param recordId recordId to merge
	* @return String response
	*/
    @AuraEnabled
    public static String previewRecord(String recordId){
        String response;

        return response;
    }
	/*******************************************************************************************************
	* @description sets the merge candidate to ignore
	* @param recordId recordId to merge
	* @return String response
	*/
    @AuraEnabled
    public static String removeRecord(String recordId){
        String response;
        MergeCandidate__c mc = new MergeCandidate__c(
            Id=recordId,
            NotADuplicate__c=true
        );
        try {
            update mc;
            response = 'Record set to not a duplicate';
        } catch(Exception e){
            response = e.getMessage();
        }
        return response;
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param  List<MergeCandidate__c> merge candidates
	* @return  List<mergeGroup>  the mergeGroup wrapper list
	*/
    public static List<mergeGroup> getMergeGroupsFromCandidates(List<MergeCandidate__c> mergeCandidates){
        List<mergeGroup> mergeGroups = new List<mergeGroup>();
        for(MergeCandidate__c mergeCandidate:mergeCandidates){
            mergeGroups.add(new mergeGroup(mergeCandidate));
        }
        return mergeGroups;
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<MergeCandidate__c> a list of merge candidates to save
	*/
    public static List<SObject> getSObjectsFromMergeGroup(String mergeGroupJSON){
        mergeGroup mergeGroup = (mergeGroup) JSON.deserialize(mergeGroupJSON, mergeGroup.class);
        List<String> recordIds = mergeGroup.recordIds;
        String objectType = mergeGroup.objectType;
        String soqlQuery = MRG_Merge_SVC.getSOQLQuery(objectType);
        soqlQuery+=' WHERE Id IN:recordIds';
        return database.query(soqlQuery);
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param List<mergeGroup> the mergeGroup wrapper list
	* @return  List<MergeCandidate__c> a list of merge candidates to save
	*/
    public static List<MergeCandidate__c> getMergeCandidateFromMergeGroup(List<mergeGroup> mergeGroups){
        List<MergeCandidate__c> mergeCandidates = new List<MergeCandidate__c>();
        for(mergeGroup mergeGroup:mergeGroups){
            mergeCandidates.add(getMergeCandidateFromMergeGroup(mergeGroup));
        }
        return mergeCandidates;
    }

	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param mergeGroup the mergeGroup wrapper
	* @return  MergeCandidate__c the MergeCandidate__c object
	*/
    public static MergeCandidate__c getMergeCandidateFromMergeGroup(mergeGroup mergeGroup){
        MergeCandidate__c mergeCandidate = new MergeCandidate__c(
            KeepRecordId__c = mergeGroup.keepId,
            MergeRecordId__c = mergeGroup.mergeId,
            Object__c = mergeGroup.objectType,
            Rule__c = mergeGroup.rule,
            Status__c = mergeGroup.status,
            Merge2RecordId__c = mergeGroup.merge2Id
        );
        if(String.isNotBlank(mergeGroup.id))
            mergeCandidate.Id = mergeGroup.id;
        
        return mergeCandidate;
    }


	/*******************************************************************************************************
	* @description merge group
	*/ 
    public class mergeGroup {
        @AuraEnabled
        public String id;
        @AuraEnabled
        public String name;
        @AuraEnabled
        public String keepId;  
        @AuraEnabled
        public String keepName;  
        @AuraEnabled
        public String mergeId; 
        @AuraEnabled
        public String mergeName; 
        @AuraEnabled
        public String merge2Id;
        @AuraEnabled
        public String merge2Name;
        @AuraEnabled
        public String objectType;
        @AuraEnabled
        public String rule;
        @AuraEnabled
        public String status;
        @AuraEnabled
        public Boolean autoMerge;
        @AuraEnabled
        public Datetime createdDate; 
        @AuraEnabled
        public Datetime lastModifiedDate;  
        @AuraEnabled
        public List<String> recordIds;
        @AuraEnabled
        public String link {
            get {
                return '/'+this.id;
            }
        }
        @AuraEnabled
        public String keepLink {
            get {
                return '/'+this.keepId;
            }
        }
        @AuraEnabled
        public String mergeLink {
            get {
                return '/'+this.mergeId;
            }
        }
        @AuraEnabled
        public String merge2Link {
            get {
                String link = null;
                if(String.isNotBlank(merge2Id)) {
                    link = '/'+this.merge2Id;
                }
                return link;
            }
        }

        public mergeGroup(MergeCandidate__c mergeCandidate){
            this.id = mergeCandidate.Id;
            this.name = mergeCandidate.name;
            this.keepId = mergeCandidate.KeepRecordId__c;
            this.keepName = mergeCandidate.KeepName__c;
            this.mergeId = mergeCandidate.MergeRecordId__c;
            this.mergeName = mergeCandidate.MergeName__c;
            this.merge2Id = mergeCandidate.Merge2RecordId__c;
            this.merge2Name = mergeCandidate.Merge2Name__c;
            this.objectType = mergeCandidate.Object__c;
            this.rule = mergeCandidate.Rule__c;
            this.status = mergeCandidate.Status__c;
            this.autoMerge = mergeCandidate.AutoMerge__c;
            this.createdDate = mergeCandidate.CreatedDate;
            this.lastModifiedDate = mergeCandidate.LastModifiedDate;
            this.recordIds = new List<String>();
            if(String.isNotBlank(this.keepId))
                this.recordIds.add(this.keepId);
            if(String.isNotBlank(this.mergeId))
                this.recordIds.add(this.mergeId);
            if(String.isNotBlank(this.merge2Id))
                this.recordIds.add(this.merge2Id);
        }      
    }
}
