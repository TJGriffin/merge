public with sharing class CON_MergeSettings_CTRL {
	/*******************************************************************************************************
	* @description a set of fields to always ignore
	*/
	private static Set<String> ignoreFields {
		get {
			return new Set<String>{
				'individualid',
				'contact.individualid'
			};
		}
		set;
	}
	
	/*******************************************************************************************************
	* @description get all merge fields
	* @return List<mergeFieldWrap>
	*/	
	@auraEnabled(cacheable=true) public static List<CON_Merge_SVC.mergeFieldWrap> getAllMergeFields() {
		List<CON_Merge_SVC.mergeFieldWrap> mergeFieldWraps = new List<CON_Merge_SVC.mergeFieldWrap>();

		for(ContactMergeField__mdt mergeField:CON_Merge_SVC.mergeFields) {
			mergeFieldWraps.add(new CON_Merge_SVC.mergeFieldWrap(mergeField));
		}
		return mergeFieldWraps;
	}
	/*******************************************************************************************************
	* @description get all merge fields
    * @param type the type of merge field to return
	* @return List<mergeFieldWrap>
	*/
    @auraEnabled(cacheable=true) public static List<CON_Merge_SVC.mergeFieldWrap> getAllMergeFields(String type, String objectType) {
		List<CON_Merge_SVC.mergeFieldWrap> mergeFieldWraps = new List<CON_Merge_SVC.mergeFieldWrap>();
		List<CON_Merge_SVC.mergeFieldWrap> mergeFields = new List<CON_Merge_SVC.mergeFieldWrap>();
		if(String.isBlank(type)) {
			mergeFields.addAll(CON_Merge_SVC.getTrackMergeFields());
			mergeFields.addAll(CON_Merge_SVC.getPreserveMergeFields());
		} else {
        	mergeFields = type.equalsIgnoreCase('t') ? CON_Merge_SVC.getTrackMergeFields() : CON_Merge_SVC.getPreserveMergeFields();
		} 
		for(CON_Merge_SVC.mergeFieldWrap mergeField:mergeFields){
			if(String.isNotBlank(objectType)) {
				if(mergeField.objectName.equalsIgnoreCase(objectType))
				mergeFieldWraps.add(mergeField);
			} else {
				mergeFieldWraps.add(mergeField);
			}	
		}
		return mergeFieldWraps;
    }
	/*******************************************************************************************************
	* @description get all merge fields
	* @return List<mergeFieldWrap>
	*/
	@auraEnabled(cacheable=true)
	public static List<CON_Merge_SVC.objectField> getObjectFields(String objectType) {
		List<CON_Merge_SVC.objectField> fields = new List<CON_Merge_SVC.objectField>();
		SObjectType objType = Schema.getGlobalDescribe().get(objectType);
		for(SObjectfield objField : objType.getDescribe().fields.getMap().values()) {
			if(objField.getDescribe().isAccessible() 
			&& objField.getDescribe().isUpdateable()
			&& !ignoreFields.contains(objField.getDescribe().getName().toLowerCase())) {
				fields.add(new CON_Merge_SVC.objectField(objField));
			}
		}
		fields.sort();

		return fields;
	}
	/*******************************************************************************************************
	* @description handles save
	* @param String the JSON string to save
	* @return String jobId
	*/
	@AuraEnabled(cacheable=TRUE)
	public static String saveMergeFields(String jsonData) {
		List<CON_Merge_SVC.mergeFieldWrap> mergeFields = (List<CON_Merge_SVC.mergeFieldWrap>) JSON.deserialize(jsonData, List<CON_Merge_SVC.mergeFieldWrap>.class);
		return CON_Merge_SVC.saveMergeFields(mergeFields);
	}
}
