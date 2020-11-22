/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description Service for dealing with contact merges
*/
public with sharing class CON_Merge_SVC {
	/*******************************************************************************************************
	* @description Returns the merge fields
	* @param mergeFields the mergeFieldWrap collection to save
	* @return  String metaData deploy job Id
	*/	
	public static String saveMergeFields(List<mergeFieldWrap> mergeFields) {
		CON_Metadata_SVC mdService = new CON_Metadata_SVC();
		List<ContactMergeField__mdt> mergeFieldMetadata = new List<ContactMergeField__mdt>();
		for(mergeFieldWrap mergeField:mergeFields) {
			mergeFieldMetadata.add(getMergeFieldFromObject(mergeField));
		}
			
		List<Metadata.CustomMetadata> mdRecords = new List<Metadata.CustomMetadata>();
		// get metadata and add to record list
		for(ContactMergeField__mdt mergeField:mergeFieldMetadata) {
			Metadata.CustomMetadata mdRecord =  mdService.getMetaDataRecord(mergeField);
			mdRecords.add(mdRecord);
		}
		// deploy record via metadata api
		return mdService.deployMetadataRecords(mdRecords);
	}
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
		@auraEnabled public Boolean disable;

		public mergeFieldWrap(ContactMergeField__mdt mergeField) {
			this.id = mergeField.Id;
			this.label = mergeField.Label;
			this.name = mergeField.QualifiedAPIName;
			this.objectName = mergeField.Object__r.QualifiedAPIName;
			this.fieldName = mergeField.Field__r.QualifiedAPIName;
			this.type = mergeField.Type__c.left(1).toLowerCase();
			this.rule = mergeField.PreservationRule__c;
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
	* @return ContactMergeField__mdt the merge field metadata record
	*/	
	public static ContactMergeField__mdt getMergeFieldFromObject(mergeFieldWrap mfw) {
		ContactMergeField__mdt mergeField = new ContactMergeField__mdt(
			Label = mfw.label,
			PreservationRule__c = mfw.rule,
			Disable__c = mfw.disable

		);
		mergeField.Type__c = mfw.type == 't' ? 'Track' : 'Preserve';
		if(String.isNotBlank(mfw.id))
			mergeField.Id = mfw.id;
		mergeField.QualifiedAPIName = String.isBlank(mfw.name) ? mfw.fieldName + mfw.objectName : mfw.name;
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
		mergeFieldJSON.put('Field__r',fldField);
		mergeFieldJSON.put('Object__r',objField);

		mergeField = (ContactMergeField__mdt) JSON.deserialize(JSON.serialize(mergeFieldJSON),ContactMergeField__mdt.class);

		return mergeField;
	}


	/*******************************************************************************************************
	* @description merge fields from custom metadata
	*/	
	public static List<ContactMergeField__mdt> mergeFields {
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
					Disable__c,
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
	public static List<mergeFieldWrap> getTrackMergeFields() {
		List<mergeFieldWrap> trackMergeFields = new List<mergeFieldWrap>();
		for(ContactMergeField__mdt mergeField:mergeFields) {
			if(mergeField.Type__c != null
				&& mergeField.Type__c.equalsIgnoreCase('Track'))
				trackMergeFields.add(new mergeFieldWrap(mergeField));
		}
		return trackMergeFields;
	}

	/*******************************************************************************************************
	* @description a list of fields to preserve based on preservation rule
	* @return List<ContactMergeField__mdt>
	*/	
	public static List<mergeFieldWrap> getPreserveMergeFields() {
		List<mergeFieldWrap> preserveMergeFields = new List<mergeFieldWrap>();
		for(ContactMergeField__mdt mergeField:mergeFields) {
			if(mergeField.Type__c != null
				&& mergeField.Type__c.equalsIgnoreCase('Preserve'))
				preserveMergeFields.add(new mergeFieldWrap(mergeField));
		}
		return preserveMergeFields;
	}

	/*******************************************************************************************************
	* @description translates deleted contacts into merge records
	* @param List<Contact> oldlist a list of records from trigger.old
	* @return List<Merge__c> the resulting sync record import list
	*/
	public static void createMergeRecords(List<Contact> deletedContacts) {
		
		List<mergeFieldWrap> trackMergeFields = getTrackMergeFields();
		List<mergeFieldWrap> preserveMergeFields = getPreserveMergeFields();
		
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
	public static List<Merge__c> getMergesFromDeletedContacts(List<Contact> mergedContacts, Map<Id,Contact> keptContactMap, List<mergeFieldWrap> trackMergeFields, List<mergeFieldWrap> preserveMergeFields) {
		Map<String, mergeFieldWrap> trackfieldMap = new Map<String, mergeFieldWrap>(getMergeFieldMap(trackMergeFields));
		Map<String, mergeFieldWrap> preserveFieldMap = new Map<String, mergeFieldWrap>(getMergeFieldMap(preserveMergeFields));
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
					mergeFieldWrap trackField = trackfieldMap.containsKey(fieldName) ? trackfieldMap.get(fieldName) : null;
					mergeFieldWrap preserveField = preserveFieldMap.containsKey(fieldName) ? preserveFieldMap.get(fieldName) : null;
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
							if(testValue(fieldValue, keptContactFieldValue, preserveField.rule, keptcontactIsOlder)) {
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
	public static Map<String, mergeFieldWrap> getMergeFieldMap(List<mergeFieldWrap> mergeFields) {
		Map<String, mergeFieldWrap> mergeFieldMap = new Map<String, mergeFieldWrap>();
		for(mergeFieldWrap mergeField:mergeFields) {
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
}