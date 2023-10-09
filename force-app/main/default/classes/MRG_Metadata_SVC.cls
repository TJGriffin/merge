public with sharing class MRG_Metadata_SVC {
	/*******************************************************************************************************
	* @description retrieves metadata records based on list of APIQualifiedNames
	* @param QualifiedAPINames
	* @return List<Metadata.Metadata> List of metadata records
	*/		
	
	public List<Metadata.Metadata> getMetadataRecords(List<String> QualifiedAPINames) {
		List<Metadata.Metadata> records = new List<Metadata.Metadata>();
		records = Metadata.Operations.retrieve(Metadata.MetadataType.CustomMetadata,QualifiedAPINames);
		return records;
	}
 
 	
	/*******************************************************************************************************
	* @description creates metadata object with associated fields
	* @param metadataRecord meta data object to create/update
	* @param fieldValues map of field keys and values
	* @return Metadata.CustomMetadata metadata record with fields added
	*/	 
	public Metadata.CustomMetadata updateMetadataObjectFields(Metadata.CustomMetadata metadataRecord, Map<String, Object> fieldKeyValues) {
		
		for(String fieldKey:fieldKeyValues.keyset()) {
			Metadata.CustomMetadataValue fieldSetting = new Metadata.CustomMetadataValue();
			fieldSetting.field = fieldKey;
			fieldSetting.value = fieldKeyValues.get(fieldKey);
			metadataRecord.values.add(fieldSetting);
		}
		return metadataRecord;
	}

	/*******************************************************************************************************
	* @description queue a list of metadata records to deploy
	* @param metadataRecords a list of metadata records to deploy
	* @return String jobId of the deployment
	*/	 
	public String deployMetadataRecords(List<Metadata.Metadata> metadataRecords) {
		// create deploy container to deploy the metadata values
		if(metadataRecords.size() == 0) {
			return null;
		}
		Metadata.DeployContainer container = new Metadata.DeployContainer();
		for(Metadata.Metadata metadataRecord:metadataRecords) {
			container.addMetadata(metadataRecord);
		}		
		DeployCallback callback = new DeployCallback();	
		String jobId = Test.isRunningTest() ? 'Test Job Id' :Metadata.Operations.enqueueDeployment(container, callback);
		Return (String) jobId;
	}
	/*******************************************************************************************************
	* @description callback method for the metadata api deployment
	*/
	
	private class DeployCallback implements Metadata.DeployCallback {
		
		/*******************************************************************************************************
		* @description constructor
		*/ 				
		public DeployCallback() {
			
		}

  		/*******************************************************************************************************
		* @description metadata deployment callback result handler
		*/ 	      
		public void handleResult(Metadata.DeployResult result, Metadata.DeployCallbackContext context) {
			MergeRecordSave__e saveEvent = new MergeRecordSave__e();
			saveEvent.isSuccess__c = result.status == Metadata.DeployStatus.Succeeded;
			String message;
			if(result.status != Metadata.DeployStatus.Succeeded) {
				message = String.isNotBlank(result.errorMessage) ? result.errorMessage.left(255) : result.errorMessage;
			}
			saveEvent.Message__c = message;
			List<Database.SaveResult> results = EventBus.publish(new List<MergeRecordSave__e>{saveEvent});
		}	
	}
	/*******************************************************************************************************
	* @description saves an integration process via metadata deployment
	* @param previewFields the preview fields we're saving
	* @return the Job Id of the deployment job
	*/ 		
	public Metadata.CustomMetadata getMetaDataRecord(PreviewFields__mdt previewField) {
		   	// create metadata container
		Metadata.CustomMetadata mdRecord = new Metadata.CustomMetadata();
		List<String> mdRecordNames = new List<String>();
		// map for setting values in meta data record
		Map<String, Object> fieldKeyValues = new Map<String, Object>();
		// populate fieldkeyvalue map with the current record's values
		fieldKeyValues.put('Field__c', previewField.Field__r.QualifiedAPIName);
		fieldKeyValues.put('Object__c',previewField.Object__r.QualifiedAPIName);
	 	fieldKeyValues.put('Disable__c', previewField.Disable__c);
		String qualifiedName = getQualifiedAPIName(previewField.QualifiedAPIName,'PreviewFields__mdt');
		mdRecordNames.add(qualifiedName);
		
		// get existing metadata records based on qualified name
		List<Metadata.Metadata> metadataRecords = getMetadataRecords(mdRecordNames);
		if(metadataRecords.size()>0) {
			// this is an existing record
			mdRecord = (Metadata.CustomMetadata) metadataRecords.get(0).clone();
		} else {
			mdRecord.fullName = qualifiedName;
		}
		mdRecord.Label = shortenLabel(previewField.Label);
		// add new field values to record

		mdRecord= updateMetadataObjectFields(mdRecord, fieldKeyValues);	
		
		return mdRecord;
	}
	/*******************************************************************************************************
	* @description saves an integration process via metadata deployment
	* @param integrationProcessToSave the integration process we're saving
	* @return the Job Id of the deployment job
	*/ 		
	public Metadata.CustomMetadata getMetaDataRecord(DuplicateRuleSettings__mdt dupeRuleSetting) {
		   	// create metadata container
		Metadata.CustomMetadata mdRecord = new Metadata.CustomMetadata();
		List<String> mdRecordNames = new List<String>();
		// map for setting values in meta data record
		Map<String, Object> fieldKeyValues = new Map<String, Object>();
		// populate fieldkeyvalue map with the current record's values
		fieldKeyValues.put('RuleName__c', dupeRuleSetting.RuleName__c);
		fieldKeyValues.put('Object__c',dupeRuleSetting.Object__r.QualifiedAPIName);
	 	fieldKeyValues.put('AutoMerge__c', dupeRuleSetting.AutoMerge__c);
		String qualifiedName = getQualifiedAPIName(dupeRuleSetting.QualifiedAPIName,'DuplicateRuleSettings__mdt');
		mdRecordNames.add(qualifiedName);
		
		// get existing metadata records based on qualified name
		List<Metadata.Metadata> metadataRecords = getMetadataRecords(mdRecordNames);
		if(metadataRecords.size()>0) {
			// this is an existing record
			mdRecord = (Metadata.CustomMetadata) metadataRecords.get(0).clone();
		} else {
			mdRecord.fullName = qualifiedName;
		}
		mdRecord.Label = shortenLabel(dupeRuleSetting.Label);
		// add new field values to record

		mdRecord= updateMetadataObjectFields(mdRecord, fieldKeyValues);	
		
		return mdRecord;
	}

	/*******************************************************************************************************
	* @description saves an integration process via metadata deployment
	* @param integrationProcessToSave the integration process we're saving
	* @return the Job Id of the deployment job
	*/ 		
	public Metadata.CustomMetadata getMetaDataRecord(MergeFieldSetting__mdt mergeField) {
		   	// create metadata container
		Metadata.CustomMetadata mdRecord = new Metadata.CustomMetadata();
		List<String> mdRecordNames = new List<String>();
		// map for setting values in meta data record
		Map<String, Object> fieldKeyValues = new Map<String, Object>();
		// populate fieldkeyvalue map with the current record's values
		fieldKeyValues.put('Disable__c', mergeField.Disable__c);
		fieldKeyValues.put('Field__c', mergeField.Field__r.QualifiedAPIName);
		fieldKeyValues.put('RelatedField__c', mergeField.RelatedField__r.QualifiedAPIName);
		fieldKeyValues.put('Object__c',mergeField.Object__r.QualifiedAPIName);
	 	fieldKeyValues.put('PreservationRule__c', mergeField.PreservationRule__c);
		fieldKeyValues.put('Type__c',mergeField.Type__c);
		String qualifiedName = getQualifiedAPIName(mergeField.QualifiedAPIName,'MergeFieldSetting__mdt'); 
		mdRecordNames.add(qualifiedName);
		
		// get existing metadata records based on qualified name
		List<Metadata.Metadata> metadataRecords = getMetadataRecords(mdRecordNames);
		if(metadataRecords.size()>0) {
			// this is an existing record
			mdRecord = (Metadata.CustomMetadata) metadataRecords.get(0).clone();
		} else {
			
			mdRecord.fullName =qualifiedName;
		}
		String label = mergeField.Field__r.QualifiedAPIName;
		label = shortenLabel(label);
		mdRecord.Label = label;
		// add new field values to record

		mdRecord= updateMetadataObjectFields(mdRecord, fieldKeyValues);	
		
		return mdRecord;
	}
	/*******************************************************************************************************
	* @description saves an integration process via metadata deployment
	* @param integrationProcessToSave the integration process we're saving
	* @return the Job Id of the deployment job
	*/ 		
	public Metadata.CustomMetadata getMetaDataRecord(KeepRuleSetting__mdt keepRule) {
				// create metadata container
		Metadata.CustomMetadata mdRecord = new Metadata.CustomMetadata();
		List<String> mdRecordNames = new List<String>();
		// map for setting values in meta data record
		Map<String, Object> fieldKeyValues = new Map<String, Object>();
		// populate fieldkeyvalue map with the current record's values
		fieldKeyValues.put('Object__c',keepRule.Object__r.QualifiedAPIName);
		fieldKeyValues.put('Type__c',keepRule.Type__c);
		String qualifiedName = getQualifiedAPIName(keepRule.QualifiedAPIName,'KeepRuleSetting__mdt');
		mdRecordNames.add(qualifiedName);
		
		// get existing metadata records based on qualified name
		List<Metadata.Metadata> metadataRecords = getMetadataRecords(mdRecordNames);
		if(metadataRecords.size()>0) {
			// this is an existing record
			mdRecord = (Metadata.CustomMetadata) metadataRecords.get(0).clone();
		} else {
			
			mdRecord.fullName =qualifiedName;
		}
		String label = keepRule.Type__c == 'Both' ? keepRule.Object__r.QualifiedAPIName + ' Primary Rule' : keepRule.Object__r.QualifiedAPIName + ' ' + keepRule.Type__c;
		label = shortenLabel(label);

		mdRecord.Label = label;
		// add new field values to record

		mdRecord= updateMetadataObjectFields(mdRecord, fieldKeyValues);	
		
		return mdRecord;
	
	}
	/*******************************************************************************************************
	* @description utility for shortening md labal
	* @param label the 
	* @return String
	*/ 
	private static String getQualifiedAPIName(String qualifiedAPIName, String objectName){
		if(!qualifiedAPIName.contains('.')){
			qualifiedAPIName = objectName + '.' + shortenApiName(qualifiedAPIName);
		}
		return qualifiedAPIName;
	}

	/*******************************************************************************************************
	* @description utility for shortening md labal
	* @param label the 
	* @return String
	*/ 
	private static String shortenLabel(String label){
		return shorten(label,'label');
	}

	/*******************************************************************************************************
	* @description utility for shortening md labal
	* @param label the 
	* @return String
	*/ 
	private static String shortenApiName(String qualifiedAPIName){
		return shorten(qualifiedAPIName,'apiname');
	}
	/*******************************************************************************************************
	* @description utility for shortening strings
	* @param label the 
	* @param type
	* @return String
	*/ 
	private static String shorten(String value, String type){
		value = String.isNotBlank(value) ? value.trim() : value;
		Integer stringSize = type == 'label' ? 80 : 40;
		String delimiter = type == 'label' ? '*' : '_';
		if(String.isNotBlank(value) && value.length()  >stringSize){
			value = value.left((stringSize/2)-1) + delimiter + value.right((stringSize/2));
		}
		return value;
	}

}