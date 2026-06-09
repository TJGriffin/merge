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
	private static KeepRecordRuleSettings__mdt buildSetting(String objectName, Integer order, String filterLogic, String conditionsJson) {
		KeepRecordRuleSettings__mdt setting = new KeepRecordRuleSettings__mdt();
		Map<String, Object> fieldMap = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(setting));
		fieldMap.put(KeepRecordRuleSettings__mdt.Label.getDescribe().getName(), objectName+' rule '+order);
		fieldMap.put(KeepRecordRuleSettings__mdt.DeveloperName.getDescribe().getName(), objectName+'Rule'+order);
		fieldMap.put(KeepRecordRuleSettings__mdt.Order__c.getDescribe().getName(), order);
		fieldMap.put(KeepRecordRuleSettings__mdt.FilterLogic__c.getDescribe().getName(), filterLogic);
		fieldMap.put(KeepRecordRuleSettings__mdt.Conditions__c.getDescribe().getName(), conditionsJson);
		fieldMap.put('Object__r', new Map<String, Object>{
			'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' },
			'QualifiedAPIName' => objectName
		});
		return (KeepRecordRuleSettings__mdt) JSON.deserialize(JSON.serialize(fieldMap), KeepRecordRuleSettings__mdt.class);
	}

	static testMethod void testConstructorParsesSetting() {
		String conditions = JSON.serialize(new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('MailingState','equals','TX'),
			new MRG_KeepRecordRule.condition('HasOptedOutOfEmail','equals','true')
		});
		KeepRecordRuleSettings__mdt setting = buildSetting('Contact', 2, '1 OR 2', conditions);

		MRG_KeepRecordRule rule = new MRG_KeepRecordRule(setting);
		system.assertEquals('Contact', rule.objectName);
		system.assertEquals(2, rule.order);
		system.assertEquals('1 OR 2', rule.filterLogic);
		system.assertEquals(2, rule.conditions.size());
		system.assertEquals('MailingState', rule.conditions[0].fieldName);
		system.assertEquals('true', rule.conditions[1].value);
	}

	static testMethod void testConstructorHandlesBlankConditions() {
		KeepRecordRuleSettings__mdt setting = buildSetting('Account', 1, null, null);
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule(setting);
		system.assertEquals(0, rule.conditions.size(), 'blank conditions -> empty list, not null');
	}

	static testMethod void testGetRulesFiltersAndSorts() {
		// inject rules directly via the property setter
		MRG_KeepRecordRule contactRule2 = new MRG_KeepRecordRule();
		contactRule2.objectName = 'Contact'; contactRule2.order = 2;
		MRG_KeepRecordRule contactRule1 = new MRG_KeepRecordRule();
		contactRule1.objectName = 'Contact'; contactRule1.order = 1;
		MRG_KeepRecordRule accountRule = new MRG_KeepRecordRule();
		accountRule.objectName = 'Account'; accountRule.order = 1;
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ contactRule2, accountRule, contactRule1 };

		List<MRG_KeepRecordRule> contactRules = MRG_KeepRecordRule.getRules('Contact');
		system.assertEquals(2, contactRules.size(), 'only contact rules returned');
		system.assertEquals(1, contactRules[0].order, 'sorted by order ascending');
		system.assertEquals(2, contactRules[1].order);

		system.assertEquals(1, MRG_KeepRecordRule.getRules('Account').size());
		system.assertEquals(0, MRG_KeepRecordRule.getRules('Lead').size());
	}

	static testMethod void testToSettingSerializesConditionsAndObject() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Contact';
		rule.order = 1;
		rule.filterLogic = '1 AND 2';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('MailingState','equals','TX')
		};

		KeepRecordRuleSettings__mdt setting = MRG_KeepRecordRule.toSetting(rule);
		system.assertEquals('Contact', setting.Object__r.QualifiedAPIName, 'object relationship injected');
		system.assertEquals(1, setting.Order__c);
		system.assertEquals('1 AND 2', setting.FilterLogic__c);
		system.assert(setting.Conditions__c.contains('MailingState'), 'conditions serialized to JSON');
		// round trip back through the constructor
		MRG_KeepRecordRule roundTrip = new MRG_KeepRecordRule(setting);
		system.assertEquals(1, roundTrip.conditions.size());
		system.assertEquals('MailingState', roundTrip.conditions[0].fieldName);
	}

	static testMethod void testSaveKeepRecordRules() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Contact';
		rule.order = 1;
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('HasOptedOutOfEmail','equals','true')
		};

		Test.startTest();
		String jobId = MRG_KeepRecordRule.saveKeepRecordRules(new List<MRG_KeepRecordRule>{ rule });
		Test.stopTest();

		// in test context the metadata service returns a stub job id rather than enqueuing a deploy
		system.assertEquals('Test Job Id', jobId);
	}
}
