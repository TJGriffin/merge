/**
* @author tj@tjgriffin.com
* @group Merge
* @description controller for the Keep Record Rules LWC tab. Loads/saves the ordered, comparative
* keep-record rules of an object and provides the field list and preference options for the editor.
*/
public with sharing class MRG_KeepRecordRules_CTRL {

	/*******************************************************************************************************
	* @description the active keep-record rules configured for an object, in evaluation order
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
	* @description the readable fields of an object (label, name, type) for the field picker. Keep-record
	* rules only read values, so system fields such as CreatedDate and formulas are offered too.
	* @param objectType the SObject api name
	* @return List<MRG_Merge_SVC.objectField>
	*/
	@auraEnabled(cacheable=true)
	public static List<MRG_Merge_SVC.objectField> getObjectFields(String objectType) {
		return MRG_MergeSettings_CTRL.getReadableObjectFields(objectType);
	}

	/*******************************************************************************************************
	* @description the preference options for the editor, in display order
	* @return List<preferenceOption>
	*/
	@auraEnabled(cacheable=true)
	public static List<preferenceOption> getPreferences() {
		return new List<preferenceOption>{
			new preferenceOption(MRG_KeepRecordRule.PREFER_HAS_VALUE, 'has a value'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_IS_BLANK, 'is blank'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_IS_TRUE, 'is checked (true)'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_IS_FALSE, 'is unchecked (false)'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_OLDEST, 'is the oldest (earliest date)'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_NEWEST, 'is the newest (latest date)'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_LARGEST, 'is the largest'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_SMALLEST, 'is the smallest'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_LONGEST, 'is the longest text'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_SHORTEST, 'is the shortest text'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_EQUALS, 'equals'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_NOT_EQUALS, 'does not equal'),
			new preferenceOption(MRG_KeepRecordRule.PREFER_CONTAINS, 'contains')
		};
	}

	/*******************************************************************************************************
	* @description the condition operator options used by the auto-merge-accounts editor
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
	* @description saves the keep-record rules of an object in the order supplied by the UI. Every rule
	* is validated first so an incomplete rule is rejected with a clear message and nothing is deployed.
	* @param objectType the SObject api name
	* @param jsonData a JSON array of MRG_KeepRecordRule in evaluation order
	* @return String the metadata deploy job id
	*/
	@auraEnabled
	public static String saveKeepRecordRules(String objectType, String jsonData) {
		if(String.isBlank(objectType))
			throw new AuraHandledException('Choose an object before saving.');
		List<MRG_KeepRecordRule> rules = String.isBlank(jsonData)
			? new List<MRG_KeepRecordRule>()
			: (List<MRG_KeepRecordRule>) JSON.deserialize(jsonData, List<MRG_KeepRecordRule>.class);
		Integer position = 1;
		for(MRG_KeepRecordRule rule:rules) {
			if(String.isBlank(rule.fieldName))
				throw new AuraHandledException('Rule ' + position + ': choose a field.');
			if(rule.preference == null || !MRG_KeepRecordRule.PREFERENCES.contains(rule.preference))
				throw new AuraHandledException('Rule ' + position + ': choose a preference.');
			if(MRG_KeepRecordRule.VALUE_PREFERENCES.contains(rule.preference) && String.isBlank(rule.value))
				throw new AuraHandledException('Rule ' + position + ': enter the value to compare with.');
			position++;
		}
		return MRG_KeepRecordRule.saveKeepRecordRules(objectType, rules);
	}

	/*******************************************************************************************************
	* @description a preference option for the UI
	*/
	public class preferenceOption {
		@auraEnabled public String value;
		@auraEnabled public String label;
		@auraEnabled public Boolean needsValue;
		public preferenceOption(String value, String label) {
			this.value = value;
			this.label = label;
			this.needsValue = MRG_KeepRecordRule.VALUE_PREFERENCES.contains(value);
		}
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
