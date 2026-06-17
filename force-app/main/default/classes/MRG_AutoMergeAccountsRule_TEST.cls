/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the auto-merge-accounts rule model: cross-record aggregator evaluation and
* load/save
*/
@isTest
private class MRG_AutoMergeAccountsRule_TEST {

	private static MRG_KeepRecordRule.condition cond(String field, String op, String val, String agg) {
		MRG_KeepRecordRule.condition c = new MRG_KeepRecordRule.condition(field, op, val);
		c.aggregator = agg;
		return c;
	}

	private static List<Contact> twoContacts(String emailA, Boolean optA, String emailB, Boolean optB) {
		return new List<Contact>{
			new Contact(LastName='A', Email=emailA, HasOptedOutOfEmail=optA),
			new Contact(LastName='B', Email=emailB, HasOptedOutOfEmail=optB)
		};
	}

	static testMethod void testAggregatorAll() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','false','all') };
		// all not opted out -> matches
		system.assert(rule.matches(twoContacts('a@x.com', false, 'b@x.com', false)), 'all=false satisfies');
		// one opted out -> all fails
		system.assert(!rule.matches(twoContacts('a@x.com', false, 'b@x.com', true)), 'one true breaks all=false');
	}

	static testMethod void testAggregatorAny() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','true','any') };
		system.assert(rule.matches(twoContacts('a@x.com', false, 'b@x.com', true)), 'any opted out satisfies');
		system.assert(!rule.matches(twoContacts('a@x.com', false, 'b@x.com', false)), 'none opted out -> any fails');
	}

	static testMethod void testAggregatorDiffer() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('Email', null, null, 'differ') };
		system.assert(rule.matches(twoContacts('a@x.com', false, 'b@x.com', false)), 'different emails -> differ true');
		system.assert(!rule.matches(twoContacts('same@x.com', false, 'same@x.com', false)), 'same emails -> differ false');
	}

	static testMethod void testAggregatorSame() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.filterLogic = '1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('Email', null, null, 'same') };
		system.assert(rule.matches(twoContacts('same@x.com', false, 'same@x.com', false)), 'same emails -> same true');
		system.assert(!rule.matches(twoContacts('a@x.com', false, 'b@x.com', false)), 'different emails -> same false');
	}

	static testMethod void testTicketExample() {
		// emails differ AND both not opted out
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.filterLogic = '1 AND 2';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			cond('Email', null, null, 'differ'),
			cond('HasOptedOutOfEmail','equals','false','all')
		};
		system.assert(rule.matches(twoContacts('a@x.com', false, 'b@x.com', false)), 'emails differ + both not opted out');
		system.assert(!rule.matches(twoContacts('a@x.com', false, 'b@x.com', true)), 'one opted out fails');
		system.assert(!rule.matches(twoContacts('same@x.com', false, 'same@x.com', false)), 'same email fails');
	}

	static testMethod void testDefaultAggregatorIsAll() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.filterLogic = '1';
		// no aggregator -> defaults to all
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('HasOptedOutOfEmail','equals','false', null) };
		system.assert(rule.matches(twoContacts('a@x.com', false, 'b@x.com', false)));
		system.assert(!rule.matches(twoContacts('a@x.com', false, 'b@x.com', true)));
	}

	static testMethod void testReferencedFields() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			cond('Email', null, null, 'differ'),
			cond('HasOptedOutOfEmail','equals','false','all')
		};
		Set<String> f = rule.referencedFields();
		system.assert(f.contains('Email') && f.contains('HasOptedOutOfEmail'));
	}

	// ---- persistence ----

	private static AutoMergeAccountsRule__mdt buildSetting(String objectName, Boolean autoMerge, String conditionsJson) {
		AutoMergeAccountsRule__mdt s = new AutoMergeAccountsRule__mdt();
		Map<String, Object> m = (Map<String, Object>) JSON.deserializeUntyped(JSON.serialize(s));
		m.put(AutoMergeAccountsRule__mdt.Label.getDescribe().getName(), objectName+' ama');
		m.put(AutoMergeAccountsRule__mdt.DeveloperName.getDescribe().getName(), objectName+'Ama');
		m.put(AutoMergeAccountsRule__mdt.FilterLogic__c.getDescribe().getName(), '1 AND 2');
		m.put(AutoMergeAccountsRule__mdt.AutoMerge__c.getDescribe().getName(), autoMerge);
		m.put(AutoMergeAccountsRule__mdt.Conditions__c.getDescribe().getName(), conditionsJson);
		m.put('Object__r', new Map<String, Object>{ 'attributes' => new Map<String, Object>{ 'type' => 'EntityDefinition' }, 'QualifiedAPIName' => objectName });
		return (AutoMergeAccountsRule__mdt) JSON.deserialize(JSON.serialize(m), AutoMergeAccountsRule__mdt.class);
	}

	static testMethod void testConstructorAndGetRules() {
		String condJson = JSON.serialize(new List<MRG_KeepRecordRule.condition>{
			cond('Email', null, null, 'differ')
		});
		MRG_AutoMergeAccountsRule.autoMergeAccountsRules = new List<MRG_AutoMergeAccountsRule>{
			new MRG_AutoMergeAccountsRule(buildSetting('Contact', true, condJson)),
			new MRG_AutoMergeAccountsRule(buildSetting('Account', false, null))
		};
		List<MRG_AutoMergeAccountsRule> contactRules = MRG_AutoMergeAccountsRule.getRules('Contact');
		system.assertEquals(1, contactRules.size());
		system.assertEquals(true, contactRules[0].autoMerge);
		system.assertEquals(1, contactRules[0].conditions.size());
		system.assertEquals('differ', contactRules[0].conditions[0].aggregator);
		system.assertEquals(0, MRG_AutoMergeAccountsRule.getRules('Lead').size());
	}

	static testMethod void testToSettingRoundTrip() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.objectName = 'Contact';
		rule.label = 'Diff Email';
		rule.autoMerge = true;
		rule.filterLogic = '1 AND 2';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			cond('Email', null, null, 'differ'),
			cond('HasOptedOutOfEmail','equals','false','all')
		};
		AutoMergeAccountsRule__mdt setting = MRG_AutoMergeAccountsRule.toSetting(rule);
		system.assertEquals('Contact', setting.Object__r.QualifiedAPIName);
		system.assertEquals(true, setting.AutoMerge__c);
		system.assert(setting.Conditions__c.contains('differ'));
		MRG_AutoMergeAccountsRule rt = new MRG_AutoMergeAccountsRule(setting);
		system.assertEquals(2, rt.conditions.size());
	}

	static testMethod void testToSettingDeveloperNameWithinLimit() {
		// the default UI label is "<Object> Auto Merge Accounts <n>"; the generated DeveloperName must
		// stay within the 40-char custom metadata limit, start with a letter, and be alphanumeric, or
		// the metadata deploy fails (and the failure is not surfaced to the user)
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.objectName = 'Account';
		rule.label = 'Account Auto Merge Accounts 1';
		AutoMergeAccountsRule__mdt setting = MRG_AutoMergeAccountsRule.toSetting(rule);
		String devName = setting.QualifiedAPIName;
		system.assert(devName.length() <= 40, 'DeveloperName must be <= 40 chars, was ' + devName.length() + ': ' + devName);
		system.assert(devName.substring(0,1).isAlpha(), 'DeveloperName must start with a letter: ' + devName);
		system.assert(devName.isAlphanumeric(), 'DeveloperName must be alphanumeric: ' + devName);
	}

	static testMethod void testToSettingDeveloperNameFallbackAndLeadingDigit() {
		// blank label falls back to an object-based name; a numeric-leading label is prefixed so the
		// DeveloperName still starts with a letter
		MRG_AutoMergeAccountsRule blank = new MRG_AutoMergeAccountsRule();
		blank.objectName = 'Contact';
		blank.label = '   ';
		system.assert(MRG_AutoMergeAccountsRule.toSetting(blank).QualifiedAPIName.isAlphanumeric(), 'fallback name must be valid');

		MRG_AutoMergeAccountsRule numeric = new MRG_AutoMergeAccountsRule();
		numeric.objectName = 'Contact';
		numeric.label = '123 rule';
		String devName = MRG_AutoMergeAccountsRule.toSetting(numeric).QualifiedAPIName;
		system.assert(devName.substring(0,1).isAlpha(), 'leading digit must be prefixed: ' + devName);
	}

	static testMethod void testSaveRules() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.objectName = 'Contact';
		rule.label = 'R1';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ cond('Email', null, null, 'differ') };
		Test.startTest();
		String jobId = MRG_AutoMergeAccountsRule.saveRules(new List<MRG_AutoMergeAccountsRule>{ rule });
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId);
	}
}
