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

	// ---- #97: orphaned household merge after a Contact merge ----

	/*******************************************************************************************************
	* @description injects record type developer names by Account id so the tests run in orgs without
	* Account record types; accounts not in the map have no record type
	*/
	private static void setRecordTypes(Map<Id,String> developerNameById) {
		MRG_AccountMerge_SVC.recordTypeDeveloperNameById = developerNameById;
		MRG_Merge_SVC.mergeFields = new List<MergeFieldSetting__mdt>();
		MRG_Merge_SVC.previewFields = new List<PreviewFields__mdt>();
	}

	/*******************************************************************************************************
	* @description merges C2 into C1 through the UI entry point and returns the contact candidate
	*/
	private static MergeCandidate__c mergeContacts(Contact keep, Contact merged) {
		MergeCandidate__c candidate = MRG_TestFactory.mergeCandidate(keep.Id, merged.Id, 'Contact');
		Test.startTest();
		MRG_DuplicateMerge_CTRL.mergeRecord(candidate.Id);
		Test.stopTest();
		return [SELECT Status__c FROM MergeCandidate__c WHERE Id=:candidate.Id];
	}

	private static Boolean accountExists(Id accountId) {
		return [SELECT count() FROM Account WHERE Id=:accountId] == 1;
	}

	private static List<MergeCandidate__c> orphanCandidates() {
		return [SELECT KeepRecordId__c, MergeRecordId__c, Status__c FROM MergeCandidate__c
			WHERE Object__c='Account' AND Rule__c=:MRG_AccountMerge_SVC.RULE_ORPHANED_HOUSEHOLD];
	}

	static testMethod void testOrphanedHouseholdMergedWithDefaultSetting() {
		// no MergeControlSettings__c: the default record type list applies (case-insensitive)
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'household_account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };

		MergeCandidate__c contactCandidate = mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'the orphaned household is merged away');
		system.assertEquals(accts[0].Id, [SELECT AccountId FROM Contact WHERE Id=:c1.Id].AccountId, 'kept contact stays on H1');
		List<MergeCandidate__c> accountCandidates = orphanCandidates();
		system.assertEquals(1, accountCandidates.size(), 'one auditable Account candidate');
		system.assertEquals(String.valueOf(accts[0].Id), accountCandidates[0].KeepRecordId__c);
		system.assertEquals(String.valueOf(accts[1].Id), accountCandidates[0].MergeRecordId__c);
		system.assertEquals('Processed', accountCandidates[0].Status__c);
		system.assertEquals('Processed', contactCandidate.Status__c);
	}

	static testMethod void testOrphanedHouseholdWithOtherContactNotMerged() {
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2, c3 };

		MergeCandidate__c contactCandidate = mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'H2 still has C3 so it is not merged');
		system.assertEquals(0, orphanCandidates().size());
		system.assertEquals('Processed', contactCandidate.Status__c);
	}

	static testMethod void testOrphanedHouseholdSettingNoneTurnsOff() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), AutoMergeOrphanedHouseholds__c='NONE');
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };

		mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'NONE matches no record type');
		system.assertEquals(0, orphanCandidates().size());
	}

	static testMethod void testKeptAccountTypeNotListedNotMerged() {
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'Business_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };

		mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'kept account type is not listed');
		system.assertEquals(0, orphanCandidates().size());
	}

	static testMethod void testKeptAccountWithoutRecordTypeNotMerged() {
		List<Account> accts = MRG_TestFactory.accounts(2);
		// H1 has no record type (not in the map)
		setRecordTypes(new Map<Id,String>{ accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };

		mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'an account without a record type never matches');
		system.assertEquals(0, orphanCandidates().size());
	}

	static testMethod void testSameAccountNoOrphanMerge() {
		List<Account> accts = MRG_TestFactory.accounts(1);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[0].Id);
		insert new List<Contact>{ c1, c2 };

		MergeCandidate__c contactCandidate = mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[0].Id));
		system.assertEquals(0, orphanCandidates().size());
		system.assertEquals('Processed', contactCandidate.Status__c);
	}

	static testMethod void testOrphanedHouseholdRecordTypesParsing() {
		Set<String> defaults = MRG_Merge_SVC.getOrphanedHouseholdRecordTypes();
		system.assertEquals(new Set<String>{ 'household_account', 'hh_account', 'household', 'individual' }, defaults,
			'blank setting falls back to the default list');
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), AutoMergeOrphanedHouseholds__c=' Family , HH_Account ,,');
		system.assertEquals(new Set<String>{ 'family', 'hh_account' }, MRG_Merge_SVC.getOrphanedHouseholdRecordTypes(),
			'values are trimmed and lower-cased');
	}
}
