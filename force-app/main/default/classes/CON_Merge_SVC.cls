/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Service for dealing with contact merges
*/
public with sharing class CON_Merge_SVC {
	
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @return  List<ContactMergeField__mdt from custom metadata
	*/	
	publc static Set<String> writeableFields {
		get {
			if(writeableFields == null)
				writeableFields = getWriteableFields('Contact');
		}
		set;
	}

	/*******************************************************************************************************
	* @description Returns the merge fields
	* @return  List<ContactMergeField__mdt from custom metadata
	*/	
	@private static List<ContactMergeField__mdt> getMergeFields() {
		if(mergeFields == null) {
			mergeFields =  new List<ContactMergeField__mdt>([SELECT
			Id,
			Label,
			DeveloperName,
			QualifiedAPIName,
			Object__r.QualifiedAPIName,
			Field__r.QualifiedAPIName,
			Type__c,
			PreservationRule__c
			FROM ContactMergeField__mdt
			]);
		}
		return mergeFields;
	}
	/*******************************************************************************************************
	* @description merge fields from custom metadata
	*/	
	public static List<ContactMergeField__mdt> mergeFields {
		get {
			if(mergeFields == null) {
				mergeFields = getMergeFields();
			}
			return mergeFields;
		}
		set;
	}
	/*******************************************************************************************************
	* @description merge fields from custom metadata
	*/	
	public static List<ContactMergeField__mdt> getTrackMergeFields() {
		List<ContactMergeField__mdt> trackMergeFields = new List<ContactMergeField__mdt>();
		for(ContactMergeField__mdt mergeField:mergeFields) {
			if(mergeField.Type__c != null
				&& mergeField.Type__c.equalsIgnoreCase('Track'))
				trackMergeFields.add(mergeField);
		}
		return trackMergeFields;
	}
	/*******************************************************************************************************
	* @description merge fields from custom metadata
	*/	
	public static List<ContactMergeField__mdt> getPreserveMergeFields() {
		List<ContactMergeField__mdt> preserveMergeFields = new List<ContactMergeField__mdt>();
		for(ContactMergeField__mdt mergeField:mergeFields) {
			if(mergeField.Type__c != null
				&& mergeField.Type__c.equalsIgnoreCase('Preserve'))
				preserveMergeFields.add(mergeField);
		}
		return preserveMergeFields;
	}
	/*******************************************************************************************************
	* @description translates deleted contacts into merge records
	* @param List<Contact> oldlist a list of records from trigger.old
	* @return List<Merge__c> the resulting sync record import list
	*/
	public static void createMergeRecords(List<Contact> deletedContacts) {
		List<ContactMergeField__mdt> trackMergeFields = getTrackMergeFields();
		List<ContactMergeField__mdt> preserveMergeFields = getPreserveMergeFields();
		
		/** @description  map to store kept contact */	
		Map<Id,Contact> keptContactMap = new Map<Id, Contact>();
		
		/** @description  list to store deleted contacts that are merges */	
		List<Contact> mergedContacts = new List<Contact>();
		
		for(Contact con:deletedContacts) {
			if(String.isNotBlank(con.MasterRecordId)) {
				mergedContacts.add(con);
				keptContactMap.put(con.MasterRecordId, new Contact(Id=con.MasterRecordId));
			}
		}
		String soqlQuery = getSOQLQuery();
		Set<Id> keptContactIds = new Set<Id>();
		keptContactIds.addAll(keptContactMap.keyset());
		soqlQuery+=' WHERE Id IN:keptContactIds';
		keptContactMap = new Map<Id,Contact>((List<Contact>) database.Query(soqlQuery));
		
		List<Merge__c> merges = getMergesFromDeletedContacts(mergedContacts,keptContactMap,trackMergeFields,preserveMergeFields);
		
		if(merges.size()>0)
			insert merges;
		
	}

	/*******************************************************************************************************
	* @description get field SOQL
	* @return String soql query
	*/
	public static String getSOQLQuery() {
		String soqlQuery='SELECT Id,CreatedDate';
		Set<String> queryFields = writeableFields;
		for(Integer i=0;i<mergeFields.size();i++) {
			String fieldName = mergeFields[i].Field__r.QualifiedAPIName;
			if(!queryFields.contains(fieldName.toLowerCase()))
				soqlQuery+=','+fieldName;
		}
		soqlQuery+=', '+queryFields.join(',');
		soqlQuery+=' FROM Contact';
		
		return soqlQuery;
	}
	
	/*******************************************************************************************************
	* @description returns a list of Merge records for saving
	* @param List<Contact> deleted contacts
	* @param Map<Id,Contact> kept contacts
	* @return List<Merge__c> the resulting sync record import list
	*/
	public static List<Merge__c> getMergesFromDeletedContacts(List<Contact> mergedContacts, Map<Id,Contact> keptContactMap, List<ContactMergeField__mdt> mergeFields, List<ContactMergeField__mdt> preserveMergeFields) {
		Map<String, ContactMergeField__mdt> mergefieldMap = new Map<String, ContactMergeField__mdt>(getMergeFieldMap(mergeFields));
		Map<String, ContactMergeField__mdt> preserveFieldMap = new Map<String, ContactMergeField__mdt>(getMergeFieldMap(preserveFields));
		for(ContactMergeField__mdt mergeField:mergefields) {
			mergeFieldmap.put(mergeField.Field__r.QualifiedAPIName.toLowerCase(), mergeField);
		}
		List<Merge__c> mergeRecords = new List<Merge__c>();
		Map<Id, Contact> updateContactMap = new Map<Id, Contact>();
		for(Contact con:mergedContacts) {
			if(keptContactMap.containsKey(con.MasterRecordId)) {
				Contact keptConOld = keptContactMap.get(con.MasterRecordId);
				Contact keptCon = keptContactMap.get(con.MasterRecordId);
				Boolean keptcontactIsOlder = keptCon.CreatedDate < con.CreatedDate;
				for(String fieldName:writeableFields) {
					ContactMergeField__mdt mergeField = mergefieldMap.containsKey(fieldName) ? mergefieldMap.get(fieldName) : null;
					ContactMergeField__mdt preserveField = preserveFieldMap.containsKey(fieldName) ? preserveFieldMap.get(fieldName) : null;
					String fieldName = mergeField.Field__r.QualifiedAPIName;
					Object fieldValue = con.get(fieldName);
					Object keptContactfieldValue = keptCon.get(fieldName);
					if(fieldValue!= null )) {
						if(keptContactfieldValue==null) {
							keptCon.put(fieldName,fieldValue);
							if(mergeField != null) {
								mergeRecords.add(new Merge__c(
									KeptContactId__c = keptCon.Id,
									KeptValue__c = String.valueOf(keptContactfieldValue),
									MergeValue__c = String.valueOf(fieldValue),
									MergedValueType__c = fieldName
								));
							}
						} else if(keptContactfieldValue!= null
							&& keptContactfieldValue != fieldValue) {
							if(mergeField != null) {
								mergeRecords.add(new Merge__c(
									KeptContactId__c = keptCon.Id,
									KeptValue__c = String.valueOf(keptContactfieldValue),
									MergeValue__c = String.valueOf(fieldValue),
									MergedValueType__c = fieldName
								));
							}
							if(preserveField != null) {
								if((preservefield.PreservationRule__c == 'Oldest Record'
									&& keptcontactIsOlder)
									|| preserveField.PreservationRule__c == 'Newest Record'
									&& !keptContactIsOlder)
									) {
										keptCon.put(fieldName,fieldValue);
									}
							}
							
						}
					}
				}
				if(keptCon != keptConOld)
					updateContactMap.put(keptCon.Id,keptCon);
			}
		}
		if(updateContactMap.size()>0)
			update updateContactMap.values();
		return mergeRecords;
	}
	/*******************************************************************************************************
	* @description get a map of contact merge fields keyed by field name lowercase
	* @param mergeFields
	* @return Map<String, ContactMergeField__mdt>
	*/
	public static Map<String, ContactMergeField__mdt> getMergeFieldMap(List<ContactMergeField__mdt> mergeFields) {
		Map<String, ContactMergeField__mdt> mergeFieldMap = new Map<String, ContactMergeField__mdt>();
		for(ContactMergeField__mdt mergeField:mergeFields) {
			mergeFieldMap.put(mergeField.Field__r.QualifiedAPIName.toLowerCase(), mergeField);
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
}