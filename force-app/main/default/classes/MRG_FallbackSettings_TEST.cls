/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for loading/saving fallback rules from/to FallbackRuleSettings__mdt
*/
@isTest
private class MRG_FallbackSettings_TEST {

	private static FallbackRuleSettings__mdt buildSetting(String objectName, String selectionType, String fieldPairsJson, String tieBreakField) {
		FallbackRuleSettings__mdt s = new FallbackRuleSettings__mdt();
		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(s));
		m.put(FallbackRuleSettings__mdt.Label.getDescribe().getName(), objectName+' fallback');
		m.put(FallbackRuleSettings__mdt.DeveloperName.getDescribe().getName(), objectName+'Fallback');
		m.put(FallbackRuleSettings__mdt.SelectionType__c.getDescribe().getName(), selectionType);
		m.put(FallbackRuleSettings__mdt.Rule__c.getDescribe().getName(), 'Newest');
		m.put(FallbackRuleSettings__mdt.TieBreakDirection__c.getDescribe().getName(), 'DESC');
		m.put(FallbackRuleSettings__mdt.FieldPairs__c.getDescribe().getName(), fieldPairsJson);
		m.put('Object__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' }, 'QualifiedAPIName' => objectName });
		if(String.isNotBlank(tieBreakField))
			m.put('TieBreakField__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityParticle' }, 'QualifiedAPIName' => tieBreakField });
		return (FallbackRuleSettings__mdt) JSON.deserialize(JSON.serialize(m), FallbackRuleSettings__mdt.class);
	}

	private static String pairsJson() {
		return JSON.serialize(new List<MRG_FallbackRule.fieldPair>{
			new MRG_FallbackRule.fieldPair('Email','Description'),
			new MRG_FallbackRule.fieldPair('MailingState','OtherCity')
		});
	}

	static testMethod void testConstructorParsesSetting() {
		FallbackRuleSettings__mdt setting = buildSetting('Contact', 'complex', pairsJson(), 'Birthdate');
		MRG_FallbackRule rule = new MRG_FallbackRule(setting);
		system.assertEquals('Contact', rule.objectName);
		system.assertEquals('complex', rule.selectionType);
		system.assertEquals('Birthdate', rule.tieBreakField);
		system.assertEquals('DESC', rule.tieBreakDirection);
		system.assertEquals(2, rule.fieldPairs.size());
		system.assertEquals('Email', rule.fieldPairs[0].sourceField);
		system.assertEquals('OtherCity', rule.fieldPairs[1].targetField);
	}

	static testMethod void testConstructorHandlesBlankCollections() {
		FallbackRuleSettings__mdt setting = buildSetting('Account', 'simple', null, null);
		MRG_FallbackRule rule = new MRG_FallbackRule(setting);
		system.assertEquals(0, rule.fieldPairs.size());
		system.assertEquals(0, rule.conditions.size());
		system.assertEquals('simple', rule.selectionType);
	}

	static testMethod void testGetRulesFiltersByObject() {
		MRG_FallbackRule c = new MRG_FallbackRule(); c.objectName = 'Contact';
		MRG_FallbackRule a = new MRG_FallbackRule(); a.objectName = 'Account';
		MRG_FallbackRule.fallbackRules = new List<MRG_FallbackRule>{ c, a };
		system.assertEquals(1, MRG_FallbackRule.getRules('Contact').size());
		system.assertEquals(1, MRG_FallbackRule.getRules('Account').size());
		system.assertEquals(0, MRG_FallbackRule.getRules('Lead').size());
	}

	static testMethod void testToSettingRoundTrip() {
		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.objectName = 'Contact';
		rule.label = 'Email Fallback';
		rule.selectionType = 'complex';
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ new MRG_KeepRecordRule.condition('HasOptedOutOfEmail','equals','true') };
		rule.tieBreakField = 'Birthdate';
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };

		FallbackRuleSettings__mdt setting = MRG_FallbackRule.toSetting(rule);
		system.assertEquals('Contact', setting.Object__r.QualifiedAPIName);
		system.assertEquals('complex', setting.SelectionType__c);
		system.assertEquals('Birthdate', setting.TieBreakField__r.QualifiedAPIName);
		system.assert(setting.FieldPairs__c.contains('Email'));
		system.assert(setting.Conditions__c.contains('HasOptedOutOfEmail'));

		MRG_FallbackRule roundTrip = new MRG_FallbackRule(setting);
		system.assertEquals(1, roundTrip.fieldPairs.size());
		system.assertEquals('Email', roundTrip.fieldPairs[0].sourceField);
		system.assertEquals(1, roundTrip.conditions.size());
	}

	static testMethod void testSaveFallbackRules() {
		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.objectName = 'Contact';
		rule.label = 'F1';
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };
		Test.startTest();
		String jobId = MRG_FallbackRule.saveFallbackRules(new List<MRG_FallbackRule>{ rule });
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId);
	}
}
