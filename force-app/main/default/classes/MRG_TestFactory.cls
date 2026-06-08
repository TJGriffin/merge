/**
* @author tj@tjgriffin.com
* @group Merge
* @description shared test data factory and merge harness for the Merge Control test suite.
* Builds Accounts/Contacts with controlled CreatedDate ordering, registers in-memory
* MergeFieldSetting__mdt / PreviewFields__mdt, builds MergeCandidate__c records, drives merges
* through the production service path, and provides assertion helpers.
*/
@isTest
public class MRG_TestFactory {

	/*******************************************************************************************************
	* @description inserts n Accounts named Account 0..n-1
	* @param n the number of accounts to create
	* @return List<Account> the inserted accounts
	*/
	public static List<Account> accounts(Integer n) {
		List<Account> accs = new List<Account>();
		for(Integer i=0; i<n; i++)
			accs.add(new Account(Name='Account '+i));
		insert accs;
		return accs;
	}

	/*******************************************************************************************************
	* @description inserts n Contacts named Test Contact{i}
	* @param n the number of contacts to create
	* @return List<Contact> the inserted contacts
	*/
	public static List<Contact> contacts(Integer n) {
		List<Contact> cons = new List<Contact>();
		for(Integer i=0; i<n; i++)
			cons.add(new Contact(FirstName='Test', LastName='Contact'+i));
		insert cons;
		return cons;
	}

	/*******************************************************************************************************
	* @description sets the CreatedDate on a record so preservation rules that depend on record age
	* (Oldest/Newest) can be exercised deterministically
	* @param recordId the record to backdate
	* @param dt the created date to set
	*/
	public static void setCreatedDate(Id recordId, Datetime dt) {
		Test.setCreatedDate(recordId, dt);
	}

	/*******************************************************************************************************
	* @description registers a list of merge field settings in memory on MRG_Merge_SVC so the service
	* reads them without a real metadata deploy
	* @param fields the merge field settings to register
	*/
	public static void registerMergeFields(List<MergeFieldSetting__mdt> fields) {
		MRG_Merge_SVC.mergeFields = fields;
	}

	/*******************************************************************************************************
	* @description registers a list of preview fields in memory on MRG_Merge_SVC
	* @param fields the preview fields to register
	*/
	public static void registerPreviewFields(List<PreviewFields__mdt> fields) {
		MRG_Merge_SVC.previewFields = fields;
	}

	/*******************************************************************************************************
	* @description builds an in-memory MergeFieldSetting__mdt with the read-only Object__r / Field__r
	* relationships populated via JSON injection
	* @param objectName the SObject api name
	* @param fieldName the field api name
	* @param type Track or Preserve
	* @param rule the preservation rule (Oldest/Newest/Largest/Smallest/Related Field), may be null
	* @return MergeFieldSetting__mdt the constructed setting
	*/
	public static MergeFieldSetting__mdt mergeField(String objectName, String fieldName, String type, String rule) {
		return mergeField(objectName, fieldName, type, rule, null);
	}

	/*******************************************************************************************************
	* @description builds an in-memory MergeFieldSetting__mdt, optionally with a RelatedField__r
	* @param objectName the SObject api name
	* @param fieldName the field api name
	* @param type Track or Preserve
	* @param rule the preservation rule
	* @param relatedFieldName the related (paired) field api name, may be null
	* @return MergeFieldSetting__mdt the constructed setting
	*/
	public static MergeFieldSetting__mdt mergeField(String objectName, String fieldName, String type, String rule, String relatedFieldName) {
		MergeFieldSetting__mdt mergeField = new MergeFieldSetting__mdt();
		Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(mergeField));
		fieldMap.put(MergeFieldSetting__mdt.Label.getDescribe().getName(), 'test'+fieldName);
		fieldMap.put(MergeFieldSetting__mdt.DeveloperName.getDescribe().getName(), 'test'+fieldName);
		fieldMap.put(MergeFieldSetting__mdt.Type__c.getDescribe().getName(), type);
		fieldMap.put(MergeFieldSetting__mdt.PreservationRule__c.getDescribe().getName(), rule);
		fieldMap.put('Object__r', entityRef('EntityDefinition', objectName));
		fieldMap.put('Field__r', entityRef('EntityParticle', fieldName));
		if(String.isNotBlank(relatedFieldName))
			fieldMap.put('RelatedField__r', entityRef('EntityParticle', relatedFieldName));
		return (MergeFieldSetting__mdt) JSON.deserialize(JSON.serialize(fieldMap), MergeFieldSetting__mdt.class);
	}

	/*******************************************************************************************************
	* @description builds an in-memory PreviewFields__mdt with read-only relationships via JSON injection
	* @param objectName the SObject api name
	* @param fieldName the field api name
	* @param hidden whether the field is hidden from the preview
	* @return PreviewFields__mdt the constructed preview field
	*/
	public static PreviewFields__mdt previewField(String objectName, String fieldName, Boolean hidden) {
		PreviewFields__mdt pField = new PreviewFields__mdt();
		Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(pField));
		fieldMap.put(PreviewFields__mdt.Label.getDescribe().getName(), 'test'+fieldName);
		fieldMap.put(PreviewFields__mdt.DeveloperName.getDescribe().getName(), 'test'+fieldName);
		fieldMap.put(PreviewFields__mdt.Disable__c.getDescribe().getName(), hidden);
		fieldMap.put('Object__r', entityRef('EntityDefinition', objectName));
		fieldMap.put('Field__r', entityRef('EntityParticle', fieldName));
		return (PreviewFields__mdt) JSON.deserialize(JSON.serialize(fieldMap), PreviewFields__mdt.class);
	}

	/*******************************************************************************************************
	* @description builds (unsaved) a JSON shape for a metadata relationship field
	* @param entityType EntityDefinition or EntityParticle
	* @param apiName the QualifiedAPIName value
	* @return Map<String, Object> the relationship shape
	*/
	private static Map<String, Object> entityRef(String entityType, String apiName) {
		return new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => entityType },
			'QualifiedAPIName' => apiName
		};
	}

	/*******************************************************************************************************
	* @description inserts a MergeCandidate__c for a keep + merge pair
	* @param keepId the record to keep
	* @param mergeId the record to merge into keep
	* @param objectType the SObject type
	* @return MergeCandidate__c the inserted candidate
	*/
	public static MergeCandidate__c mergeCandidate(Id keepId, Id mergeId, String objectType) {
		return mergeCandidate(keepId, mergeId, null, objectType);
	}

	/*******************************************************************************************************
	* @description inserts a MergeCandidate__c for a keep + up to two merge records
	* @param keepId the record to keep
	* @param mergeId the first record to merge
	* @param merge2Id the second record to merge, may be null
	* @param objectType the SObject type
	* @return MergeCandidate__c the inserted candidate
	*/
	public static MergeCandidate__c mergeCandidate(Id keepId, Id mergeId, Id merge2Id, String objectType) {
		MergeCandidate__c mc = new MergeCandidate__c(
			KeepRecordId__c = keepId,
			MergeRecordId__c = mergeId,
			Merge2RecordId__c = merge2Id,
			Object__c = objectType,
			Rule__c = 'test',
			Status__c = 'New',
			AutoMerge__c = true
		);
		insert mc;
		return mc;
	}

	/*******************************************************************************************************
	* @description serializes a list of field overrides onto a candidate's Override__c and updates it
	* @param candidate the candidate to set overrides on
	* @param overrides the overrides to apply
	*/
	public static void setOverrides(MergeCandidate__c candidate, List<MRG_MergeCandidate.fieldOverride> overrides) {
		candidate.Override__c = JSON.serialize(overrides);
		update candidate;
	}

	/*******************************************************************************************************
	* @description builds a single field override
	* @param keepId the kept record id the override applies to
	* @param fieldName the field api name
	* @param fieldValue the raw string value
	* @param fieldType the SOAP type name (BOOLEAN/DATE/DATETIME/DOUBLE/INTEGER/STRING/...)
	* @return MRG_MergeCandidate.fieldOverride the override
	*/
	public static MRG_MergeCandidate.fieldOverride fieldOverride(Id keepId, String fieldName, String fieldValue, String fieldType) {
		MRG_MergeCandidate.fieldOverride o = new MRG_MergeCandidate.fieldOverride();
		o.keepId = keepId;
		o.fieldName = fieldName;
		o.fieldValue = fieldValue;
		o.fieldType = fieldType;
		return o;
	}

	/*******************************************************************************************************
	* @description drives a merge through the production service path (not raw DML merge)
	* @param candidates the candidates to process
	* @param objectType the SObject type
	*/
	public static void runMerge(List<MergeCandidate__c> candidates, String objectType) {
		MRG_Merge_SVC.processMergesFromBatch(candidates, objectType);
	}

	/*******************************************************************************************************
	* @description re-queries a kept record and returns the value of a single field after a merge
	* @param recordId the kept record id
	* @param objectType the SObject type
	* @param fieldName the field api name
	* @return Object the field value
	*/
	public static Object keptValue(Id recordId, String objectType, String fieldName) {
		SObject rec = Database.query('SELECT '+String.escapeSingleQuotes(fieldName)+' FROM '+String.escapeSingleQuotes(objectType)+' WHERE Id=:recordId');
		return rec.get(fieldName);
	}

	/*******************************************************************************************************
	* @description returns the MergeFieldHistory__c entries for a kept record keyed by field
	* (MergeValueType__c), lowercased and trimmed
	* @param keepId the kept record id
	* @return Map<String, MergeFieldHistory__c> history keyed by field
	*/
	public static Map<String, MergeFieldHistory__c> historyByField(Id keepId) {
		Map<String, MergeFieldHistory__c> historyMap = new Map<String, MergeFieldHistory__c>();
		for(MergeFieldHistory__c h : [
			SELECT Id, KeptRecordId__c, MergedRecordId__c, KeptValue__c, MergeValue__c, MergeValueType__c
			FROM MergeFieldHistory__c
			WHERE KeptRecordId__c = :keepId
		]) {
			if(h.MergeValueType__c != null)
				historyMap.put(h.MergeValueType__c.trim().toLowerCase(), h);
		}
		return historyMap;
	}
}
