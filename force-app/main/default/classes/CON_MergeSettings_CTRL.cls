/**
* @author tj@tjgriffin.com
* @date 2020
* @group Merge
* @description controller for merge settings lwc
*/
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
	@auraEnabled(cacheable=true) public static List<CON_Merge_SVC.mergeFieldWrap> getAllMergeFields() {
		List<CON_Merge_SVC.mergeFieldWrap> mergeFieldWraps = new List<CON_Merge_SVC.mergeFieldWrap>();

		for(ContactMergeField__mdt mergeField:CON_Merge_SVC.mergeFields) {
			mergeFieldWraps.add(new CON_Merge_SVC.mergeFieldWrap(mergeField));
		}
		if(mergeFieldWraps.size()>0)
			mergeFieldWraps.sort();
		return mergeFieldWraps;
	}
	/*******************************************************************************************************
	* @description get all merge fields
    * @param type the type of merge field to return
	* @return List<mergeFieldWrap>
	*/
	@auraEnabled(cacheable=true)
	public static CON_Merge_SVC.mergeSetting getMergeSetting(){
		MergeControlSettings__c settings = CON_Merge_SVC.getSettings();
		if(settings==null)
			settings = new MergeControlSettings__c();
		return new CON_Merge_SVC.mergeSetting(settings);
	}
	/*******************************************************************************************************
	* @description get all merge fields
    * @param type the type of merge field to return
	* @return List<mergeFieldWrap>
	*/
	@auraEnabled
	public static CON_Merge_SVC.mergeSetting saveMergeSettings(String mergeSettingJSON){
		CON_Merge_SVC.mergeSetting settingsObj = (CON_Merge_SVC.mergeSetting) JSON.deserialize(mergeSettingJSON,CON_Merge_SVC.mergeSetting.class);
		MergeControlSettings__c setting = CON_Merge_SVC.getSettingsFromObject(settingsObj);
		MergeControlSettings__c defaultSettings = CON_Merge_SVC.getSettings();
		setting.Id = String.isNotBlank(defaultSettings.Id) ? defaultSettings.Id : null;

		upsert setting;

		return new CON_Merge_SVC.mergeSetting(setting);

	}	
	/*******************************************************************************************************
	* @description get all merge fields
    * @param type the type of merge field to return
	* @return List<mergeFieldWrap>
	*/
    @auraEnabled(cacheable=true) 
	public static List<CON_Merge_SVC.mergeFieldWrap> getAllMergeFields(String type, String objectType) {
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
		if(mergeFieldWraps.size()>0)
			mergeFieldWraps.sort();
		return mergeFieldWraps;
    }
	/*******************************************************************************************************
	* @description get all merge fields
	* @return List<mergeFieldWrap>
	*/
	@auraEnabled(cacheable=true)
	public static List<CON_Merge_SVC.objectField> getObjectFields(String objectType) {
		List<CON_Merge_SVC.objectField> fields = new List<CON_Merge_SVC.objectField>();
		if(String.isBlank(objectType))
			return fields;
		SObjectType objType = Schema.getGlobalDescribe().get(objectType);
		for(SObjectfield objField : objType.getDescribe().fields.getMap().values()) {
			if(objField.getDescribe().isAccessible() 
			&& objField.getDescribe().isUpdateable()
			&& !ignoreFields.contains(objField.getDescribe().getName().toLowerCase())) {
				fields.add(new CON_Merge_SVC.objectField(objField));
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
	@AuraEnabled(cacheable=TRUE)
	public static String saveMergeFields(String jsonData) {
		List<CON_Merge_SVC.mergeFieldWrap> mergeFields = (List<CON_Merge_SVC.mergeFieldWrap>) JSON.deserialize(jsonData, List<CON_Merge_SVC.mergeFieldWrap>.class);
		return CON_Merge_SVC.saveMergeFields(mergeFields);
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
