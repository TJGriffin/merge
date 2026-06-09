/**
* @author tj@tjgriffin.com
* @group Merge
* @description controller for the Fallback Rules LWC tab. Loads/saves fallback rules and provides the
* object field list and operator options for the rule builder.
*/
public with sharing class MRG_FallbackRules_CTRL {

	/*******************************************************************************************************
	* @description the fallback rules configured for an object
	* @param objectType the SObject api name
	* @return List<MRG_FallbackRule>
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_FallbackRule> getFallbackRules(String objectType) {
		if(String.isBlank(objectType))
			return new List<MRG_FallbackRule>();
		return MRG_FallbackRule.getRules(objectType);
	}

	/*******************************************************************************************************
	* @description updateable, accessible fields for an object (label, name, type) for field pickers
	* @param objectType the SObject api name
	* @return List<MRG_Merge_SVC.objectField>
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_Merge_SVC.objectField> getObjectFields(String objectType) {
		return MRG_MergeSettings_CTRL.getObjectFields(objectType);
	}

	/*******************************************************************************************************
	* @description condition operator options
	* @return List<MRG_KeepRecordRules_CTRL.operatorOption>
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_KeepRecordRules_CTRL.operatorOption> getOperators() {
		return MRG_KeepRecordRules_CTRL.getOperators();
	}

	/*******************************************************************************************************
	* @description saves the fallback rules supplied as JSON from the UI. Validates each complex rule's
	* filter logic before deploying.
	* @param jsonData a JSON array of MRG_FallbackRule
	* @return String the metadata deploy job id
	*/
	@auraEnabled
	public static String saveFallbackRules(String jsonData) {
		List<MRG_FallbackRule> rules = (List<MRG_FallbackRule>) JSON.deserialize(jsonData, List<MRG_FallbackRule>.class);
		for(MRG_FallbackRule rule:rules) {
			if(rule.selectionType == 'complex') {
				Integer count = rule.conditions == null ? 0 : rule.conditions.size();
				try {
					MRG_FilterLogic.validate(rule.filterLogic, count);
				} catch(MRG_FilterLogic.ParseException e) {
					throw new AuraHandledException('Invalid filter logic for fallback "' + rule.label + '": ' + e.getMessage());
				}
			}
		}
		return MRG_FallbackRule.saveFallbackRules(rules);
	}
}
