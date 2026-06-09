/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for the Fallback Rules controller
*/
@isTest
private class MRG_FallbackRules_CTRL_TEST {

	static testMethod void testGetFallbackRules() {
		system.assertEquals(0, MRG_FallbackRules_CTRL.getFallbackRules('').size(), 'blank object -> empty');
		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.objectName = 'Contact';
		MRG_FallbackRule.fallbackRules = new List<MRG_FallbackRule>{ rule };
		system.assertEquals(1, MRG_FallbackRules_CTRL.getFallbackRules('Contact').size());
		system.assertEquals(0, MRG_FallbackRules_CTRL.getFallbackRules('Account').size());
	}

	static testMethod void testGetObjectFieldsAndOperators() {
		system.assert(MRG_FallbackRules_CTRL.getObjectFields('Contact').size() > 0);
		system.assertEquals(0, MRG_FallbackRules_CTRL.getObjectFields('').size());
		system.assert(MRG_FallbackRules_CTRL.getOperators().size() >= 9);
	}

	static testMethod void testSaveValidSimple() {
		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.objectName = 'Contact';
		rule.label = 'simple fb';
		rule.selectionType = 'simple';
		rule.rule = 'Newest';
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };

		Test.startTest();
		String jobId = MRG_FallbackRules_CTRL.saveFallbackRules(JSON.serialize(new List<MRG_FallbackRule>{ rule }));
		Test.stopTest();
		system.assertEquals('Test Job Id', jobId);
	}

	static testMethod void testSaveInvalidComplexLogicThrows() {
		MRG_FallbackRule rule = new MRG_FallbackRule();
		rule.objectName = 'Contact';
		rule.label = 'bad fb';
		rule.selectionType = 'complex';
		rule.filterLogic = '1 AND 7'; // references condition 7 with only 1 condition
		rule.conditions = new List<MRG_KeepRecordRule.condition>{ new MRG_KeepRecordRule.condition('Email','equals','x@test.com') };
		rule.fieldPairs = new List<MRG_FallbackRule.fieldPair>{ new MRG_FallbackRule.fieldPair('Email','Description') };

		Boolean threw = false;
		try {
			MRG_FallbackRules_CTRL.saveFallbackRules(JSON.serialize(new List<MRG_FallbackRule>{ rule }));
		} catch(AuraHandledException e) {
			threw = true;
		}
		system.assert(threw, 'invalid complex filter logic should raise an AuraHandledException');
	}
}
