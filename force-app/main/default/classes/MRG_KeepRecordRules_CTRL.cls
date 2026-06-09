/**
* @author tj@tjgriffin.com
* @group Merge
* @description controller for the Keep Record Rules LWC tab. Loads/saves keep-record rules and
* provides the object field list and operator options for the criteria builder.
*/
public with sharing class MRG_KeepRecordRules_CTRL {

	/*******************************************************************************************************
	* @description the keep-record rules configured for an object, ordered
	* @param objectType the SObject api name
	* @return List<MRG_KeepRecordRule> the rules (empty when none)
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_KeepRecordRule> getKeepRecordRules(String objectType) {
		if(String.isBlank(objectType))
			return new List<MRG_KeepRecordRule>();
		return MRG_KeepRecordRule.getRules(objectType);
	}

	/*******************************************************************************************************
	* @description the updateable, accessible fields for an object (label, name, type) for field pickers.
	* Reuses the field describe used by the field-settings UI.
	* @param objectType the SObject api name
	* @return List<MRG_Merge_SVC.objectField>
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_Merge_SVC.objectField> getObjectFields(String objectType) {
		// keep-record conditions only READ values to choose a record, so offer all readable fields
		// (incl. CreatedDate / LastModifiedDate / formulas), not just updateable ones
		return MRG_MergeSettings_CTRL.getReadableObjectFields(objectType);
	}

	/*******************************************************************************************************
	* @description the condition operator options for the criteria builder
	* @return List<operatorOption>
	*/
	@auraEnabled(cacheable=true)
	public static List<operatorOption> getOperators() {
		return new List<operatorOption>{
			new operatorOption('equals', 'equals'),
			new operatorOption('notEquals', 'not equals'),
			new operatorOption('lessThan', 'less than'),
			new operatorOption('lessOrEqual', 'less or equal'),
			new operatorOption('greaterThan', 'greater than'),
			new operatorOption('greaterOrEqual', 'greater or equal'),
			new operatorOption('contains', 'contains'),
			new operatorOption('startsWith', 'starts with'),
			new operatorOption('endsWith', 'ends with')
		};
	}

	/*******************************************************************************************************
	* @description saves the keep-record rules supplied as JSON from the UI. Validates each rule's filter
	* logic before deploying so a malformed expression is rejected with a clear message.
	* @param jsonData a JSON array of MRG_KeepRecordRule
	* @return String the metadata deploy job id
	*/
	@auraEnabled
	public static String saveKeepRecordRules(String jsonData) {
		List<MRG_KeepRecordRule> rules = (List<MRG_KeepRecordRule>) JSON.deserialize(jsonData, List<MRG_KeepRecordRule>.class);
		for(MRG_KeepRecordRule rule:rules) {
			Integer count = rule.conditions == null ? 0 : rule.conditions.size();
			try {
				MRG_FilterLogic.validate(rule.filterLogic, count);
			} catch(MRG_FilterLogic.ParseException e) {
				throw new AuraHandledException('Invalid filter logic for rule "' + rule.label + '": ' + e.getMessage());
			}
		}
		return MRG_KeepRecordRule.saveKeepRecordRules(rules);
	}

	/*******************************************************************************************************
	* @description a condition operator option for the UI
	*/
	public class operatorOption {
		@auraEnabled public String value;
		@auraEnabled public String label;
		public operatorOption(String value, String label) {
			this.value = value;
			this.label = label;
		}
	}
}
