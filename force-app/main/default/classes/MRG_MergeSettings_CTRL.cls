/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description controller for merge settings lwc
*/
public with sharing class MRG_MergeSettings_CTRL {
	/*******************************************************************************************************
	* @description a set of fields to always ignore
	*/
	public static String getPreviewFieldsSOQL(){
		String soql='SELECT Id,';
		soql+=' QualifiedAPIName,';
		soql+=' Label,';
		soql+=' Object__c,';
		soql+=' Object__r.QualifiedAPIName,';
		soql+=' Field__c,';
		soql+=' Field__r.QualifiedAPIName,';
		soql+=' Disable__c,';
		soql+=' ReadOnly__c';
		soql+=' FROM PreviewFields__mdt';
		return soql;
	}	
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
	* @description gets profiles with delete permissions to account or contact
	* @return List<userWrap>
	*/	
	@auraEnabled(cacheable=true)
	public static List<profileWrap> getProfiles(){
		Map<Id, profileWrap> profileWraps = new Map<Id, profileWrap>();
		for(PermissionSet ps:[
			SELECT 
				ProfileId,
				Profile.Name
			FROM PermissionSet
			WHERE IsOwnedByProfile=true
			AND Id IN (
				SELECT ParentId
				FROM ObjectPermissions
				WHERE PermissionsDelete=true
				AND (SObjectType='Account'
					OR SObjectType='Contact'
				)
			)
			]){
			profileWraps.put(ps.ProfileId,new profileWrap(new Profile(Id=ps.profileId,Name=ps.Profile.Name)));
		}
		return profileWraps.values();
	}

	/*******************************************************************************************************
	* @description get users with delete permissions to account or contact
	* @return List<userWrap>
	*/	
	@auraEnabled(cacheable=true)
	public static List<userWrap> getUsers(){
		List<userWrap> userWraps = new List<userWrap>();
		Set<Id> profilesWithDelete = new Set<Id>();
		for(PermissionSet ps:[
			SELECT ProfileId
			FROM PermissionSet
			WHERE IsOwnedByProfile=true
			AND Id IN (
				SELECT ParentId
				FROM ObjectPermissions
				WHERE PermissionsDelete=true
				AND (SObjectType='Account'
					OR SObjectType='Contact'
				)
			)
			]){
			profilesWithDelete.add(ps.ProfileId);
		}
		for(User usr:[
			SELECT
			Id,
			FirstName,
			LastName,
			UserName,
			Email,
			ProfileId,
			Profile.Name
			FROM User
			WHERE IsActive=true
			]) {
			if(profilesWithDelete.contains(usr.ProfileId))
				userWraps.add(new userWrap(usr));
		}
		return userWraps;
	}
	/*******************************************************************************************************
	* @description get all merge fields
	* @return List<mergeFieldWrap>
	*/	
	@auraEnabled(cacheable=true) public static List<previewField> getAllPreviewFields() {
		List<previewField> pFields = new List<previewField>();

		for(PreviewFields__mdt pField:MRG_Merge_SVC.previewFields) {
			 pFields.add(new previewField(pField));
		}
		if(pFields.size()>0)
			pFields.sort();
		return pFields;
	}
	/*******************************************************************************************************
	* @description get all merge fields
	* @return List<mergeFieldWrap>
	*/	
	@auraEnabled(cacheable=true) public static List<previewField> getAllPreviewFields(String objectType) {
		List<previewField> previewfields = new List<previewField>();
		for(previewField pField:getAllPreviewFields()){
			if(String.isBlank(objectType) ||
				pField.objectName == objectType)
				previewFields.add(pField);
		}
		return previewfields;
	}
	/*******************************************************************************************************
	* @description get all merge fields
	* @return List<mergeFieldWrap>
	*/	
	@auraEnabled(cacheable=true) public static List<MRG_Merge_SVC.mergeFieldWrap> getAllMergeFields() {
		List<MRG_Merge_SVC.mergeFieldWrap> mergeFieldWraps = new List<MRG_Merge_SVC.mergeFieldWrap>();

		for(MergeFieldSetting__mdt mergeField:MRG_Merge_SVC.mergeFields) {
			mergeFieldWraps.add(new MRG_Merge_SVC.mergeFieldWrap(mergeField));
		}
		if(mergeFieldWraps.size()>0)
			mergeFieldWraps.sort();
		return mergeFieldWraps;
	}
	/*******************************************************************************************************
	* @description get all merge fields
    * @param type the type of merge field to return
    * @param objectType the type of object to filter on
	* @return List<MRG_Merge_SVC.mergeFieldWrap>
	*/
    @auraEnabled(cacheable=true) 
	public static List<MRG_Merge_SVC.mergeFieldWrap> getAllMergeFields(String type, String objectType) {
		List<MRG_Merge_SVC.mergeFieldWrap> mergeFieldWraps = new List<MRG_Merge_SVC.mergeFieldWrap>();
		List<MRG_Merge_SVC.mergeFieldWrap> mergeFields = new List<MRG_Merge_SVC.mergeFieldWrap>();
		if(String.isBlank(type)) {
			mergeFields.addAll(MRG_Merge_SVC.getTrackMergeFields());
			mergeFields.addAll(MRG_Merge_SVC.getPreserveMergeFields());
		} else {
        	mergeFields = type.equalsIgnoreCase('t') ? MRG_Merge_SVC.getTrackMergeFields() : MRG_Merge_SVC.getPreserveMergeFields();
		} 
		for(MRG_Merge_SVC.mergeFieldWrap mergeField:mergeFields){
			if(String.isNotBlank(objectType)) {
				if(mergeField.objectName.equalsIgnoreCase(objectType))
				mergeFieldWraps.add(mergeField);
			} else {
				mergeFieldWraps.add(mergeField);
			}	
		}
		if(mergeFieldWraps.size()>0)
			mergeFieldWraps.sort();
		return mergeFieldWraps;
    }
	/*******************************************************************************************************
	* @description get all merge fields
	* @return MRG_Merge_SVC.mergeSetting
	*/
	@auraEnabled(cacheable=true)
	public static MRG_Merge_SVC.mergeSetting getMergeSetting(){
		MergeControlSettings__c settings = MRG_Merge_SVC.getSettings();
		if(settings==null)
			settings = new MergeControlSettings__c();
		return new MRG_Merge_SVC.mergeSetting(settings);
	}
	/*******************************************************************************************************
	* @description get all merge fields
    * @param mergeSettingJSON the json representation of the setting
	* @return MRG_Merge_SVC.mergeSetting
	*/
	@auraEnabled
	public static MRG_Merge_SVC.mergeSetting saveMergeSettings(String mergeSettingJSON){
		MRG_Merge_SVC.mergeSetting settingsObj = (MRG_Merge_SVC.mergeSetting) JSON.deserialize(mergeSettingJSON,MRG_Merge_SVC.mergeSetting.class);
		MergeControlSettings__c setting = MRG_Merge_SVC.getSettingsFromObject(settingsObj);
		MergeControlSettings__c defaultSettings = MRG_Merge_SVC.getSettings();
		setting.Id = String.isNotBlank(defaultSettings.Id) ? defaultSettings.Id : null;

		upsert setting;

		return new MRG_Merge_SVC.mergeSetting(setting);

	}	
	/*******************************************************************************************************
	* @description gets fields for a specific object
	* @param objectType the type of object
	* @return List<MRG_Merge_SVC.objectField>
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_Merge_SVC.objectField> getObjectFields(String objectType) {
		List<MRG_Merge_SVC.objectField> fields = new List<MRG_Merge_SVC.objectField>();
		if(String.isBlank(objectType))
			return fields;
		SObjectType objType = Schema.getGlobalDescribe().get(objectType);
		for(SObjectfield objField : objType.getDescribe().fields.getMap().values()) {
			if(objField.getDescribe().isAccessible() 
			&& !ignoreFields.contains(objField.getDescribe().getName().toLowerCase())) {
				fields.add(new MRG_Merge_SVC.objectField(objField));
			}
		}
		if(fields.size()>0)
			fields.sort();

		return fields;
	}
	/*******************************************************************************************************
	* @description handles save
	* @param String the JSON string to save
	* @return String jobId
	*/
	@AuraEnabled
	public static String savePreviewFieldsSettings(String jsonData) {
		List<previewField> pFields= (List<previewField>) JSON.deserialize(jsonData, List<previewField>.class);
		return MRG_Merge_SVC.savePreviewFields(pFields);
	}
	/*******************************************************************************************************
	* @description handles save
	* @param String the JSON string to save
	* @return String 
	*/
	@AuraEnabled(cacheable=TRUE)
	public static String saveMergeFields(String jsonData) {
		List<MRG_Merge_SVC.mergeFieldWrap> mergeFields = (List<MRG_Merge_SVC.mergeFieldWrap>) JSON.deserialize(jsonData, List<MRG_Merge_SVC.mergeFieldWrap>.class);
		return MRG_Merge_SVC.saveMergeFields(mergeFields);
	}
	/*******************************************************************************************************
	* @description preview field wrapper
	*/
	public class previewField implements Comparable {
		@AuraEnabled public String id;
		@AuraEnabled public String label;
		@AuraEnabled public String name;
		@AuraEnabled public String objectName;
		@AuraEnabled public String fieldName;
		@AuraEnabled public Boolean hidden;
		@AuraEnabled public Boolean readOnly;

		public previewField(PreviewFields__mdt pField){
			this.id = pField.Id;
			this.label = pField.Label;
			this.name = pField.QualifiedAPIName;
			this.objectName = pField.Object__r.QualifiedAPIName;
			this.fieldName = pField.Field__r.QualifiedAPIName;
			this.hidden = pField.Disable__c;
			this.readOnly = pField.ReadOnly__c;
		}
		public Integer compareTo(Object compareTo) {
			previewField sortObj = (previewField) compareTo;
			return this.fieldName > sortObj.fieldName ? 1 : -1;
		}
	}
	/*******************************************************************************************************
	* @description user wrapper
	*/
	public class userWrap implements Comparable {
		@AuraEnabled public String id;
		@AuraEnabled public String userName;
		@AuraEnabled public String firstName;
		@auraEnabled public String lastName;
		@auraEnabled public String profile;
		@auraEnabled public String email;

		public userWrap(User usr) {
			this.id = usr.Id;
			this.userName = usr.UserName;
			this.firstName = usr.FirstName;
			this.lastName = usr.LastNAme;
			this.profile = usr.Profile.Name;
			this.email = usr.Email;
		}
		public Integer compareTo(Object compareTo) {
			userWrap sortObj = (userWrap) compareTo;
			return this.lastName > sortObj.lastName ? 1 : -1;
		}

	}
	/*******************************************************************************************************
	* @description user wrapper
	*/
	public class profileWrap implements Comparable {
		@AuraEnabled public String id;
		@AuraEnabled public String name;

		public profileWrap(Profile p) {
			this.id = p.Id;
			this.name = p.Name;
		}
		public Integer compareTo(Object compareTo) {
			profileWrap sortObj = (profileWrap) compareTo;
			return this.name > sortObj.name ? 1 : -1;
		}

	}
}
