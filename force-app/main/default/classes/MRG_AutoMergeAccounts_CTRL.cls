/**
* @author tj@tjgriffin.com
* @group Merge
* @description controller for the Auto-Merge Accounts Rules LWC tab (#35). Loads/saves the rules and
* provides object fields, operators, and aggregator options for the rule builder.
*/
public with sharing class MRG_AutoMergeAccounts_CTRL {

	/*******************************************************************************************************
	* @description the auto-merge-accounts rules configured for an object
	* @param objectType the SObject api name
	* @return List<MRG_AutoMergeAccountsRule>
	*/
	// not cacheable: rules are edited in this same UI and re-loaded right after a save, so a cached
	// (pre-save) result would make the freshly saved rules appear to be missing
	@auraEnabled
	public static List<MRG_AutoMergeAccountsRule> getRules(String objectType) {
		if(String.isBlank(objectType))
			return new List<MRG_AutoMergeAccountsRule>();
		return MRG_AutoMergeAccountsRule.getRules(objectType);
	}

	/*******************************************************************************************************
	* @description readable fields for the condition pickers (selectors only read values)
	* @param objectType the SObject api name
	* @return List<MRG_Merge_SVC.objectField>
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_Merge_SVC.objectField> getObjectFields(String objectType) {
		return MRG_MergeSettings_CTRL.getReadableObjectFields(objectType);
	}

	/*******************************************************************************************************
	* @description condition operator options
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_KeepRecordRules_CTRL.operatorOption> getOperators() {
		return MRG_KeepRecordRules_CTRL.getOperators();
	}

	/*******************************************************************************************************
	* @description cross-record aggregator options
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_KeepRecordRules_CTRL.operatorOption> getAggregators() {
		return new List<MRG_KeepRecordRules_CTRL.operatorOption>{
			new MRG_KeepRecordRules_CTRL.operatorOption('all', 'all records match'),
			new MRG_KeepRecordRules_CTRL.operatorOption('any', 'any record matches'),
			new MRG_KeepRecordRules_CTRL.operatorOption('differ', 'values differ'),
			new MRG_KeepRecordRules_CTRL.operatorOption('same', 'values are the same')
		};
	}

	/*******************************************************************************************************
	* @description saves the rules supplied as JSON; validates each rule's filter logic before deploying
	* @param jsonData a JSON array of MRG_AutoMergeAccountsRule
	* @return String the metadata deploy job id
	*/
	@auraEnabled
	public static String saveRules(String jsonData) {
		List<MRG_AutoMergeAccountsRule> rules = (List<MRG_AutoMergeAccountsRule>) JSON.deserialize(jsonData, List<MRG_AutoMergeAccountsRule>.class);
		for(MRG_AutoMergeAccountsRule rule:rules) {
			Integer count = rule.conditions == null ? 0 : rule.conditions.size();
			try {
				MRG_FilterLogic.validate(rule.filterLogic, count);
			} catch(MRG_FilterLogic.ParseException e) {
				throw new AuraHandledException('Invalid filter logic for rule "' + rule.label + '": ' + e.getMessage());
			}
		}
		return MRG_AutoMergeAccountsRule.saveRules(rules);
	}
}
