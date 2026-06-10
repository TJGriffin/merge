/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for #35c: scan-time flagging, the account-merge auto batch, and the manual
* controller entry point
*/
@isTest
private class MRG_AccountMergeFlow_TEST {

	private static MRG_KeepRecordRule.condition cond(String field, String op, String val, String agg) {
		MRG_KeepRecordRule.condition c = new MRG_KeepRecordRule.condition(field, op, val);
		c.aggregator = agg;
		return c;
	}

	// rule: emails differ AND both not opted out, autoMerge = true
	private static void registerAutoRule(Boolean autoMerge) {
		MRG_AutoMergeAccountsRule rule = new MRG_AutoMergeAccountsRule();
		rule.objectName = 'Contact';
		rule.autoMerge = autoMerge;
		rule.filterLogic = '1 AND 2';
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			cond('Email', null, null, 'differ'),
			cond('HasOptedOutOfEmail','equals','false','all')
		};
		MRG_AutoMergeAccountsRule.autoMergeAccountsRules = new List<MRG_AutoMergeAccountsRule>{ rule };
	}

	private static MergeCandidate__c setupTwoContactsOnTwoAccounts(String emailA, Boolean optA, String emailB, Boolean optB) {
		List<Account> accts = MRG_TestFactory.accounts(2);
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', AccountId=accts[0].Id, Email=emailA, HasOptedOutOfEmail=optA),
			new Contact(FirstName='B', LastName='B', AccountId=accts[1].Id, Email=emailB, HasOptedOutOfEmail=optB)
		};
		insert cons;
		return MRG_TestFactory.mergeCandidate(cons[0].Id, cons[1].Id, 'Contact');
	}

	static testMethod void testFlagSetWhenRuleMatches() {
		registerAutoRule(true);
		MergeCandidate__c mc = setupTwoContactsOnTwoAccounts('a@x.com', false, 'b@x.com', false);
		List<MergeCandidate__c> candidates = new List<MergeCandidate__c>{ mc };

		Test.startTest();
		MRG_AccountMerge_SVC.flagAutoMergeAccounts(candidates, 'Contact');
		Test.stopTest();

		system.assertEquals(true, candidates[0].AutoMergeAccounts__c, 'matching candidate should be flagged');
	}

	static testMethod void testFlagNotSetWhenRuleDoesNotMatch() {
		registerAutoRule(true);
		// same email -> 'differ' fails
		MergeCandidate__c mc = setupTwoContactsOnTwoAccounts('same@x.com', false, 'same@x.com', false);
		List<MergeCandidate__c> candidates = new List<MergeCandidate__c>{ mc };

		MRG_AccountMerge_SVC.flagAutoMergeAccounts(candidates, 'Contact');
		system.assertNotEquals(true, candidates[0].AutoMergeAccounts__c, 'non-matching candidate not flagged');
	}

	static testMethod void testFlagNotSetWhenRuleIsManualOnly() {
		registerAutoRule(false); // autoMerge = false
		MergeCandidate__c mc = setupTwoContactsOnTwoAccounts('a@x.com', false, 'b@x.com', false);
		List<MergeCandidate__c> candidates = new List<MergeCandidate__c>{ mc };

		MRG_AccountMerge_SVC.flagAutoMergeAccounts(candidates, 'Contact');
		system.assertNotEquals(true, candidates[0].AutoMergeAccounts__c, 'manual-only rule should not auto-flag');
	}

	static testMethod void testAutoBatchMergesAccounts() {
		registerAutoRule(true);
		MergeCandidate__c mc = setupTwoContactsOnTwoAccounts('a@x.com', false, 'b@x.com', false);
		// flag it (as the scan would) and persist
		mc.AutoMergeAccounts__c = true;
		update mc;
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>();
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		Test.startTest();
		Database.executeBatch(new MRG_AccountMerge_BATCH());
		Test.stopTest();

		// one of the two accounts should be merged away
		system.assertEquals(1, [SELECT count() FROM Account WHERE IsDeleted=true ALL ROWS],
			'the auto batch should merge one account into the other');
		// contacts survive
		system.assertEquals(2, [SELECT count() FROM Contact WHERE IsDeleted=false],
			'contacts are kept');
		// candidate marked accounts merged
		system.assertEquals(MRG_AccountMerge_SVC.STATUS_ACCOUNTS_MERGED,
			[SELECT Status__c FROM MergeCandidate__c WHERE Id=:mc.Id].Status__c);
	}

	static testMethod void testManualControllerEntry() {
		MergeCandidate__c mc = setupTwoContactsOnTwoAccounts('a@x.com', false, 'b@x.com', false);
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>();
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		Test.startTest();
		String response = MRG_DuplicateMerge_CTRL.mergeAccounts(mc.Id);
		Test.stopTest();

		system.assertEquals('Accounts merged', response);
		system.assertEquals(1, [SELECT count() FROM Account WHERE IsDeleted=true ALL ROWS]);
		system.assertEquals(2, [SELECT count() FROM Contact WHERE IsDeleted=false]);
	}
}
