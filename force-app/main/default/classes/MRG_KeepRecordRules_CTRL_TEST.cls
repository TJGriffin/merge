/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the Keep Record Rules tab controller
*/
@isTest
private class MRG_KeepRecordRules_CTRL_TEST {

	private static MRG_KeepRecordRule rule(String objectName, Integer order, String field, String preference, String value) {
		MRG_KeepRecordRule r = new MRG_KeepRecordRule();
		r.objectName = objectName; r.order = order; r.fieldName = field; r.preference = preference; r.value = value;
		return r;
	}

	static testMethod void testGetKeepRecordRules() {
		system.assertEquals(0, MRG_KeepRecordRules_CTRL.getKeepRecordRules('').size(), 'blank object -> empty');
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ rule('Contact', 1, 'Email', 'HasValue', null) };
		system.assertEquals(1, MRG_KeepRecordRules_CTRL.getKeepRecordRules('Contact').size());
		system.assertEquals(0, MRG_KeepRecordRules_CTRL.getKeepRecordRules('Account').size());
	}

	static testMethod void testGetPreferences() {
		List<MRG_KeepRecordRules_CTRL.preferenceOption> prefs = MRG_KeepRecordRules_CTRL.getPreferences();
		system.assertEquals(MRG_KeepRecordRule.PREFERENCES.size(), prefs.size(), 'one option per preference');
		Map<String, MRG_KeepRecordRules_CTRL.preferenceOption> byValue = new Map<String, MRG_KeepRecordRules_CTRL.preferenceOption>();
		for(MRG_KeepRecordRules_CTRL.preferenceOption p:prefs) byValue.put(p.value, p);
		system.assertEquals(true, byValue.get('Equals').needsValue);
		system.assertEquals(true, byValue.get('Contains').needsValue);
		system.assertEquals(false, byValue.get('HasValue').needsValue);
		system.assertEquals(false, byValue.get('Oldest').needsValue);
		system.assertEquals('has a value', byValue.get('HasValue').label);
	}

	static testMethod void testGetOperatorsStillServesAutoMergeEditor() {
		List<MRG_KeepRecordRules_CTRL.operatorOption> ops = MRG_KeepRecordRules_CTRL.getOperators();
		system.assert(ops.size() >= 9, 'all operators returned');
		Set<String> values = new Set<String>();
		for(MRG_KeepRecordRules_CTRL.operatorOption o:ops) values.add(o.value);
		system.assert(values.contains('equals') && values.contains('greaterThan') && values.contains('contains'));
	}

	static testMethod void testGetObjectFields() {
		List<MRG_Merge_SVC.objectField> fields = MRG_KeepRecordRules_CTRL.getObjectFields('Account');
		system.assert(fields.size() > 0, 'account has readable fields');
		Set<String> names = new Set<String>();
		for(MRG_Merge_SVC.objectField f:fields) names.add(f.name);
		system.assert(names.contains('CreatedDate'), 'read-only system fields are offered (the oldest-record preference needs them)');
		system.assertEquals(0, MRG_KeepRecordRules_CTRL.getObjectFields('').size(), 'blank object -> empty');
	}

	static testMethod void testSaveValid() {
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>();
		List<MRG_KeepRecordRule> rules = new List<MRG_KeepRecordRule>{
			rule('Account', 1, 'Site', 'HasValue', null),
			rule('Account', 2, 'CreatedDate', 'Oldest', null),
			rule('Account', 3, 'Type', 'Equals', 'Customer')
		};
		Test.startTest();
		String jobId = MRG_KeepRecordRules_CTRL.saveKeepRecordRules('Account', JSON.serialize(rules));
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId, 'valid rules deploy (stub job id in test context)');
	}

	static testMethod void testSaveRejectsIncompleteRules() {
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>();
		assertRejected('', JSON.serialize(new List<MRG_KeepRecordRule>()), 'object');
		assertRejected('Account', JSON.serialize(new List<MRG_KeepRecordRule>{ rule('Account', 1, null, 'HasValue', null) }), 'field');
		assertRejected('Account', JSON.serialize(new List<MRG_KeepRecordRule>{ rule('Account', 1, 'Site', 'Nope', null) }), 'preference');
		assertRejected('Account', JSON.serialize(new List<MRG_KeepRecordRule>{ rule('Account', 1, 'Site', 'Equals', ' ') }), 'value');
	}

	static testMethod void testSaveEmptyRetiresStoredRules() {
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ rule('Account', 1, 'Site', 'HasValue', null) };
		Test.startTest();
		String jobId = MRG_KeepRecordRules_CTRL.saveKeepRecordRules('Account', '');
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId, 'clearing the list deploys the stored rule as inactive');
	}

	private static void assertRejected(String objectType, String jsonData, String what) {
		Boolean threw = false;
		try {
			MRG_KeepRecordRules_CTRL.saveKeepRecordRules(objectType, jsonData);
		} catch(AuraHandledException e) {
			threw = true;
		}
		system.assert(threw, 'a rule without a ' + what + ' is rejected');
	}
}
