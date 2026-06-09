/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the Keep Record Rules controller
*/
@isTest
private class MRG_KeepRecordRules_CTRL_TEST {

	static testMethod void testGetKeepRecordRules() {
		system.assertEquals(0, MRG_KeepRecordRules_CTRL.getKeepRecordRules('').size(), 'blank object -> empty');
		// inject a rule and read it back through the controller
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Contact';
		rule.order = 1;
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ rule };
		system.assertEquals(1, MRG_KeepRecordRules_CTRL.getKeepRecordRules('Contact').size());
		system.assertEquals(0, MRG_KeepRecordRules_CTRL.getKeepRecordRules('Account').size());
	}

	static testMethod void testGetOperators() {
		List<MRG_KeepRecordRules_CTRL.operatorOption> ops = MRG_KeepRecordRules_CTRL.getOperators();
		system.assert(ops.size() >= 9, 'all operators returned');
		Set<String> values = new Set<String>();
		for(MRG_KeepRecordRules_CTRL.operatorOption op:ops)
			values.add(op.value);
		system.assert(values.contains('equals') && values.contains('greaterThan') && values.contains('contains'));
	}

	static testMethod void testGetObjectFields() {
		List<MRG_Merge_SVC.objectField> fields = MRG_KeepRecordRules_CTRL.getObjectFields('Contact');
		system.assert(fields.size() > 0, 'contact has updateable fields');
		system.assertEquals(0, MRG_KeepRecordRules_CTRL.getObjectFields('').size(), 'blank object -> empty');
	}

	static testMethod void testSaveValid() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Contact';
		rule.order = 1;
		rule.label = 'r1';
		rule.filterLogic = '1 AND 2';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('MailingState','equals','TX'),
			new MRG_KeepRecordRule.condition('HasOptedOutOfEmail','equals','true')
		};

		Test.startTest();
		String jobId = MRG_KeepRecordRules_CTRL.saveKeepRecordRules(JSON.serialize(new List<MRG_KeepRecordRule>{ rule }));
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId, 'valid rules deploy (stub job id in test context)');
	}

	static testMethod void testSaveInvalidFilterLogicThrows() {
		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Contact';
		rule.order = 1;
		rule.label = 'bad';
		rule.filterLogic = '1 AND 5'; // references condition 5 with only 1 condition
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('MailingState','equals','TX')
		};

		Boolean threw = false;
		try {
			MRG_KeepRecordRules_CTRL.saveKeepRecordRules(JSON.serialize(new List<MRG_KeepRecordRule>{ rule }));
		} catch(AuraHandledException e) {
			threw = true;
		}
		system.assert(threw, 'invalid filter logic should raise an AuraHandledException');
	}
}
