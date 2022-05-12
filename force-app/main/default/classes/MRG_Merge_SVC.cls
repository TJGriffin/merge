/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Service for dealing with contact merges
*/
public with sharing class MRG_Merge_SVC {
	/*******************************************************************************************************
	* @description get the custom settings
	* @return MergeControlSettings__c settings
	*/	
	public static MergeControlSettings__c getSettings(){
		MergeControlSettings__c settings = MergeControlSettings__c.getOrgDefaults();

		return settings;
	}
	/*******************************************************************************************************
	* @description get the custom settings
	* @return Boolean whether or not the account trigger is disabled
	*/	
	public static Boolean getAccountTriggerDisabled(){
		MergeControlSettings__c settings = getSettings();
		return settings != null && settings.DisableAccountTrigger__c;
	}
	/*******************************************************************************************************
	* @description get the custom settings
	* @return Boolean whether or not the contact trigger is disabled
	*/	
	public static Boolean getContactTriggerDisabled(){
		MergeControlSettings__c settings = getSettings();
		return settings != null && settings.DisableContactTrigger__c;
	}
	/*******************************************************************************************************
	* @description get the custom settings
	* @return Set<String> a set of profile Ids that this is disabled for
	*/	
	public static Set<String> getDisabledProfileIds(){
		MergeControlSettings__c settings = getSettings();
		Set<String> profileIds = new Set<String>();
		if(settings != null) {
			 if(String.isNotBlank(settings.DisableForProfiles__c)){
				 profileIds.addAll(getSetFromString(settings.DisableForProfiles__c));
			 }
		 }
		return profileIds;
	}
	/*******************************************************************************************************
	* @description get the custom settings
	* @return Set<String> a set of user Ids
	*/	
	public static Set<String> getDisabledUserIds(){
		MergeControlSettings__c settings = getSettings();
		Set<String> userIds = new Set<String>();
		if(settings != null) {
			 if(String.isNotBlank(settings.DisableForUsers__c)){
				 userIds.addAll(getSetFromString(settings.DisableForUsers__c));
			 }
		 }
		return userIds;
	}
	/*******************************************************************************************************
	* @description get the custom settings
	* @return Boolean
	*/	
	public static Boolean getTriggerDisabled(String objectType){
		if(objectType=='Account'
			&& getAccountTriggerDisabled())
			return true;
		if(objectType=='Contact'
			&& getContactTriggerDisabled())
			return true;
		if(getDisabledUserIds().size()>0
			&& getDisabledUserIds().contains(UserInfo.getUserId()))
			return true;
		if(getDisabledProfileIds().size()>0
			&& getDisabledProfileIds().contains(UserInfo.getProfileId()))
			return true;
		return false;
	}
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param mergeFields the mergeFieldWrap collection to save
	* @return  String metaData deploy job Id
	*/	
	public static String saveMergeFields(List<mergeFieldWrap> mergeFields) {
		MRG_Metadata_SVC mdService = new MRG_Metadata_SVC();
		List<MergeFieldSetting__mdt> mergeFieldMetadata = new List<MergeFieldSetting__mdt>();
		for(mergeFieldWrap mergeField:mergeFields) {
			mergeFieldMetadata.add(getMergeFieldFromObject(mergeField));
		}
			
		List<Metadata.CustomMetadata> mdRecords = new List<Metadata.CustomMetadata>();
		// get metadata and add to record list
		for(MergeFieldSetting__mdt mergeField:mergeFieldMetadata) {
			Metadata.CustomMetadata mdRecord =  mdService.getMetaDataRecord(mergeField);
			mdRecords.add(mdRecord);
		}
		// deploy record via metadata api
		return mdService.deployMetadataRecords(mdRecords);
	}
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param mergeFields the mergeFieldWrap collection to save
	* @return  String metaData deploy job Id
	*/	
	public static String savePreviewFields(List<MRG_MergeSettings_CTRL.previewField> previewFields) {
		MRG_Metadata_SVC mdService = new MRG_Metadata_SVC();
		List<PreviewFields__mdt> previewFieldMetadata = new List<PReviewFields__mdt>();
		for(MRG_MergeSettings_CTRL.previewField previewField:previewFields) {
			previewFieldMetadata.add(getPreviewFieldFromObject(previewField));
		}
			
		List<Metadata.CustomMetadata> mdRecords = new List<Metadata.CustomMetadata>();
		// get metadata and add to record list
		for(PreviewFields__mdt previewField:previewFieldMetadata) {
			Metadata.CustomMetadata mdRecord =  mdService.getMetaDataRecord(previewField);
			mdRecords.add(mdRecord);
		}
		// deploy record via metadata api
		return mdService.deployMetadataRecords(mdRecords);
	}
	/*******************************************************************************************************
	* @description settings wrapper
	*/
	public class mergeSetting {
		@auraEnabled public boolean disableAccountTrigger;
		@auraEnabled public boolean disableContactTrigger;
		@auraEnabled public List<String> disabledForProfiles;
		@auraEnabled public List<String> disabledForUsers;

		public mergeSetting(MergeControlSettings__c setting) {
			this.disableAccountTrigger = setting.DisableAccountTrigger__c;
			this.disableContactTrigger = setting.DisableContactTrigger__c;
			List<String> profileIDs = new List<String>();
			List<String> userIds = new List<String>();
			profileIDs.addAll(getSetFromString(setting.DisableForProfiles__c));
			userIds.addAll(getSetFromString(setting.DisableForUsers__c));
			this.disabledForProfiles = profileIDs;
			this.disabledForUsers = userIds;
		}
	}
	/*******************************************************************************************************
	* @description get setting from wrapper
	*/
	public static MergeControlSettings__c getSettingsFromObject(mergeSetting settingObj) {
		MergeControlSettings__c setting = MergeControlSettings__c.getOrgDefaults();
		setting.DisableAccountTrigger__c = settingObj.disableAccountTrigger;
		setting.DisableContactTrigger__c = settingObj.disableContactTrigger;
		setting.DisableForProfiles__c = settingObj.disabledForProfiles != null && settingObj.disabledForProfiles.size()>0 ? String.join(settingObj.disabledForProfiles,';') : null;
		setting.DisableForUsers__c = settingObj.disabledForUsers != null && settingObj.disabledForUsers.size()>0 ? String.join(settingObj.disabledForUsers,';') : null;
		return setting;
	}

	/*******************************************************************************************************
	* @description mergefield wrapper
	*/		
	public class mergeFieldWrap implements Comparable {
		@auraEnabled public String id;
		@auraEnabled public String label;
		@auraEnabled public String name;
		@auraEnabled public String objectName;
		@auraEnabled public String fieldName;
		@auraEnabled public String type;
		@auraEnabled public String rule;
		@auraEnabled public String relatedField;
		@auraEnabled public Boolean disable;

		public mergeFieldWrap(MergeFieldSetting__mdt mergeField) {
			this.id = mergeField.Id;
			this.label = mergeField.Label;
			this.name = mergeField.QualifiedAPIName;
			this.objectName = mergeField.Object__r.QualifiedAPIName;
			this.fieldName = mergeField.Field__r.QualifiedAPIName;
			this.type = mergeField.Type__c != null ? mergeField.Type__c.left(1).toLowerCase() : 't';
			this.rule = mergeField.PreservationRule__c;
			this.relatedField = mergeField.RelatedField__r.QualifiedAPIName;
			this.disable = mergeField.Disable__c;
		}
		public Integer compareTo(Object compareTo) {
			mergeFieldWrap sortObj = (mergeFieldWrap) compareTo;
			return this.fieldName.left(1) > sortObj.fieldName.left(1) ? 1 : -1;
		}
	}
	/*******************************************************************************************************
	* @description get mergeField metadata from object
	* @param mfw a mergeFieldWrap
	* @return MergeFieldSetting__mdt the merge field metadata record
	*/	
	public static PreviewFields__mdt getPreviewFieldFromObject(MRG_MergeSettings_CTRL.previewField previewField) {
		
		PreviewFields__mdt pField = new PreviewFields__mdt (
			Label = previewField.label,
			Disable__c = previewField.hidden
		);
		pField.Label = String.isBlank(pField.Label) ? previewField.name : pField.Label;
		if(String.isNotBlank(previewField.id))
			pField.Id = previewField.id;
		pField.QualifiedAPIName = String.isBlank(previewField.name) || previewField.name.contains('_') ? previewField.fieldName.replace('_','') + previewField.objectName.left(1) : previewField.name;
		
		Map<String, Object> pFieldJSON = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(pField));
		Map<String, Object> fldField = new Map<String, Object> {
			'attributes' => new Map<String, Object> {
				'type' => 'EntityParticle'
			},
			'QualifiedAPIName' => previewField.fieldName
		};
		Map<String, Object> objField = new Map<String, Object> {
			'attributes' => new Map<String, Object> {
				'type' => 'EntityDefinition'
			},
			'QualifiedAPIName' => previewField.objectName
		};

		pFieldJSON.put('Field__r',fldField);
		pFieldJSON.put('Object__r',objField);

		pField = (PreviewFields__mdt) JSON.deserialize(JSON.serialize(pFieldJSON),PreviewFields__mdt.class);

		return pField;
	}
	/*******************************************************************************************************
	* @description get mergeField metadata from object
	* @param mfw a mergeFieldWrap
	* @return MergeFieldSetting__mdt the merge field metadata record
	*/	
	public static MergeFieldSetting__mdt getMergeFieldFromObject(mergeFieldWrap mfw) {
		MergeFieldSetting__mdt mergeField = new MergeFieldSetting__mdt(
			Label = mfw.label,
			PreservationRule__c = mfw.rule,
			Disable__c = mfw.disable

		);
		mergeField.Type__c = mfw.type == 't' ? 'Track' : 'Preserve';
		if(String.isNotBlank(mfw.id))
			mergeField.Id = mfw.id;
		mergeField.QualifiedAPIName = String.isBlank(mfw.name) || mfw.name.contains('__') ? mfw.fieldName.replace('__','') + mfw.objectName.left(1) : mfw.name;
		Map<String, Object> mergeFieldJSON = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(mergeField));
		Map<String, Object> fldField = new Map<String, Object> {
			'attributes' => new Map<String, Object> {
				'type' => 'EntityParticle'
			},
			'QualifiedAPIName' => mfw.fieldName
		};
		Map<String, Object> objField = new Map<String, Object> {
			'attributes' => new Map<String, Object> {
				'type' => 'EntityDefinition'
			},
			'QualifiedAPIName' => mfw.objectName
		};
		if(String.isNotBlank(mfw.relatedField)){
			Map<String, Object> rltField = new Map<String, Object> {
				'attributes' => new Map<String, Object> {
					'type' => 'EntityParticle'
				},
				'QualifiedAPIName' => mfw.relatedField
			};
			mergeFieldJSON.put('RelatedField__r',rltField);
		}
		mergeFieldJSON.put('Field__r',fldField);
		mergeFieldJSON.put('Object__r',objField);

		mergeField = (MergeFieldSetting__mdt) JSON.deserialize(JSON.serialize(mergeFieldJSON),MergeFieldSetting__mdt.class);

		return mergeField;
	}
	/*******************************************************************************************************
	* @description merge fields from custom metadata
	*/	
	public static List<PreviewFields__mdt> previewFields {
		get {
			if(previewFields  == null) {
				return new List<PreviewFields__mdt>((List<PreviewFields__mdt>)database.query(MRG_MergeSettings_CTRL.getPreviewFieldsSOQL()));
			}
			return previewFields;
		}
		set;
	}

	/*******************************************************************************************************
	* @description merge fields from custom metadata
	*/	
	public static List<MergeFieldSetting__mdt> mergeFields {
		get {
			if(mergeFields == null) {
				return new List<MergeFieldSetting__mdt>([SELECT
					Id,
					Label,
					DeveloperName,
					QualifiedAPIName,
					Object__r.QualifiedAPIName,
					Field__r.QualifiedAPIName,
					RelatedField__r.QualifiedAPIName,
					Type__c,
					Disable__c,
					PreservationRule__c
					FROM MergeFieldSetting__mdt
				]);
			}
			return mergeFields;
		}
		set;
	}
	/*******************************************************************************************************
	* @description get merge History result from merge candidates
	* @param List<MergeCandidate__c> records
	* @param String objectType
	* @return mergeHistoryResult
	*/
	public static mergeHistoryResult getMergeHistoryResult(List<MergeCandidate__c> records,String objectType){
		Map<Id, Set<Id>> mergeKeyMap = MRG_Duplicate_SVC.getMergeKeyMap(records);
		Set<Id> allIds = MRG_Duplicate_SVC.getAllIds(mergeKeyMap);
		String soqlQuery = MRG_Duplicate_SVC.getMergeSOQLQuery(objectType);
		soqlQuery+=' WHERE Id in:allIds';
		Map<Id, SObject> objMap = new Map<Id, SObject>(Database.query(soqlQuery));
		mergeHistoryResult mergeResult = createMergeRecords(objMap, mergeKeyMap, objectType);
		mergeResult.objectMap = objMap;
		return mergeResult;
	}
	/*******************************************************************************************************
	* @description a list of fields to track in MergeFieldHistory__c
	* @return List<MergeFieldSetting__mdt>
	*/
	public static void processMergesFromBatch(List<MergeCandidate__c> records, String objectType) {
		Boolean disableTriggers = true;
		processMergesFromBatch(records, objectType, disableTriggers);
	}
	/*******************************************************************************************************
	* @description a list of fields to track in MergeFieldHistory__c
	* @return List<MergeFieldSetting__mdt>
	*/
	public static void processMergesFromBatch(List<MergeCandidate__c> records, String objectType, Boolean disableTriggers) {
		if(disableTriggers)
			MRG_Duplicate_SVC.triggerDisabled=true;
		Map<Id,Id> mergeCandidateIdByKeepId = MRG_Duplicate_SVC.getMergeCandidateIdByKeepId(records);
		Map<Id, MergeCandidate__c> mergeCandidateMap = new Map<Id, MergeCandidate__c>(records);
		mergeHistoryResult mergeResult = getMergeHistoryResult(records, objectType);
		Map<Id, SObject> objMap = mergeResult.objectMap;
		Map<Id, Set<Id>> mergeKeyMap = MRG_Duplicate_SVC.getMergeKeyMap(records);
		if(mergeResult.fieldHistory.size()>0)
			insert mergeResult.fieldHistory;
		Map<Id, Sobject> keptRecordMap = new Map<Id, SObject>(mergeResult.updateRecords);
		Set<Id> keepIdsMerged = new Set<Id>();
		for(Id keepId:mergeKeyMap.keyset()){
			if(objectType=='Account') {
				Account keepObject = keptRecordMap.containsKey(keepId) ? (Account) keptRecordMap.get(keepId).clone(true,false,false,false) : new Account(Id=keepId);
				List<Account> mergeObjects = new List<Account>();
				for(Id mergeId:mergeKeyMap.get(keepId)) {
					mergeObjects.add((Account) objMap.get(mergeId));
				}
				merge keepObject mergeObjects;
				keepIdsMerged.add(keepObject.Id);

			} else {
				Contact keepObject = keptRecordMap.containsKey(keepId) ? (Contact) keptRecordMap.get(keepId).clone(true,false,false,false) : new Contact(Id=keepId);
				List<Contact> mergeObjects = new List<Contact>();
				for(Id mergeId:mergeKeyMap.get(keepId)) {
					mergeObjects.add((Contact) objMap.get(mergeId));
				}
				merge keepObject mergeObjects;
				keepIdsMerged.add(keepObject.Id);

			}
		}
		Map<Id, mergeHistoryResult> mergeResultByKeepId = getMergeHistoryResultByKeepId(mergeResult,mergeKeyMap);
		updateMergeCandidateStatus(keepIdsMerged, mergeCandidateMap, mergeCandidateIdByKeepId, mergeResultByKeepId);
		if(disableTriggers)
			MRG_Duplicate_SVC.triggerDisabled=false;
	}
	/*******************************************************************************************************
	* @description updates the status of merged records with corresponding merge candidates
	* @param keepIds the Ids of the kept records
	* @param mergeCandidateMap the map of merge candidates
	* @param mergeCandidateByKeepId the map of merged candidate id by keep id
	*/
	public static void updateMergeCandidateStatus(Set<Id> keepIds, Map<Id, MergeCandidate__c> mergeCandidateMap, Map<Id,Id> mergeCandidateIdByKeepId,Map<Id,mergeHistoryResult> mergeResultByKeepId){
		
		for(Id keepId:keepIds){
			Id mergeCandidateId = mergeCandidateIdByKeepId.get(keepId);
			if(MergeCandidateMap.containsKey(mergeCandidateId)){
				MergeCandidateMap.get(mergeCandidateId).Status__c='Processed';
				MergeCandidateMap.get(mergeCandidateId).Data__c = mergeResultByKeepId.containsKey(keepId) ? JSON.serialize(mergeResultByKeepId.get(keepId)) : null;
			}
		}
		if(mergeCandidateMap.size()>0)
			update mergeCandidateMap.values();
	}

	/*******************************************************************************************************
	* @description updates the status of merged records with corresponding merge candidates
	* @param keepIds the Ids of the kept records
	*/
	public static void updateMergeCandidateStatus(Set<Id> keepIds, Map<Id,mergeHistoryResult> mergeResultByKeepId){
		List<MergeCandidate__c> records = MRG_Duplicate_SVC.getMergeCandidatesFromKeptIds(keepIds);
		Map<Id, MergeCandidate__c> mergeCandidateMap = new Map<Id, MergeCandidate__c>(records);
		Map<Id,Id> mergeCandidateIdByKeepId = MRG_Duplicate_SVC.getMergeCandidateIdByKeepId(records);
		updateMergeCandidateStatus(keepIds,mergeCandidateMap,mergeCandidateIdByKeepId, mergeResultByKeepId);
	}

	/*******************************************************************************************************
	* @description a list of fields to track in MergeFieldHistory__c
	* @return List<MergeFieldSetting__mdt>
	*/	
	public static List<mergeFieldWrap> getTrackMergeFields() {
		List<mergeFieldWrap> trackMergeFields = new List<mergeFieldWrap>();
		for(MergeFieldSetting__mdt mergeField:mergeFields) {
			if(mergeField.Type__c != null
				&& mergeField.Type__c.equalsIgnoreCase('Track'))
				trackMergeFields.add(new mergeFieldWrap(mergeField));
		}
		return trackMergeFields;
	}

	/*******************************************************************************************************
	* @description a list of fields to preserve based on preservation rule
	* @return List<MergeFieldSetting__mdt>
	*/	
	public static List<mergeFieldWrap> getPreserveMergeFields() {
		List<mergeFieldWrap> preserveMergeFields = new List<mergeFieldWrap>();
		for(MergeFieldSetting__mdt mergeField:mergeFields) {
			if(mergeField.Type__c != null
				&& mergeField.Type__c.equalsIgnoreCase('Preserve'))
				preserveMergeFields.add(new mergeFieldWrap(mergeField));
		}
		return preserveMergeFields;
	}
	/*******************************************************************************************************
	* @description translates deleted contacts into merge records
	* @param List<Contact> oldlist a list of records from trigger.old
	* @return List<MergeFieldHistory__c> the resulting sync record import list
	*/
	public static mergeHistoryResult createMergeRecords(Map<Id, SObject> objMap, Map<Id, Set<Id>> mergeKeyMap, String objectType) {
		List<mergeFieldWrap> trackMergeFields = new List<mergeFieldWrap>();
		for(mergefieldWrap mergeField:getTrackMergeFields()) {
			if(mergeField.objectName.equalsIgnorecase(objectType))
				trackMergeFields.add(mergeField);
		}
		List<mergeFieldWrap> preserveMergeFields = new List<mergeFieldWrap>();
		for(mergeFieldWrap mergeField:getPreserveMergeFields()){
			if(mergeField.objectName.equalsIgnoreCase(objecttype))
				preserveMergeFields.add(mergeField);
		}

		List<SObject> mergedRecords = new List<SObject>();
		Map<Id,SObject> keptRecordMap = new Map<Id, SObject>();

		for(Id keepId:mergeKeyMap.keyset()){
			if(objMap.containsKey(keepId))
				keptRecordMap.put(keepId, objMap.get(keepId));
			for(Id mergeId:mergeKeyMap.get(keepId)){
				if(objMap.containsKey(mergeId))
					mergedRecords.add(objMap.get(mergeId));
			}
		}
		mergeHistoryResult mergeResult = getMergesFromDeletedRecords(mergedRecords,mergeKeyMap, keptRecordMap,trackMergeFields,preserveMergeFields, objectType);
		return mergeResult;
	}
	/*******************************************************************************************************
	* @description translates deleted contacts into merge records
	* @param List<Contact> oldlist a list of records from trigger.old
	* @return List<MergeFieldHistory__c> the resulting sync record import list
	*/
	public static void createMergeRecords(List<SObject> deletedRecords, String objectType) {
		
		List<mergeFieldWrap> trackMergeFields = new List<mergeFieldWrap>();
		for(mergefieldWrap mergeField:getTrackMergeFields()) {
			if(mergeField.objectName.equalsIgnorecase(objectType))
				trackMergeFields.add(mergeField);
		}
		List<mergeFieldWrap> preserveMergeFields = new List<mergeFieldWrap>();
		for(mergeFieldWrap mergeField:getPreserveMergeFields()){
			if(mergeField.objectName.equalsIgnoreCase(objecttype))
				preserveMergeFields.add(mergeField);
		}
		
		/** @description  map to store kept contact */	
		Map<Id,SObject> keptRecordMap = new Map<Id, SObject>();
		
		/** @description  list to store deleted records that are merges */	
		List<SObject> mergedRecords = new List<SObject>();
		
		for(Sobject obj:deletedRecords) {
			String masterRecordId = (String) obj.get('MasterRecordId');
			if(String.isNotBlank(masterRecordId)) {
				mergedRecords.add(obj);
				SObject keptRec = createNewObject(objectType);
				keptRec.ID = masterRecordId;
				keptRecordMap.put(masterRecordId, keptRec);
			}
		}
		String soqlQuery = getSOQLQuery(objectType);
		Set<Id> keptRecordIds = new Set<Id>();
		keptRecordIds.addAll(keptRecordMap.keyset());
		soqlQuery+=' WHERE Id IN:keptRecordIds';
		keptRecordMap = new Map<Id,Sobject>(database.Query(soqlQuery));
		Map<Id, Set<Id>> mergeKeyMap = getMergeKeyMap(mergedRecords);
		
		mergeHistoryResult mergeResult = getMergesFromDeletedRecords(mergedRecords,mergeKeyMap, keptRecordMap,trackMergeFields,preserveMergeFields, objectType);
		Map<Id, mergeHistoryResult> mergeResultByKeepId = getMergeHistoryResultByKeepId(mergeResult, mergeKeyMap);
		if(mergeResult.fieldHistory.size()>0)
			insert mergeResult.fieldHistory;
		if(mergeResult.updateRecords.size()>0)
			update mergeResult.updateRecords;
		if(keptRecordIds.size()>0)
			updateMergeCandidateStatus(keptRecordIds,mergeResultByKeepId);
		
	}
	/*******************************************************************************************************
	* @description get field SOQL
	* @return String soql query
	*/
	public static Map<Id,Id> getKeepIdMap(Map<Id, Set<Id>> mergeKeyMap){
		Map<Id, Id> keepIdMap = new Map<Id, Id>();
		for(Id keepId:mergeKeyMap.keyset()) {
			for(Id mergeId:mergeKeyMap.get(keepId)){
				keepIdMap.put(mergeId,keepId);
			}
		}
		return keepIdMap;
	}
	/*******************************************************************************************************
	* @return String soql query
	*/
	public static Map<Id, Set<Id>> getMergeKeyMap(List<SObject> mergeRecords){
		Map<Id, Set<Id>> mergeKeyMap = new Map<Id, Set<Id>>();
		for(SObject record:mergeRecords){
			if(record.get('MasterRecordId') != null) {
				Id keepId = Id.valueOf((String) record.get('MasterRecordId'));
				if(!mergeKeyMap.containsKey(keepId))
					mergeKeyMap.put(keepId,new Set<Id>());
				mergeKeyMap.get(keepId).add(Id.valueOf((String) record.get('Id')));
			}
		}
		return mergeKeyMap;
	}
	/*******************************************************************************************************
	* @description get field SOQL
	* @return String soql query
	*/
	public static String getSOQLQuery(String objectType) {
		String soqlQuery='SELECT Id,CreatedDate';
		Set<String> queryFields = getWriteableFields(objectType);
		soqlQuery+=', '+String.join((Iterable<String>) queryFields, ',');
		soqlQuery+=' FROM '+objectType;
		
		return soqlQuery;
	}
	/*******************************************************************************************************
	* @description returns a list of Merge records for saving
	* @param preserveFieldmap the preservation rules
	* @return  Map<String, Set<String>> map of master child fields
	*/
	public static Map<String, String> getMasterChildFields(Map<String, mergeFieldWrap> preserveFieldMap){
		Map<String, String> masterChildFields = new Map<String, String>();
		for(mergeFieldWrap mfw:preserveFieldMap.values()){
			if(mfw.rule=='Related Field'
				&& String.isNotBlank(mfw.relatedField)){
					masterChildFields.put(mfw.fieldName.toLowerCase(),mfw.relatedField.toLowerCase());
				}
		}
		return masterChildFields;
	}

	/*******************************************************************************************************
	* @description returns a list of Merge records for saving
	* @param List<SObject> deleted contacts
	* @param Map<Id,SObject> kept contacts
	* @return mergeHistoryResult the resulting sync record import list
	*/
	public static mergeHistoryResult getMergesFromDeletedRecords(List<SObject> mergedRecords, Map<Id, Set<Id>> mergeKeyMap, Map<Id,Sobject> keptRecordMap, List<mergeFieldWrap> trackMergeFields, List<mergeFieldWrap> preserveMergeFields, String objectType) {
		Map<Id,Id> keepIdMap = getKeepIdMap(mergeKeyMap);
		Map<String, mergeFieldWrap> trackfieldMap = new Map<String, mergeFieldWrap>(getMergeFieldMap(trackMergeFields));
		Map<String, mergeFieldWrap> preserveFieldMap = new Map<String, mergeFieldWrap>(getMergeFieldMap(preserveMergeFields));
		/****
		*	a map of child field to master field keyed by child field
		***/
		Map<String, String> masterChildFields = new Map<String, String>(getMasterChildFields(preserveFieldMap));
		/****
		*	a set of master fields
		***/
		Set<String> masterFields = new Set<String>();
		masterFields.addAll(masterChildFields.values());

		Set<String> writeableFields = getWriteableFields(objectType);
		for(String masterField:masterFields){
			if(writeableFields.contains(masterField))
				writeablefields.remove(masterField);
		}

		// add all of the fields from the preserve rules
		List<String> fieldsToCheck = new List<String>();
		fieldsToCheck.addAll(masterFields);
		fieldsToCheck.addAll(writeableFields);

		List<MergeFieldHistory__c> mergeRecords = new List<MergeFieldHistory__c>();
		Map<Id, SObject> updateRecordMap = new Map<Id, SObject>();
		for(Sobject obj:mergedRecords) {
			String mergedRecordId = (String) obj.get('Id'); 
			String masterRecordId = keepIdMap.containsKey(Id.valueOf(mergedRecordId)) ? keepIdMap.get(Id.valueOf(mergedRecordId)) : null;
			Map<String, Boolean> keptMasterFields = new Map<String, Boolean>();
			if(String.isNotBlank(masterRecordId)
				&& keptRecordMap.containsKey(masterRecordId)) {
				SObject keptRecOld = keptRecordMap.get(masterRecordId);
				SObject keptRec = keptRecordMap.get(masterRecordId);
				Boolean keptRecordIsOlder = (Datetime) keptRec.get('CreatedDate') < (Datetime) obj.get('CreatedDate');
				Boolean hasChange = false;
				for(String fieldName:fieldsToCheck) {
					system.debug(JSON.serializePretty(fieldsToCheck));
					Boolean isMaster = masterFields.contains(fieldName);
					Boolean isChild = masterChildFields.containsKey(fieldName);
					String masterFieldName = isChild ? masterChildFields.get(fieldName) : null;
					Boolean masterFieldIsKept = masterFieldName != null && keptMasterFields.containsKey(masterFieldName) && keptMasterFields.get(masterFieldName);
					Boolean mergedFieldIsKept = false;
					mergeFieldWrap trackField = trackfieldMap.containsKey(fieldName) ? trackfieldMap.get(fieldName) : null;
					mergeFieldWrap preserveField = preserveFieldMap.containsKey(fieldName) ? preserveFieldMap.get(fieldName) : null;
					Object mergeRecordFieldValue = obj.get(fieldName);
					Object keptRecordfieldValue = keptRec.get(fieldName);
					Object keepValue = keptRecordfieldValue;
					Object mergeValue = mergeRecordFieldValue;
					
					if(mergeRecordFieldValue!= null) {
						// if we should preserve thie value then preserve it
						if(preserveField != null) {
							if(isChild && masterFieldIsKept){
								keepValue = mergeRecordFieldValue;
								mergeValue = keptRecordfieldValue;
								keptRec.put(fieldName,keepValue);
								hasChange=true;
								mergedFieldIsKept=true;								
							} else if(testValue(mergeRecordFieldValue, keptRecordfieldValue, preserveField.rule, keptRecordIsOlder)) {
								keepValue = mergeRecordFieldValue;
								mergeValue = keptRecordfieldValue;
								keptRec.put(fieldName,keepValue);
								hasChange=true;
								mergedFieldIsKept=true;
							}
						} else {
							// if the new value is null then preserve it
							if(keptRecordfieldValue==null) {
								keepValue = mergeRecordFieldValue;
								mergeValue = keptRecordfieldValue;
								keptRec.put(fieldName,keepValue);
								hasChange = true;
								mergedFieldIsKept=true;
							}
							// if it is a boolean field and the old value is true then preserve it
							if(getObjectType(mergeRecordFieldValue) == 'Boolean'
								&& (Boolean) mergeRecordFieldValue
								&& !(Boolean) keptRecordFieldValue) {
								keepValue = mergeRecordFieldValue;
								mergeValue = keptRecordfieldValue;
								keptRec.put(fieldname,keepValue);
								hasChange=true;
								mergedFieldIsKept=true;
							}
						}
						// if this is a master field and the merged value is kept, keep track
						if(mergedFieldIsKept && isMaster)
							keptMasterFields.put(fieldName,true);
						// if we should track this field then track it
						if(trackField != null
							|| (preserveField != null 
								&& hasChange)) {
							if(keepValue != null
								&& mergeValue != null
								&& keepValue != mergeValue) {
									
								mergeRecords.add(getMergeRecord(keepValue, mergeValue, keptRec, mergedRecordId, fieldName));
								
							}
						}

					}
				}
				if(hasChange)
					updateRecordMap.put(keptRec.Id,keptRec);
			}
		}
		mergeHistoryResult mergeResult = new mergeHistoryResult(updateRecordMap.values(),mergeRecords);
		return mergeResult;
	}

	/*******************************************************************************************************
	* @description get a map of contact merge fields keyed by field name lowercase
	* @param mergeFields
	* @return Map<String, MergeFieldSetting__mdt>
	*/
	public static Map<String, mergeFieldWrap> getMergeFieldMap(List<mergeFieldWrap> mergeFields) {
		Map<String, mergeFieldWrap> mergeFieldMap = new Map<String, mergeFieldWrap>();
		for(mergeFieldWrap mergeField:mergeFields) {
			if(!mergeField.disable)
				mergeFieldMap.put(mergeField.fieldName.toLowerCase(), mergeField);
		}
		return mergeFieldMap;
	}

	/*******************************************************************************************************
	* @description gets writeable fields for a contact record
	* @param objectType the string representation of the object type
	* @return Set<String> writeable fields
	*/
	public static Set<String> getWriteableFields(String objectType) {
		Set<String> writeableFields = new Set<String>();
		for(Schema.SObjectField fieldRef : Schema.getGlobalDescribe().get(objectType).getDescribe().fields.getMap().values()) {
			if(fieldRef.getDescribe().isUpdateable())
				writeableFields.add(fieldRef.getDescribe().getName().toLowerCase());
		}
		return writeableFields;
	}
	/*******************************************************************************************************
	* @description gets writeable fields for a contact record
	* @param objectType the string representation of the object type
	* @return Set<String> writeable fields
	*/
	public static MergeFieldHistory__c getMergeRecord(Object keepValue, Object mergeValue, SObject keptRec, String mergedRecordId, String fieldName) {
		MergeFieldHistory__c mergeRecord = new MergeFieldHistory__c(
			KeptRecordId__c = keptRec.Id,
			MergedRecordId__c = mergedRecordId,
			KeptValue__c = String.valueOf(keepValue),
			MergeValue__c = String.valueOf(mergeValue),
			MergeValueType__c = fieldName
		);
		return mergeRecord;
	}
	/*******************************************************************************************************
	* @description gets writeable fields for a contact record
	* @param objectType the string representation of the object type
	* @return Set<String> writeable fields
	*/
	public static Boolean testValue(Object fieldValue, Object keptContactfieldValue, String preservationRule, Boolean keptContactIsOlder) {
		Boolean isLargest = preservationRule.equalsIgnoreCase('Largest');
		Boolean isSmallest = preservationRule.equalsIgnoreCase('Smallest');
		Boolean isOldest = preservationRule.equalsIgnoreCase('Oldest');
		Boolean isNewest = preservationRule.equalsIgnorecase('Newest');
		Boolean result = false;
		if(keptContactfieldValue == null)
			return true;
		if(isOldest || isNewest) {
			result = (isOldest && !keptContactIsOlder) || (isNewest && keptContactIsOlder);

		} else if(isLargest || isSmallest) {
			switch on getObjectType(fieldValue) {
				when 'String' {
					result = (isLargest && (String) fieldValue > (String) keptContactFieldValue) || (isSmallest && (String) fieldValue < (String) keptContactFieldValue);
				}
				when 'Boolean' {
					result = (Boolean) fieldValue == true;
				}
				when 'Date' {
					result = (isLargest && (Date) fieldValue > (Date) keptContactFieldValue) || (isSmallest && (Date)fieldValue < (Date)keptContactFieldValue);
				}
				when 'Datetime' {
					result = (isLargest && (Datetime) fieldValue > (Datetime) keptContactFieldValue) || (isSmallest && (Datetime)fieldValue < (Datetime)keptContactFieldValue);
				}
				when 'Time' {
					result = (isLargest && (Time) fieldValue > (Time) keptContactFieldValue) || (isSmallest && (Time)fieldValue < (Time)keptContactFieldValue);
				}
				when 'Integer' {
					result = (isLargest && (Integer) fieldValue > (Integer) keptContactFieldValue) || (isSmallest && (Integer)fieldValue < (Integer)keptContactFieldValue);
				}
				when 'Decimal' {
					result = (isLargest && (Decimal) fieldValue > (Decimal) keptContactFieldValue) || (isSmallest && (Decimal)fieldValue < (Decimal)keptContactFieldValue);
				}
				when 'Double' {
					result = (isLargest && (Double) fieldValue > (Double) keptContactFieldValue) || (isSmallest && (Double)fieldValue < (Double)keptContactFieldValue);
				}
				when else {
					result = (isLargest && String.valueOf(fieldValue) > String.valueOf(keptContactFieldValue)) || (isSmallest && String.valueOf(fieldValue) < String.valueOf(keptContactFieldValue));
				}
			}
		}
		return result;
	}

	/*******************************************************************************************************
	* @description get the primitive type of a fieldvalue
	* @param fieldvalue the field value
	* @return String the type (Boolean, Date, Datetime, Time, Long, Integer, Decimal, Double defaulted to String)
	*/	
	public static String getObjectType(Object fieldValue) {
		if(fieldValue == null) return '';
		if(fieldValue instanceOf Boolean) return 'Boolean';
		if(fieldValue instanceOf Date) return 'Date';
		if(fieldValue instanceOf Datetime) return 'Datetime';
		if(fieldValue instanceOf Time) return 'Time';
		if(FieldValue instanceOf Long) return 'Long';
		if(FieldValue instanceOf Integer) return 'Integer';
		if(fieldValue instanceOf Decimal) return 'Decimal';
		if(fieldValue instanceOf Double) return 'Double';
		return 'String';
	}
	/*******************************************************************************************************
	* @description objectField class
	*/	
	public class objectField implements Comparable {
		@auraEnabled public String label;
		@auraEnabled public String name;
		@auraEnabled public String type;

		public objectField(Schema.sObjectField field){
			this.label = field.getDescribe().getLabel();
			this.name = field.getDescribe().getName();
			this.type = field.getDescribe().getType().name();
		}


		public Integer compareTo(Object compareTo) {
			objectField sortObj = (objectField) compareTo;
			return this.label > sortObj.label ? 1 : -1;
		}
	}
	/*******************************************************************************************************
	* @description returns a map of Field history by Keep Id
	* @param List<MergeFieldHistory__c> fieldHistory
	* @return Map<Id, List<MergeFieldHistory__c>> 
	*/
	public static Map<Id, List<MergeFieldHistory__c>>  getFieldHistoryByKeepId(List<MergeFieldHistory__C> fieldHistories){
		Map<Id, List<MergeFieldHistory__c>> fieldHistoryByKeepId = new Map<Id, List<MergeFieldHistory__c>>();
		for(MergeFieldHistory__c fieldHistory:fieldHistories){
			Id keepId = String.isNotBlank(fieldHistory.KeptRecordId__c) ? Id.valueOf(fieldHistory.KeptRecordId__c) : null;
			if(keepId == null)
				continue;
			if(!fieldHistoryByKeepId.containsKey(keepId))
				fieldHistoryByKeepId.put(keepId, new List<MergeFieldHistory__c>());
			fieldHistoryByKeepId.get(keepId).add(fieldHistory);
		}
		return fieldHistoryByKeepId;
	}

	/*******************************************************************************************************
	* @description returns a merge history result map keyed by the kept record
	* @param mergeResult the merge history result
	* @param mergeKeyMap the merge key map
	* @return Map<Id, mergeHistoryResult>
	*/
	public static Map<Id, mergeHistoryResult> getMergeHistoryResultByKeepId(mergeHistoryResult mergeResult, Map<Id, Set<Id>> mergeKeyMap) {
		Map<Id, List<MergeFieldHistory__c>> fieldHistoryByKeepId = getFieldHistoryByKeepId(mergeResult.fieldHistory);
		Map<Id, SObject> updateRecordsById = new Map<Id, SObject>(mergeResult.updateRecords);
		mergeResult.objectMap = mergeResult.objectMap == null ? new Map<Id, SObject>() : mergeResult.objectMap;
		Map<Id, mergeHistoryResult> mergeHistoryByKeepId = new Map<Id, mergeHistoryResult>();
		for(Id keepId:mergeKeyMap.keyset()){
			List<SObject> updateRecords = new List<SObject>();
			if(updateRecordsById.containsKey(keepId))
				updateRecords.add(updateRecordsById.get(keepId));
			List<MergeFieldHistory__c> fieldHistory = new List<MergeFieldHistory__c>();
			if(fieldHistoryByKeepId.containsKey(keepId))
				fieldHistoryByKeepId.get(keepId);
			Map<Id, SObject> objectMap = new Map<Id, SObject>();
			if(mergeResult.objectMap.containsKey(keepId))
				objectMap.put(keepId, mergeResult.objectMap.get(keepId));
			for(Id mergeId:mergeKeyMap.get(keepId)){
				if(mergeResult.objectMap.containsKey(mergeId))
					objectMap.put(mergeId,mergeResult.objectMap.get(mergeId));
			}
			mergeHistoryByKeepId.put(keepId,new mergeHistoryResult(updateRecords, fieldHistory, objectMap));
		}
		return mergeHistoryByKeepId;
	}

	/*******************************************************************************************************
	* @description creates a new SObject
	*/
	public class mergeHistoryResult {
		@auraEnabled public List<SObject> updateRecords {get;set;}
		@auraEnabled public List<MergeFieldHistory__c> fieldHistory {get;set;}
		@auraEnabled public Map<Id, SObject> objectMap {get;set;}
		@auraEnabled public Map<String, Object> manualOverrides;

		public mergeHistoryResult(){

		}

		public mergeHistoryResult(List<Sobject> updateRecords, List<MergeFieldHistory__c> fieldHistory){
			this.updateRecords = updateRecords;
			this.fieldHistory = fieldHistory;
			this.objectMap = new Map<Id, SObject>();
		}
		public mergeHistoryResult(List<Sobject> updateRecords, List<MergeFieldHistory__c> fieldHistory, Map<Id,SObject> objectMap){
			this.updateRecords = updateRecords;
			this.fieldHistory = fieldHistory;
			this.objectMap = objectMap;
		}
		public mergeHistoryResult(List<Sobject> updateRecords, List<MergeFieldHistory__c> fieldHistory, Map<Id,SObject> objectMap, Map<String, object> manualOverrides){
			this.updateRecords = updateRecords;
			this.fieldHistory = fieldHistory;
			this.objectMap = objectMap;
			this.manualOverrides = manualOverrides;
		}
	}
	/*******************************************************************************************************
	* @description creates a new SObject
	* @param objecttype the type of object to create
	* @return SObject the empty object
	*/
	public static SObject createNewObject(String objectType) {
		Schema.SObjectType sObjectType = Schema.getGlobalDescribe().get(objectType);

		return sObjectType.newSObject();
	}
	/*******************************************************************************************************
	* @description returns a set String from a String value
	* @param settingValue
	* @return Set<String>
	*/
	public static Set<String> getSetFromString(String settingValue) {
		Set<String> stringSet = new Set<String>();
			if(String.isBlank(settingValue))
				return stringSet;
			if(settingValue.contains(';')) {
				String[] vals = settingValue.split(';');
				for(String val:vals) {
					if(String.isNotBlank(val))
					stringSet.add(val.trim());
				}
			} else {
				stringSet.add(settingValue);
			}
		return stringSet;
	}
}