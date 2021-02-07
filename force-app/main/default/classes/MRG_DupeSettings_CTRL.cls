/**
* @author tj@tjgriffin.com
* @date 2020
* @group Duplicate
* @description controller for dupe settings lwc
*/
public with sharing class MRG_DupeSettings_CTRL {
	/*******************************************************************************************************
	* @description gets profiles with delete permissions to account or contact
	* @return List<dupeRule>
	*/	
	@auraEnabled(cacheable=true)
    public static List<MRG_Duplicate_SVC.dupeRule> getDuplicateRuleSettings(){
        return MRG_Duplicate_SVC.duplicateRuleSettings;
    }
	/*******************************************************************************************************
	* @description gets profiles with delete permissions to account or contact
	* @return List<dupeRule>
	*/	
	@auraEnabled(cacheable=true)
    public static List<MRG_Duplicate_SVC.dupeRule> getActiveDuplicateRules(){
        return MRG_Duplicate_SVC.getActiveDuplicateRules();
    }

	/*******************************************************************************************************
	* @description handles save
	* @param String the JSON string to save
	* @return String jobId
	*/
	@AuraEnabled
	public static String saveDuplicateRuleSettings(String jsonData) {
		List<MRG_Duplicate_SVC.dupeRule> dupeRules = (List<MRG_Duplicate_SVC.dupeRule>) JSON.deserialize(jsonData, List<MRG_Duplicate_SVC.dupeRule>.class);
		return MRG_Duplicate_SVC.saveDuplicateRules(dupeRules);
	}
}
