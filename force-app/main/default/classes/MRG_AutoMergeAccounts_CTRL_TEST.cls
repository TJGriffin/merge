/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the Auto-Merge Accounts Rules controller
*/
@isTest
private class MRG_AutoMergeAccounts_CTRL_TEST {

	static testMethod void testGetRules() {
		system.assertEquals(0, MRG_AutoMergeAccounts_CTRL.getRules('').size(), 'blank -> empty');
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.objectName = 'Contact';
		MRG_AutoMergeAccountsRule.autoMergeAccountsRules = new List<MRG_AutoMergeAccountsRule>{ rule };
		system.assertEquals(1, MRG_AutoMergeAccounts_CTRL.getRules('Contact').size());
		system.assertEquals(0, MRG_AutoMergeAccounts_CTRL.getRules('Account').size());
	}

	static testMethod void testFieldOperatorAggregatorOptions() {
		system.assert(MRG_AutoMergeAccounts_CTRL.getObjectFields('Contact').size() > 0);
		system.assertEquals(0, MRG_AutoMergeAccounts_CTRL.getObjectFields('').size());
		system.assert(MRG_AutoMergeAccounts_CTRL.getOperators().size() >= 9);
		Set<String> aggs = new Set<String>();
		for(MRG_KeepRecordRules_CTRL.operatorOption o:MRG_AutoMergeAccounts_CTRL.getAggregators())
			aggs.add(o.value);
		system.assert(aggs.containsAll(new Set<String>{'all','any','differ','same'}), 'all aggregators offered');
	}

	static testMethod void testSaveValid() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.objectName = 'Contact';
		rule.label = 'r';
		rule.autoMerge = true;
		rule.filterLogic = '1 AND 2';
		MRG_KeepRecordRule.condition c1 = new MRG_KeepRecordRule.condition('Email', null, null);
		c1.aggregator = 'differ';
		MRG_KeepRecordRule.condition c2 = new MRG_KeepRecordRule.condition('HasOptedOutOfEmail','equals','false');
		c2.aggregator = 'all';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ c1, c2 };

		Test.startTest();
		String jobId = MRG_AutoMergeAccounts_CTRL.saveRules(JSON.serialize(new List<MRG_AutoMergeAccountsRule>{ rule }));
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId);
	}

	static testMethod void testSaveInvalidLogicThrows() {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.objectName = 'Contact';
		rule.label = 'bad';
		rule.filterLogic = '1 AND 9';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ new MRG_KeepRecordRule.condition('Email','equals','x') };
		Boolean threw = false;
		try {
			MRG_AutoMergeAccounts_CTRL.saveRules(JSON.serialize(new List<MRG_AutoMergeAccountsRule>{ rule }));
		} catch(AuraHandledException e) {
			threw = true;
		}
		system.assert(threw, 'invalid filter logic should throw');
	}
}
