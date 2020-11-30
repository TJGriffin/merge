/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Service for dealing with duplicate identification and merging
*/
public with sharing class CON_Duplicate_SVC {
	/*******************************************************************************************************
	* @description get active duplicate rules for Object type
	* @param objectType
	* @return List<dupeRule> a list of duplicate rule wrappers
	********************************************************************************************************/ 
    public Static Boolean triggerDisabled;

	/*******************************************************************************************************
	* @description get active duplicate rules for Object type
	* @param objectType
	* @return List<dupeRule> a list of duplicate rule wrappers
	********************************************************************************************************/ 
    public Static Boolean getTriggerDisabled(){
        triggerDisabled = triggerDisabled == null ? false : triggerDisabled;
        return triggerDisabled;
    }


	/*******************************************************************************************************
	* @description get active duplicate rules for Object type
	* @param objectType
	* @return List<dupeRule> a list of duplicate rule wrappers
	********************************************************************************************************/ 
    public Static List<dupeRule> getActiveDuplicateRules(String objectType){

        List<dupeRule> duplicateRules = new List<dupeRule>();
        for(dupeRule dupeRule:getActiveDuplicateRules()){
            if(dupeRule.objectType.equalsIgnoreCase(objectType)){
                duplicateRules.add(dupeRule);
            }
        }
        return duplicateRules;
    }
	/*******************************************************************************************************
	* @description get active duplicate rules for Object type
	* @return List<dupeRule> a list of duplicate rule wrappers
	********************************************************************************************************/ 
    public Static List<dupeRule> getActiveDuplicateRules(){
        Map<String, dupeRule> dupeRulesByName = new Map<String, dupeRule>();
        for(DuplicateRule duplicateRule:[
            SELECT 
            Id,
            DeveloperName,
            SObjectType
            FROM DuplicateRule
            WHERE IsActive=true
        ]){
            dupeRule dr = new dupeRule(duplicateRule);
            dupeRulesByName.put(dr.ruleName,dr);
        }
        for(dupeRule drSetting:duplicateRuleSettings){
            if(dupeRulesByName.containsKey(drSetting.ruleName))
                dupeRulesByName.put(drSetting.ruleName, drSetting);
        }
        return dupeRulesByName.values();
    }
	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
	* @param objectType
	* @return String the soql Query
	********************************************************************************************************/  
    public static String getScanSOQLQuery(String objectType) {
        String soqlQuery = 'SELECT Id';
        soqlQuery+=' FROM '+objectType;
        return soqlQuery;
    }
	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
	* @param objectType
	* @return String the soql Query
	********************************************************************************************************/ 
    public static String getMergeSOQLQuery(String objectType) {
        String soqlQuery = 'SELECT Id, CreatedDate, ';
        soqlQuery+=getFieldSOQLQuery(objectType);
        soqlQuery+=' FROM '+objectType;
        return soqlQuery;
    }

	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
	* @param objectType
	* @return String the the fieldQuery
	********************************************************************************************************/ 
    public static String getFieldSOQLQuery(String objectType) {	
        List<String> fields = new List<String>();
        for (Schema.SObjectField fieldRef : Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap().values()){
            if(fieldRef.getDescribe().isAccessible()
                && fieldRef.getDescribe().isUpdateable()
                && !fieldRef.getDescribe().getName().equalsIgnoreCase('IndividualId'))
                fields.add(fieldRef.getDescribe().getName());
        }

        return String.join(fields,',');
    }

	/*******************************************************************************************************
	* @description processes duplicate rules for records
	* @param List<Id> records
    * @param String objectType
	* @return List<MergeCandidate__c>
	*/ 
    public static List<MergeCandidate__c> processRecords(Set<Id> recordIdSet, String objectType) {
        List<MergeCandidate__c> mergeCandidates = new List<MergeCandidate__c>();
        List<dupeRule> duplicateRules = getActiveDuplicateRules(objectType);
        List<Id> recordIds = new List<Id>();
        recordIds.addAll(recordIdSet);
        List<Datacloud.DuplicateResult> duplicateResults = getDuplicateResults(recordIds, objectType);
        if(duplicateResults.size()>0)
            mergeCandidates.addAll(getMergeCandidates(recordIds,duplicateResults,duplicateRules));

        return mergeCandidates;

    }    
	/*******************************************************************************************************
	* @description processes duplicate rules for records
	* @param List<Id> records
	* @return List<Datacloud.DuplicateResult> duplicate results
	*/ 
	public static List<Datacloud.DuplicateResult> getDuplicateResults(List<Id> recordIds, String objectType) {
        List<Datacloud.DuplicateResult> duplicateResults = new List<Datacloud.DuplicateResult>();
		if(duplicateRulesAreActive(recordIds) && 
            (objectType=='Account' || objectType=='Lead' || objectType=='Contact')) {
			For(Datacloud.FindDuplicatesResult findDupeResult:Datacloud.FindDuplicatesByIds.findDuplicatesByIds(recordIds)) {
                duplicateResults.addAll(findDupeResult.getDuplicateResults());
			}
		}
		return duplicateResults;
	}
	/*******************************************************************************************************
	* @description determines if duplicate rules are active for this object
	* @param List<Datacloud.DuplicateResult>
	* @return Boolean
	*/ 
    public static List<MergeCandidate__c> getMergeCandidates(List<Id> recordIds, List<Datacloud.DuplicateResult> duplicateResults, List<dupeRule> duplicateRules){
        Map<String, dupeRule> duplicateRuleMap = new Map<String, dupeRule>();
        for(dupeRule duplicateRule:duplicateRules) {
            duplicateRuleMap.put(duplicateRule.ruleName, duplicateRule);
        }
        Map<String, MergeCandidate__c> mergeCandidates = new Map<String, MergeCandidate__c>();
        Set<String> mergedIds = new Set<String>();
        Integer i=0;
        for(Id recordId:recordIds) {
            for(Integer d=0;d<duplicateRules.size();d++) {

                DataCloud.DuplicateResult duplicateResult = duplicateResults[i];
                String ruleName = duplicateResult.getDuplicateRule();
                dupeRule duplicateRule = duplicateRuleMap.containsKey(ruleName) ? duplicateRuleMap.get(ruleName) : null;
                MergeCandidate__c mergeCandidate = getMergeCandidate(recordId, duplicateResult,duplicateRule);
                system.debug('merge candidate');
                system.debug(JSON.serialize(duplicateRule));
                system.debug(JSON.serialize(mergeCandidate));
                if(mergeCandidate != null) {
                    String keepId = mergeCandidate.KeepRecordId__c;
                    String mergeId = mergeCandidate.MergeRecordId__c;
                    mergeCandidate.AutoMerge__c = mergeCandidate.Rule__c.equalsIgnoreCase(duplicateRule.ruleName) ? duplicateRule.autoMerge : mergeCandidate.AutoMerge__c;
                    if(!mergedIds.contains(keepId)
                        && !mergedIds.contains(mergeId)) {
                        mergeCandidates.put(keepId, mergeCandidate);
                        mergedIds.add(keepId);
                        mergedIds.add(mergeId);
                    }
                }
                i++;
            }
        }

        return mergeCandidates.values();
    }
	/*******************************************************************************************************
	* @description determines if duplicate rules are active for this object
    *
    */
    public static Map<Id,Id> getMergeCandidateIdByKeepId(List<MergeCandidate__c> mergeRecords){
        Map<Id,Id> mergecandidateIdByKeepId = new Map<Id,Id>();
        for(MergeCandidate__c record:mergeRecords){
            mergeCandidateIdByKeepId.put(record.KeepRecordId__c,record.Id);
        }
        return mergeCandidateIdByKeepId;

    }
	/*******************************************************************************************************
	* @description determines if duplicate rules are active for this object
    * @param recordid
	* @param duplicateResult
	* @param dupeRule
	* @return MergeCandidate__c
	*/ 
    public static MergeCandidate__c getMergeCandidate(Id recordId, Datacloud.DuplicateResult duplicateResult, dupeRule duplicateRule){
        MergeCandidate__c mergeCandidate = new MergeCandidate__c();
        mergeCandidate.Rule__c = duplicateResult.getDuplicateRule();
        Set<String> matchIds = new Set<String>();
        String objectType = recordId.getSObjectType().getDescribe().getName();
        Boolean hasMatch = false;
        for(DataCloud.MatchResult matchResult : duplicateResult.getMatchResults()) {
            hasMatch = matchResult.getSize()>0;
            if(hasMatch) {
                for(DataCloud.MatchRecord matchRecord: matchResult.getMatchRecords()) {
                    matchIds.add((String) matchRecord.getRecord().Id);
                } 
            }
        }
        if(hasMatch
            && matchIds.size()>0) {
            List<String> matchIdList = new List<String>();
            matchIdList.addAll(matchIds);
            mergeCandidate.KeepRecordId__c = recordId;
            mergeCandidate.MergeRecordId__c = matchIdList.size()>0 ? matchIdList[0] : null;
            mergeCandidate.Merge2RecordId__c = matchIdList.size()>1 ? matchIdList[1] : null;
            mergeCandidate.Object__c = objectType;
            mergeCandidate.Status__c = 'New';
        } else {
            mergeCandidate = null;
        }
        return mergeCandidate;

    }
	/*******************************************************************************************************
	* @description determines if duplicate rules are active for this object
	* @param List<SObject> records
	* @return Boolean
	*/ 
	public static Boolean duplicateRulesAreActive(List<Id> recordIds) {
		Boolean rulesAreActive = true;
		
		try {
			Datacloud.FindDuplicatesByIds.findDuplicatesByIds(recordIds);
		} catch(Exception e) {
			rulesAreActive = false;
		} finally {
			return rulesAreActive;
		}
		return rulesAreActive;
	}
	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
	* @param mergeKeyMap
	* @return Set<String> all Ids
	********************************************************************************************************/ 
    public static Set<Id> getAllIds(Map<Id, Set<Id>> mergeKeyMap) {
        Set<Id> allIds = new Set<Id>();
        for(Id keepKey:mergeKeyMap.keyset()) {
            allIds.add(keepKey);
            allIds.addAll(mergeKeyMap.get(keepKey));
        }
        return allIds;
    }
	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
	* @param List<MergeCandidate__c> merge candidates
	* @return Map<String, Set<String>> a map of merge Ids keyed by keep Id
	********************************************************************************************************/ 
    public static Map<Id, Set<Id>> getMergeKeyMap(List<MergeCandidate__c> mergeCandidates) {
        Map<Id, Set<Id>> mergeKeyMap = new Map<Id, Set<Id>>();
        for(MergeCandidate__c candidate:mergeCandidates) {
            Id keepId = Id.valueOf(candidate.KeepRecordId__c);
            ID mergeId = Id.valueOf(candidate.MergeRecordId__c);
            Id mergeId2 = String.isNotBlank(candidate.Merge2RecordId__c) ? Id.valueOf(candidate.Merge2RecordId__c) : null;
            mergeKeyMap.put(keepId, new Set<Id>());
            mergeKeyMap.get(keepId).add(mergeId);
            if(String.isNotBlank(mergeId2)) {
                mergeKeyMap.get(keepId).add(mergeId2);
            }
        }
        return mergeKeyMap;
    }
	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
	* @return List<dupeRule>
	********************************************************************************************************/ 
    public static List<dupeRule> duplicateRuleSettings {
        get {
            if(duplicateRuleSettings == null) {
                List<dupeRule> dupeSettings = new List<dupeRule>();
                for(DuplicateRuleSettings__mdt dupeSetting:[
                    SELECT 
                    Id,
                    Label,
                    QualifiedAPIName,
                    Object__c,
                    Object__r.QualifiedAPIName,
                    AutoMerge__c,
                    RuleName__c
                    FROM DuplicateRuleSettings__mdt
                ]){
                    dupeSettings.add(new dupeRule(dupeSetting));
                }
                duplicateRuleSettings = dupeSettings;
            }
            return duplicateRuleSettings;
        }
        set;
    }
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param dupeRules the mergeFieldWrap collection to save
	* @return  String metaData deploy job Id
	*/	
	public static String saveDuplicateRules(List<dupeRule> dupeRules) {
		CON_Metadata_SVC mdService = new CON_Metadata_SVC();
		List<DuplicateRuleSettings__mdt> dupeRuleSettings = new List<DuplicateRuleSettings__mdt>();
		for(dupeRule dupeRule:dupeRules) {
			dupeRuleSettings.add(getDuplicateRuleSettingFromObject(dupeRule));
		}
		List<Metadata.CustomMetadata> mdRecords = new List<Metadata.CustomMetadata>();
		// get metadata and add to record list
		for(DuplicateRuleSettings__mdt dupeRuleSetting:dupeRuleSettings) {
			Metadata.CustomMetadata mdRecord =  mdService.getMetaDataRecord(dupeRuleSetting);
			mdRecords.add(mdRecord);
		}
		// deploy record via metadata api
		return mdService.deployMetadataRecords(mdRecords);
	}
	/*******************************************************************************************************
	* @description duplicate rule
	*/ 
    public static DuplicateRuleSettings__mdt getDuplicateRuleSettingFromObject(dupeRule dupeRule) {
        DuplicateRuleSettings__mdt dupeSetting = new DuplicateRuleSettings__mdt(
            Label = dupeRule.name,
            RuleName__c = dupeRule.ruleName,
            AutoMerge__c = dupeRule.autoMerge
        );
        String qualifiedName = dupeSetting.Label.contains('_') ? dupeSetting.label.replace('_','') : dupeSetting.label;
        qualifiedName = !qualifiedName.startsWith('DR') ? 'DR'+qualifiedName : qualifiedName;
        dupeSetting.qualifiedAPIName = qualifiedName;
        Map<String, Object> dupeSettingJSON = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(dupeSetting));
		Map<String, Object> objField = new Map<String, Object> {
			'attributes' => new Map<String, Object> {
				'type' => 'EntityDefinition'
			},
			'QualifiedAPIName' => dupeRule.objectType
		};
        dupeSettingJSON.put('Object__r',objField);
        dupeSetting = (DuplicateRuleSettings__mdt) JSON.deserialize(JSON.serialize(dupeSettingJSON),DuplicateRuleSettings__mdt.class);
        return dupeSetting;
    }
	/*******************************************************************************************************
	* @description duplicate rule
	*/ 
    public class dupeRule {
        /***
        * @description rule name
        */ 
        @auraEnabled 
        public String name;
        /***
        * @description rule name
        */ 
        @auraEnabled 
        public String ruleName;
        /***
        * @description object Type
        */ 
        @auraEnabled 
        public String objectType;
        /***
        * @description object Type
        */ 
        @auraEnabled 
        public Boolean autoMerge;
        /*******************************************************************************************************
        * @description constructor
        */ 
        public dupeRule(){

        }
        /*******************************************************************************************************
        * @description constructor override
        */ 
        public dupeRule(DuplicateRule duplicateRule){
            this.name = duplicateRule.DeveloperName;
            this.ruleName = duplicateRule.DeveloperName;
            this.objectType = duplicateRule.SObjectType;
            this.autoMerge = false;
        }
        /*******************************************************************************************************
        * @description constructor override
        */ 
        public dupeRule(DuplicateRuleSettings__mdt dupeRuleSetting){
            this.name = dupeRuleSetting.label;
            this.ruleName = dupeRuleSetting.RuleName__c;
            this.objectType = dupeRuleSetting.Object__r.QualifiedAPIName;
            this.autoMerge = dupeRuleSetting.AutoMerge__c;
        }
    }
}
