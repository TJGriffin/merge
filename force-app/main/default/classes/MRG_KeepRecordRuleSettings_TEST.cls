/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for loading and saving keep-record rules from/to KeepRecordRuleSettings__mdt
*/
@isTest
private class MRG_KeepRecordRuleSettings_TEST {

	/*******************************************************************************************************
	* @description builds an in-memory KeepRecordRuleSettings__mdt with the read-only Object__r
	* relationship populated via JSON injection
	*/
	private static KeepRecordRuleSettings__mdt buildSetting(String objectName, Integer order, String field, String preference, String value, Boolean active) {
		KeepRecordRuleSettings__mdt setting = new KeepRecordRuleSettings__mdt();
		Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(setting));
		fieldMap.put(KeepRecordRuleSettings__mdt.Label.getDescribe().getName(), objectName+' rule '+order);
		fieldMap.put(KeepRecordRuleSettings__mdt.DeveloperName.getDescribe().getName(), objectName+'Rule'+order);
		fieldMap.put(KeepRecordRuleSettings__mdt.Order__c.getDescribe().getName(), order);
		fieldMap.put(KeepRecordRuleSettings__mdt.Field__c.getDescribe().getName(), field);
		fieldMap.put(KeepRecordRuleSettings__mdt.Preference__c.getDescribe().getName(), preference);
		fieldMap.put(KeepRecordRuleSettings__mdt.Value__c.getDescribe().getName(), value);
		fieldMap.put(KeepRecordRuleSettings__mdt.Active__c.getDescribe().getName(), active);
		fieldMap.put('Object__r', new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' },
			'QualifiedAPIName' => objectName
		});
		return (KeepRecordRuleSettings__mdt) JSON.deserialize(JSON.serialize(fieldMap), KeepRecordRuleSettings__mdt.class);
	}

	private static MRG_KeepRecordRule rule(String objectName, Integer order, String field, String preference, String value) {
		MRG_KeepRecordRule r = new MRG_KeepRecordRule();
		r.objectName = objectName; r.order = order; r.fieldName = field; r.preference = preference; r.value = value;
		return r;
	}

	static testMethod void testConstructorParsesSetting() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule(buildSetting('Account', 2, 'Type', 'Equals', 'Customer', true));
		system.assertEquals('Account', rule.objectName);
		system.assertEquals(2, rule.order);
		system.assertEquals('Type', rule.fieldName);
		system.assertEquals('Equals', rule.preference);
		system.assertEquals('Customer', rule.value);
		system.assertEquals(true, rule.active);
		system.assertEquals(true, rule.isValid());
	}

	static testMethod void testConstructorReadsActiveFlag() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule(buildSetting('Account', 1, 'Site', 'HasValue', null, true));
		system.assertEquals(true, rule.active);
		MRG_KeepRecordRule inactive = new MRG_KeepRecordRule(buildSetting('Account', 1, 'Site', 'HasValue', null, false));
		system.assertEquals(false, inactive.active, 'a retired rule is inactive');
		MRG_KeepRecordRule legacy = new MRG_KeepRecordRule(buildSetting('Account', 1, null, null, null, true));
		system.assertEquals(false, legacy.isValid(), 'a condition-based record from the previous editor has no preference and is ignored');
	}

	static testMethod void testGetRulesFiltersAndSorts() {
		MRG_KeepRecordRule contactRule2 = rule('Contact', 2, 'Email', 'HasValue', null);
		MRG_KeepRecordRule contactRule1 = rule('Contact', 1, 'CreatedDate', 'Oldest', null);
		MRG_KeepRecordRule accountRule = rule('Account', 1, 'Site', 'HasValue', null);
		MRG_KeepRecordRule inactive = rule('Contact', 3, 'Phone', 'HasValue', null);
		inactive.active = false;
		MRG_KeepRecordRule legacy = rule('Contact', 4, null, null, null);
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ contactRule2, accountRule, contactRule1, inactive, legacy };

		List<MRG_KeepRecordRule> contactRules = MRG_KeepRecordRule.getRules('Contact');
		system.assertEquals(2, contactRules.size(), 'only active, valid contact rules returned');
		system.assertEquals(1, contactRules[0].order, 'sorted by order ascending');
		system.assertEquals(2, contactRules[1].order);
		system.assertEquals(1, MRG_KeepRecordRule.getRules('account').size(), 'object match ignores case');
		system.assertEquals(0, MRG_KeepRecordRule.getRules('Lead').size());
	}

	static testMethod void testToSettingAndDeveloperName() {
		MRG_KeepRecordRule r = rule('Account', 1, 'Relationship_Manager__c', 'HasValue', 'ignored');
		KeepRecordRuleSettings__mdt setting = MRG_KeepRecordRule.toSetting(r);
		system.assertEquals('Account', setting.Object__r.QualifiedAPIName, 'object relationship injected');
		system.assertEquals(1, setting.Order__c);
		system.assertEquals('Relationship_Manager__c', setting.Field__c);
		system.assertEquals('HasValue', setting.Preference__c);
		system.assertEquals(null, setting.Value__c, 'the value is dropped for preferences that do not use it');
		system.assertEquals(true, setting.Active__c);
		system.assertEquals('AccountKeepRule1', setting.QualifiedAPIName);
		system.assert(setting.Label.length() <= 40, 'labels fit the 40 character limit');
		system.assertEquals('npspAddresscKeepRule3', MRG_KeepRecordRule.developerName('npsp__Address__c', 3));

		MRG_KeepRecordRule withValue = rule('Contact', 2, 'MailingState', 'Equals', 'TX');
		withValue.label = 'Texans first';
		withValue.id = 'm00000000000001AAA';
		KeepRecordRuleSettings__mdt s2 = MRG_KeepRecordRule.toSetting(withValue);
		system.assertEquals('TX', s2.Value__c);
		system.assertEquals('Texans first', s2.Label);
		system.assertEquals('m00000000000001AAA', s2.Id);
		MRG_KeepRecordRule roundTrip = new MRG_KeepRecordRule(s2);
		system.assertEquals('MailingState', roundTrip.fieldName);
		system.assertEquals('Equals', roundTrip.preference);
	}

	static testMethod void testSaveRenumbersAndRetiresExtraRules() {
		// three stored Account rules; the UI saves two (second one moved to the front)
		MRG_KeepRecordRule stored1 = rule('Account', 1, 'Site', 'HasValue', null);
		MRG_KeepRecordRule stored2 = rule('Account', 2, 'CreatedDate', 'Oldest', null);
		MRG_KeepRecordRule stored3 = rule('Account', 3, 'Type', 'Equals', 'Customer');
		MRG_KeepRecordRule otherObject = rule('Contact', 3, 'Email', 'HasValue', null);
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ stored1, stored2, stored3, otherObject };

		MRG_KeepRecordRule first = rule('Account', 2, 'CreatedDate', 'Oldest', null);
		MRG_KeepRecordRule second = rule('Account', 1, 'Site', 'HasValue', null);
		second.id = 'm00000000000001AAA';
		Test.startTest();
		String jobId = MRG_KeepRecordRule.saveKeepRecordRules('Account', new List<MRG_KeepRecordRule>{ first, second });
		Test.stopTest();

		system.assertEquals('Test Job Id', jobId, 'in test context the metadata service returns a stub job id');
		system.assertEquals(1, first.order, 'renumbered by position');
		system.assertEquals(2, second.order);
		system.assertEquals(null, second.id, 'developer names follow the position, so stored ids are not reused');
		system.assertEquals(true, second.active);
	}

	static testMethod void testSaveEmptyListRetiresEverything() {
		MRG_KeepRecordRule stored1 = rule('Account', 1, 'Site', 'HasValue', null);
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ stored1 };
		Test.startTest();
		String jobId = MRG_KeepRecordRule.saveKeepRecordRules('Account', new List<MRG_KeepRecordRule>());
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId, 'the stored rule is deployed as inactive');
	}

	static testMethod void testSaveNothingStoredNothingToSave() {
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>();
		system.assertEquals(null, MRG_KeepRecordRule.saveKeepRecordRules('Account', null), 'no metadata records -> no deploy');
	}
}
