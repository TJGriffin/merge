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
	public static Set<String> writeableFields {
		get {
			if(writeableFields == null)
				writeableFields = getWriteableFields('Contact');
			return writeableFields;
		}
		set;
	}

	/*******************************************************************************************************
	* @description merge fields from custom metadata
	*/	
	@testVisible private static List<ContactMergeField__mdt> mergeFields {
		get {
			if(mergeFields == null) {
				return new List<ContactMergeField__mdt>([SELECT
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
		set;
	}

	/*******************************************************************************************************
	* @description a list of fields to track in Merge__c
	* @return List<ContactMergeField__mdt>
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
	* @description a list of fields to preserve based on preservation rule
	* @return List<ContactMergeField__mdt>
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
		soqlQuery+=', '+String.join((Iterable<String>) writeableFields, ',');
		soqlQuery+=' FROM Contact';
		
		return soqlQuery;
	}
	
	/*******************************************************************************************************
	* @description returns a list of Merge records for saving
	* @param List<Contact> deleted contacts
	* @param Map<Id,Contact> kept contacts
	* @return List<Merge__c> the resulting sync record import list
	*/
	public static List<Merge__c> getMergesFromDeletedContacts(List<Contact> mergedContacts, Map<Id,Contact> keptContactMap, List<ContactMergeField__mdt> trackMergeFields, List<ContactMergeField__mdt> preserveMergeFields) {
		Map<String, ContactMergeField__mdt> trackfieldMap = new Map<String, ContactMergeField__mdt>(getMergeFieldMap(trackMergeFields));
		Map<String, ContactMergeField__mdt> preserveFieldMap = new Map<String, ContactMergeField__mdt>(getMergeFieldMap(preserveMergeFields));
		system.debug(JSON.serialize(preserveFieldMap));
		List<Merge__c> mergeRecords = new List<Merge__c>();
		Map<Id, Contact> updateContactMap = new Map<Id, Contact>();
		for(Contact con:mergedContacts) {
			if(keptContactMap.containsKey(con.MasterRecordId)) {
				Contact keptConOld = keptContactMap.get(con.MasterRecordId);
				Contact keptCon = keptContactMap.get(con.MasterRecordId);
				Boolean keptcontactIsOlder = keptCon.CreatedDate < con.CreatedDate;
				Boolean hasChange = false;
				for(String fieldName:writeableFields) {
					ContactMergeField__mdt trackField = trackfieldMap.containsKey(fieldName) ? trackfieldMap.get(fieldName) : null;
					ContactMergeField__mdt preserveField = preserveFieldMap.containsKey(fieldName) ? preserveFieldMap.get(fieldName) : null;
					Object fieldValue = con.get(fieldName);
					Object keptContactfieldValue = keptCon.get(fieldName);

					if(fieldValue!= null) {
						// if we should track this field then track it
						if(trackField != null) {
							if(keptContactfieldValue == null
								|| (keptContactFieldValue != null 
								&& keptContactFieldValue != fieldValue))
								mergeRecords.add(getMergeRecord(keptContactFieldValue, fieldValue, keptCon, fieldName));
						}
						// if we should preserve thie value then preserve it
						if(preserveField != null) {
							if(testValue(fieldValue, keptContactFieldValue, preserveField.PreservationRule__c, keptcontactIsOlder)) {
								keptCon.put(fieldName,fieldValue);
								hasChange=true;
							}
						}
						// test for nulls and booleans for non preserved fields
						if(preserveField == null) {
							// if the new value is null then preserve it
							if(keptContactfieldValue==null) {
								keptCon.put(fieldName,fieldValue);
								hasChange = true;
							}
							// if it is a boolean field and the old value is true then preserve it
							if(getObjectType(fieldValue) == 'Boolean'
								&& (Boolean) fieldValue) {
								keptCon.put(fieldname,fieldValue);
								hasChange=true;
							}
						}
					}
				}
				if(hasChange)
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
	/*******************************************************************************************************
	* @description gets writeable fields for a contact record
	* @param objectType the string representation of the object type
	* @return Set<String> writeable fields
	*/
	public static Merge__c getMergeRecord(Object keptContactFieldValue, Object fieldValue, Contact keptCon, String fieldName) {
		Merge__c mergeRecord = new Merge__c(
			KeptContactId__c = keptCon.Id,
			KeptValue__c = String.valueOf(keptContactfieldValue),
			MergeValue__c = String.valueOf(fieldValue),
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
		if(isOldest || isNewest) {
			result = (isOldest && !keptContactIsOlder) || (isNewest && keptContactIsOlder);
		}
		if(isLargest || isSmallest) {
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
				when 'Long' {
					result = (isLargest && (Long) fieldValue > (Long) keptContactFieldValue) || (isSmallest && (Long)fieldValue < (Long)keptContactFieldValue);
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
}