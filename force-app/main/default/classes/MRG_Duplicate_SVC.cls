/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Service for dealing with duplicate identification and merging
*/
public with sharing class MRG_Duplicate_SVC {

	/*******************************************************************************************************
	* @description get field soql for merge candidate
	* @return String fieldSoql for merge candidate
	********************************************************************************************************/ 
    public static String getMergeCandidateFieldSOQL(){

		List<String> fieldList = new List<String>();
        fieldList.addAll(Schema.getGlobalDescribe().get('MergeCandidate__c').getDescribe().fields.getMap().keyset());
        String soqlQuery='SELECT ';
        soqlQuery+= String.join(fieldList, ',');
        soqlQuery+=' FROM MergeCandidate__c';
        return soqlQuery;
    }
	/*******************************************************************************************************
	* @description get where clause
	* @return String where clause for merge candidate
	********************************************************************************************************/
    public static String getWhereClause(){
        String whereClause = ' WHERE Status__c=\'New\'';
        return whereClause;
    }
	/*******************************************************************************************************
	* @description get where clause
	* @return String where clause for merge candidate
	********************************************************************************************************/
    public static String getWhereClause(String objectType, String ruleName){
        return getWhereClause(objectType,ruleName,false);
    }
	/*******************************************************************************************************
	* @description get where clause
	* @return String where clause for merge candidate
	********************************************************************************************************/
    public static String getWhereClause(String objectType, String ruleName, Boolean showIgnored){

        String whereClause = getWhereClause();
        
        if(String.isNotBlank(objectType))
            whereClause+=' AND Object__c=:objectType';
        
        if(String.isNotBlank(ruleName))
            whereClause+=' AND Rule__c=:ruleName';
        
        whereClause += showIgnored ? '' : ' AND NotADuplicate__c=false';
        
        return whereClause;
    }
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
	* @description duplicate rules
	********************************************************************************************************/ 
    @testvisible private static List<DuplicateRule> duplicateRules {
        get {
            if(duplicateRules == null){
                duplicateRules = new List<DuplicateRule>([
                    SELECT 
                    Id,
                    DeveloperName,
                    SObjectType,
                    IsActive
                    FROM DuplicateRule
                ]);
            }
            return duplicateRules;
        }
        set;
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
        for(DuplicateRule duplicateRule:duplicateRules){
            if(duplicateRule.IsActive){
                dupeRule dr = new dupeRule(duplicateRule);
                dupeRulesByName.put(dr.ruleName,dr);
            }
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
        String soqlQuery = 'SELECT Id, Name';
        soqlQuery+=' FROM '+objectType;
        soqlQuery+=' ORDER BY CreatedDate ASC';
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
    public static List<MergeCandidate__c> processRecords(Map<Id,SObject> recordMap, String objectType) {
        List<MergeCandidate__c> mergeCandidates = new List<MergeCandidate__c>();
        List<dupeRule> duplicateRules = getActiveDuplicateRules(objectType);
        List<Id> recordIds = new List<Id>();
        recordIds.addAll(recordMap.keyset());
        List<Datacloud.DuplicateResult> duplicateResults = getDuplicateResults(recordIds, objectType);
        if(duplicateResults.size()>0)
            mergeCandidates.addAll(getMergeCandidates(recordMap,duplicateResults,duplicateRules));
        for(MergeCandidate__c mergeCandidate:mergeCandidates){
            Id keepId = String.isNotBlank(mergeCandidate.KeepRecordId__c) ? Id.valueOf(mergeCandidate.KeepRecordId__c) : null;
            if(String.isNotBlank(keepId)
                && recordMap.containsKey(keepId))
                mergeCandidate.KeepName__c = (String) recordMap.get(keepId).get('Name');
        }
        return mergeCandidates;

    } 
	/*******************************************************************************************************
	* @description processes duplicate rules for records
	* @param List<Id> records
	* @return List<Datacloud.DuplicateResult> duplicate results
	*/ 
	public static List<Datacloud.DuplicateResult> getDuplicateResults(List<SOBject> records, String objectType) {
        List<Datacloud.DuplicateResult> duplicateResults = new List<Datacloud.DuplicateResult>();
		if(duplicateRulesAreActive(records) && 
            (objectType=='Account' || objectType=='Lead' || objectType=='Contact')) {
			For(Datacloud.FindDuplicatesResult findDupeResult:Datacloud.FindDuplicates.findDuplicates(records)) {
                duplicateResults.addAll(findDupeResult.getDuplicateResults());
			}
		}
		return duplicateResults;
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
	* @description returns a list of merge candidates given duplcates and duplicate rules
    * @param recordMap a map of SObjects keyed by Id
	* @param duplicateResults a list of duplicate results
    * @param dupeRules a list of duplicate rules
	* @return List<MergeCandidate__c> a list of merge candidate records
	*/ 
    public static List<MergeCandidate__c> getMergeCandidates(Map<Id,SObject> recordMap, List<Datacloud.DuplicateResult> duplicateResults, List<dupeRule> duplicateRules){
        Map<String, dupeRule> duplicateRuleMap = new Map<String, dupeRule>();
        for(dupeRule duplicateRule:duplicateRules) {
            duplicateRuleMap.put(duplicateRule.ruleName, duplicateRule);
        }
        Map<String, MergeCandidate__c> mergeCandidates = new Map<String, MergeCandidate__c>();
        Set<String> mergedIds = new Set<String>();
        Integer i=0;
        for(Id recordId:recordMap.keyset()) {
            SObject sObj = recordMap.get(recordId);
            for(Integer d=0;d<duplicateRules.size();d++) {

                DataCloud.DuplicateResult duplicateResult = duplicateResults[i];
                String ruleName = duplicateResult.getDuplicateRule();
                dupeRule duplicateRule = duplicateRuleMap.containsKey(ruleName) ? duplicateRuleMap.get(ruleName) : null;
                MergeCandidate__c mergeCandidate = getMergeCandidate(sObj, duplicateResult,duplicateRule);
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
            }
            i++;
        }

        return mergeCandidates.values();
    }
	/*******************************************************************************************************
	* @description determines if duplicate rules are active for this object
    *
    */
    public static List<MergeCandidate__c> getMergeCandidatesFromKeptIds(Set<Id> keepIds){
        String soqlQuery = getMergeCandidateFieldSOQL();
        soqlQuery+=' WHERE KeepRecordId__c in:keepIds';
        return (List<MergeCandidate__c>) database.query(soqlQuery);

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
    public static MergeCandidate__c getMergeCandidate(SObject sObj, Datacloud.DuplicateResult duplicateResult, dupeRule duplicateRule){
        Id recordId = Id.valueOf((String) sObj.get('Id'));
        String recordName = (String) sObj.get('Name');
        Map<String,String> matchNames = new Map<String, String>();
        matchNames.put(recordId,recordName);
        MergeCandidate__c mergeCandidate = new MergeCandidate__c();
        mergeCandidate.Rule__c = duplicateResult.getDuplicateRule();
        Set<String> matchIds = new Set<String>();
        Set<String> allIds = new Set<String>();
        String objectType = recordId.getSObjectType().getDescribe().getName();
        Boolean hasMatch = false;
        for(DataCloud.MatchResult matchResult : duplicateResult.getMatchResults()) {
            hasMatch = matchResult.getSize()>0;
            if(hasMatch) {
                for(DataCloud.MatchRecord matchRecord: matchResult.getMatchRecords()) {
                    matchIds.add((String) matchRecord.getRecord().Id);
                    matchNames.put(matchRecord.getRecord().Id,(String) matchRecord.getRecord().get('Name'));
                } 
            }
        }
        if(hasMatch
            && matchIds.size()>0) {
            AllIds.add(recordId);
            AllIds.addAll(matchIds);
            List<String> matchIdList = new List<String>();
            matchIdList.addAll(allIds);
            matchIdList.sort();
            mergeCandidate.KeepRecordId__c = matchIdList[0];
            mergeCandidate.KeepName__c = String.isNotBlank(mergeCandidate.KeepRecordId__c) ? matchNames.get(mergeCandidate.KeepRecordId__c) : null;
            mergeCandidate.MergeRecordId__c = matchIdList.size()>1 ? matchIdList[1] : null;
            mergeCandidate.MergeName__c = String.isNotBlank(mergeCandidate.MergeRecordId__c) ? matchNames.get(mergeCandidate.MergeRecordId__c) : null;
            mergeCandidate.Merge2RecordId__c = matchIdList.size()>2 ? matchIdList[2] : null;
            mergeCandidate.Merge2Name__c = String.isNotBlank(mergeCandidate.Merge2RecordId__c) ? matchNames.get(mergeCandidate.Merge2RecordId__c) : null;
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
	* @description determines if duplicate rules are active for this object
	* @param List<SObject> records
	* @return Boolean
	*/ 
	public static Boolean duplicateRulesAreActive(List<SObject> records) {
		Boolean rulesAreActive = true;
		
		try {
			Datacloud.FindDuplicates.findDuplicates(records);
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
    public static Map<Id, Set<Id>> getMergeKeyMap(MergeCandidate__c candidate) {
        Map<Id, Set<Id>> mergeKeyMap = new Map<Id, Set<Id>>();        
        Id keepId = Id.valueOf(candidate.KeepRecordId__c);
        ID mergeId = Id.valueOf(candidate.MergeRecordId__c);
        Id mergeId2 = String.isNotBlank(candidate.Merge2RecordId__c) ? Id.valueOf(candidate.Merge2RecordId__c) : null;
        mergeKeyMap.put(keepId, new Set<Id>());
        mergeKeyMap.get(keepId).add(mergeId);
        if(String.isNotBlank(mergeId2)) {
            mergeKeyMap.get(keepId).add(mergeId2);
        }
        return mergeKeyMap;
    }
	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
	* @param List<MergeCandidate__c> merge candidates
	* @return Map<String, Set<String>> a map of merge Ids keyed by keep Id
	********************************************************************************************************/ 
    public static Map<Id, Set<Id>> getMergeKeyMap(List<MergeCandidate__c> mergeCandidates) {
        Map<Id, Set<Id>> mergeKeyMap = new Map<Id, Set<Id>>();
        for(MergeCandidate__c candidate:mergeCandidates) {
            mergeKeyMap.putAll(getMergeKeyMap(candidate));
        }
        return mergeKeyMap;
    }
	/*******************************************************************************************************
	* @description gets the SOQL query for the duplicate scan batch
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
		MRG_Metadata_SVC mdService = new MRG_Metadata_SVC();
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
