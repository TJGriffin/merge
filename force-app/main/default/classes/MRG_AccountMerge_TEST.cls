/**
* @author tj@tjgriffin.com
* @group Merge
* @description tests for #35: merging the Accounts behind a Contact merge candidate (contacts survive)
*/
@isTest
private class MRG_AccountMerge_TEST {

	static testMethod void testMergeAccountsKeepsContactsMergesAccounts() {
		List<Account> accts = MRG_TestFactory.accounts(2);
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', AccountId=accts[0].Id),
			new Contact(FirstName='B', LastName='B', AccountId=accts[1].Id)
		};
		insert cons;
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>();
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MergeCandidate__c candidate = MRG_TestFactory.mergeCandidate(cons[0].Id, cons[1].Id, 'Contact');

		Test.startTest();
		Id keepAccountId = MRG_AccountMerge_SVC.mergeAccounts(candidate);
		Test.stopTest();

		system.assertNotEquals(null, keepAccountId, 'an account should survive');

		// both contacts survive (account merge, not contact merge)
		system.assertEquals(2, [SELECT count() FROM Contact WHERE Id IN (:cons[0].Id, :cons[1].Id) AND IsDeleted=false],
			'both contacts should survive');

		// exactly one account survives; the other is merged into it
		system.assertEquals(1, [SELECT count() FROM Account WHERE Id=:keepAccountId AND IsDeleted=false],
			'kept account survives');
		Id otherAccountId = keepAccountId == accts[0].Id ? accts[1].Id : accts[0].Id;
		Account loser = [SELECT IsDeleted, MasterRecordId FROM Account WHERE Id=:otherAccountId ALL ROWS];
		system.assertEquals(true, loser.IsDeleted, 'the other account is merged/deleted');
		system.assertEquals(keepAccountId, loser.MasterRecordId, 'loser points at the surviving account');

		// the originating contact candidate is marked Accounts Merged
		MergeCandidate__c reloaded = [SELECT Status__c, MergeProcessDate__c FROM MergeCandidate__c WHERE Id=:candidate.Id];
		system.assertEquals(MRG_AccountMerge_SVC.STATUS_ACCOUNTS_MERGED, reloaded.Status__c);
		system.assertEquals(Date.today(), reloaded.MergeProcessDate__c);
	}

	static testMethod void testKeepRecordRulesChooseSurvivingAccount() {
		// a keep-record rule on Account picks the survivor regardless of id order
		List<Account> accts = new List<Account>{
			new Account(Name='Keeper', Type='Customer - Direct'),
			new Account(Name='Other', Type='Prospect')
		};
		insert accts;
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', AccountId=accts[0].Id),
			new Contact(FirstName='B', LastName='B', AccountId=accts[1].Id)
		};
		insert cons;
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>();
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();

		MRG_KeepRecordRule rule = new MRG_KeepRecordRule();
		rule.objectName = 'Account';
		rule.order = 1;
		rule.conditions = new List<MRG_KeepRecordRule.condition>{
			new MRG_KeepRecordRule.condition('Type','equals','Customer - Direct')
		};
		MRG_KeepRecordRule.keepRecordRules = new List<MRG_KeepRecordRule>{ rule };

		MergeCandidate__c candidate = MRG_TestFactory.mergeCandidate(cons[0].Id, cons[1].Id, 'Contact');

		Test.startTest();
		Id keepAccountId = MRG_AccountMerge_SVC.mergeAccounts(candidate);
		Test.stopTest();

		system.assertEquals(accts[0].Id, keepAccountId, 'the keep-record rule should select the Customer account');
	}

	static testMethod void testSingleAccountNothingToMerge() {
		// both contacts on the SAME account -> fewer than two distinct accounts -> no merge
		List<Account> accts = MRG_TestFactory.accounts(1);
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', AccountId=accts[0].Id),
			new Contact(FirstName='B', LastName='B', AccountId=accts[0].Id)
		};
		insert cons;
		MergeCandidate__c candidate = MRG_TestFactory.mergeCandidate(cons[0].Id, cons[1].Id, 'Contact');

		Test.startTest();
		Id keepAccountId = MRG_AccountMerge_SVC.mergeAccounts(candidate);
		Test.stopTest();

		system.assertEquals(null, keepAccountId, 'nothing to merge when there is only one distinct account');
		// candidate status unchanged
		system.assertEquals('New', [SELECT Status__c FROM MergeCandidate__c WHERE Id=:candidate.Id].Status__c);
	}

	static testMethod void testGetAccountIdsDeduplicatesAndOrders() {
		List<Account> accts = MRG_TestFactory.accounts(2);
		List<Contact> cons = new List<Contact>{
			new Contact(FirstName='A', LastName='A', AccountId=accts[0].Id),
			new Contact(FirstName='B', LastName='B', AccountId=accts[1].Id)
		};
		insert cons;
		MergeCandidate__c candidate = MRG_TestFactory.mergeCandidate(cons[0].Id, cons[1].Id, 'Contact');
		List<Id> accountIds = MRG_AccountMerge_SVC.getAccountIds(candidate);
		system.assertEquals(2, accountIds.size());
		system.assertEquals(accts[0].Id, accountIds[0], 'keep contact account first');
	}
}
