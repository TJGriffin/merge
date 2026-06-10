/**
* @author tj@tjgriffin.com
* @group Merge
* @description model + group-level evaluation for an auto-merge-accounts rule (#35).
*
* Evaluated against the set of records in a merge candidate (e.g. the contacts in a Contact merge
* candidate) to decide whether, on the auto pass, their associated Accounts should be merged instead
* of merging the contacts. Conditions use a cross-record aggregator so rules can express things like
* "Email values differ" or "all records have HasOptedOutOfEmail = false", combined with report-style
* filter logic.
*/
public with sharing class MRG_AutoMergeAccountsRule {

	@auraEnabled public String id;
	@auraEnabled public String label;
	@auraEnabled public String objectName;
	@auraEnabled public String filterLogic;
	@auraEnabled public Boolean autoMerge;     // when true, the auto pass merges accounts for matches
	@auraEnabled public List<MRG_KeepRecordRule.condition> conditions;

	public MRG_AutoMergeAccountsRule() {
		this.conditions = new List<MRG_KeepRecordRule.condition>();
		this.autoMerge = false;
	}

	public MRG_AutoMergeAccountsRule(AutoMergeAccountsRule__mdt setting) {
		this.id = setting.Id;
		this.label = setting.Label;
		this.objectName = setting.Object__r != null ? setting.Object__r.QualifiedAPIName : null;
		this.filterLogic = setting.FilterLogic__c;
		this.autoMerge = setting.AutoMerge__c;
		this.conditions = String.isNotBlank(setting.Conditions__c)
			? (List<MRG_KeepRecordRule.condition>) JSON.deserialize(setting.Conditions__c, List<MRG_KeepRecordRule.condition>.class)
			: new List<MRG_KeepRecordRule.condition>();
	}

	/*******************************************************************************************************
	* @description the fields this rule reads, so the caller can ensure they are queried
	* @return Set<String>
	*/
	public Set<String> referencedFields() {
		Set<String> fields = new Set<String>();
		if(conditions != null) {
			for(MRG_KeepRecordRule.condition c:conditions) {
				if(String.isNotBlank(c.fieldName))
					fields.add(c.fieldName);
			}
		}
		return fields;
	}

	/*******************************************************************************************************
	* @description whether the candidate's records satisfy this rule. Each condition is reduced across
	* the records by its aggregator (all/any/differ/same; default all), then combined by filter logic.
	* @param records the candidate's records (e.g. the contacts in a merge candidate)
	* @return Boolean
	*/
	public Boolean matches(List<SObject> records) {
		if(conditions == null || conditions.isEmpty() || records == null || records.isEmpty())
			return false;
		Map<Integer, Boolean> results = new Map<Integer, Boolean>();
		Integer i = 1;
		for(MRG_KeepRecordRule.condition c:conditions) {
			results.put(i, evaluateAggregate(c, records));
			i++;
		}
		return MRG_FilterLogic.evaluate(filterLogic, results);
	}

	/*******************************************************************************************************
	* @description reduces a single condition across the records using its aggregator
	*/
	private Boolean evaluateAggregate(MRG_KeepRecordRule.condition c, List<SObject> records) {
		String agg = String.isBlank(c.aggregator) ? 'all' : c.aggregator.toLowerCase();
		if(agg == 'differ' || agg == 'same') {
			Set<String> distinct = new Set<String>();
			for(SObject record:records) {
				Object v = record.get(c.fieldName);
				distinct.add(v == null ? '' : String.valueOf(v));
			}
			Boolean allSame = distinct.size() <= 1;
			return agg == 'same' ? allSame : !allSame;
		}
		// all / any: per-record condition evaluation
		Boolean anyTrue = false;
		Boolean allTrue = true;
		for(SObject record:records) {
			Boolean r = c.evaluate(record);
			anyTrue = anyTrue || r;
			allTrue = allTrue && r;
		}
		return agg == 'any' ? anyTrue : allTrue;
	}

	/*******************************************************************************************************
	* @description all configured auto-merge-accounts rules, lazily queried from custom metadata
	*/
	public static List<MRG_AutoMergeAccountsRule> autoMergeAccountsRules {
		get {
			if(autoMergeAccountsRules == null) {
				List<MRG_AutoMergeAccountsRule> rules = new List<MRG_AutoMergeAccountsRule>();
				for(AutoMergeAccountsRule__mdt setting:[
					SELECT Id, Label, QualifiedAPIName, Object__c, Object__r.QualifiedAPIName,
						FilterLogic__c, AutoMerge__c, Conditions__c
					FROM AutoMergeAccountsRule__mdt
				]) {
					rules.add(new MRG_AutoMergeAccountsRule(setting));
				}
				autoMergeAccountsRules = rules;
			}
			return autoMergeAccountsRules;
		}
		set;
	}

	/*******************************************************************************************************
	* @description the rules for a single object
	* @param objectType the SObject api name (the candidate's object, e.g. Contact)
	* @return List<MRG_AutoMergeAccountsRule>
	*/
	public static List<MRG_AutoMergeAccountsRule> getRules(String objectType) {
		List<MRG_AutoMergeAccountsRule> rules = new List<MRG_AutoMergeAccountsRule>();
		for(MRG_AutoMergeAccountsRule rule:autoMergeAccountsRules) {
			if(String.isNotBlank(rule.objectName) && rule.objectName.equalsIgnoreCase(objectType))
				rules.add(rule);
		}
		return rules;
	}

	/*******************************************************************************************************
	* @description saves a list of rules via the Metadata API
	* @param rules the rules to save
	* @return String the metadata deploy job id
	*/
	public static String saveRules(List<MRG_AutoMergeAccountsRule> rules) {
		MRG_Metadata_SVC mdService = new MRG_Metadata_SVC();
		List<Metadata.CustomMetadata> mdRecords = new List<Metadata.CustomMetadata>();
		for(MRG_AutoMergeAccountsRule rule:rules) {
			mdRecords.add(mdService.getMetaDataRecord(toSetting(rule)));
		}
		return mdService.deployMetadataRecords(mdRecords);
	}

	/*******************************************************************************************************
	* @description converts a rule wrapper into an AutoMergeAccountsRule__mdt with the read-only
	* Object__r relationship injected and conditions serialized
	* @param rule the rule wrapper
	* @return AutoMergeAccountsRule__mdt
	*/
	public static AutoMergeAccountsRule__mdt toSetting(MRG_AutoMergeAccountsRule rule) {
		AutoMergeAccountsRule__mdt setting = new AutoMergeAccountsRule__mdt(
			Label = String.isNotBlank(rule.label) ? rule.label : (rule.objectName + ' Auto Merge Accounts'),
			FilterLogic__c = rule.filterLogic,
			AutoMerge__c = rule.autoMerge == true,
			Conditions__c = rule.conditions != null && !rule.conditions.isEmpty() ? JSON.serialize(rule.conditions) : null
		);
		String devName = (rule.objectName == null ? 'Obj' : rule.objectName.replace('__','').replace('_','')) + 'AutoMergeAccounts'
			+ (String.isNotBlank(rule.label) ? rule.label.replaceAll('[^a-zA-Z0-9]','') : '');
		setting.QualifiedAPIName = devName;
		Map<String, Object> settingJSON = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(setting));
		settingJSON.put('Object__r', new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' },
			'QualifiedAPIName' => rule.objectName
		});
		if(String.isNotBlank(rule.id))
			settingJSON.put('Id', rule.id);
		return (AutoMergeAccountsRule__mdt) JSON.deserialize(JSON.serialize(settingJSON), AutoMergeAccountsRule__mdt.class);
	}
}
