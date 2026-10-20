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

	private static List<MergeCandidate__c> memberCandidates() {
		return [SELECT KeepRecordId__c, MergeRecordId__c, Status__c FROM MergeCandidate__c
			WHERE Object__c='Account' AND Rule__c=:MRG_AccountMerge_SVC.RULE_HOUSEHOLD_WITH_MEMBERS];
	}

	/*******************************************************************************************************
	* @description two households (HH_Account): C1 alone in H1, C2 with the other members in H2
	*/
	private static List<Account> twoHouseholds() {
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		return accts;
	}

	static testMethod void testHouseholdWithMembersMergedWhenSet() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true);
		List<Account> accts = twoHouseholds();
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2, c3 };

		MergeCandidate__c contactCandidate = mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'H2 is merged although C3 still lived there');
		system.assertEquals(accts[0].Id, [SELECT AccountId FROM Contact WHERE Id=:c3.Id].AccountId, 'C3 moved to the kept household');
		system.assertEquals(accts[0].Id, [SELECT AccountId FROM Contact WHERE Id=:c1.Id].AccountId, 'kept contact stays on H1');
		system.assertEquals(0, orphanCandidates().size(), 'not logged as an orphan merge');
		List<MergeCandidate__c> accountCandidates = memberCandidates();
		system.assertEquals(1, accountCandidates.size(), 'one auditable Account candidate with the member rule');
		system.assertEquals(String.valueOf(accts[0].Id), accountCandidates[0].KeepRecordId__c);
		system.assertEquals(String.valueOf(accts[1].Id), accountCandidates[0].MergeRecordId__c);
		system.assertEquals('Processed', accountCandidates[0].Status__c);
		system.assertEquals('Processed', contactCandidate.Status__c);
	}

	static testMethod void testHouseholdWithMembersNotMergedWhenKeptTypeNotListed() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true);
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'Business_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2, c3 };

		mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'record types still gate the member merge');
		system.assertEquals(0, memberCandidates().size());
	}

	static testMethod void testHouseholdWithMembersMaxOtherMembers() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true, MergeHouseholdsMaxOtherMembers__c=1);
		List<Account> accts = twoHouseholds();
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id);
		Contact c4 = new Contact(FirstName='C', LastName='Four', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2, c3, c4 };

		mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'two other members exceed the limit of one');
		system.assertEquals(0, memberCandidates().size());
		system.assertEquals(accts[1].Id, [SELECT AccountId FROM Contact WHERE Id=:c3.Id].AccountId, 'C3 stays in H2');
	}

	static testMethod void testHouseholdWithMembersWithinMaxOtherMembersMerged() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true, MergeHouseholdsMaxOtherMembers__c=2);
		List<Account> accts = twoHouseholds();
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id);
		Contact c4 = new Contact(FirstName='C', LastName='Four', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2, c3, c4 };

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'two other members are within the limit of two');
		system.assertEquals(1, memberCandidates().size());
		system.assertEquals(2, [SELECT count() FROM Contact WHERE AccountId=:accts[0].Id AND Id IN (:c3.Id, :c4.Id)], 'both members moved');
	}

	static testMethod void testHouseholdWithMembersRequireSameAddressMismatchNotMerged() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true, MergeHouseholdsRequireSameAddress__c=true);
		List<Account> accts = twoHouseholds();
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id, MailingStreet='1 Main St', MailingPostalCode='12345');
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id, MailingStreet='1 Main St', MailingPostalCode='12345');
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id, MailingStreet='2 Other St', MailingPostalCode='12345');
		insert new List<Contact>{ c1, c2, c3 };

		mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'C3 lives at another address');
		system.assertEquals(0, memberCandidates().size());
	}

	static testMethod void testHouseholdWithMembersRequireSameAddressMatchMerged() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true, MergeHouseholdsRequireSameAddress__c=true);
		List<Account> accts = twoHouseholds();
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id, MailingStreet='1 Main St.\n# E-203', MailingPostalCode='12345-6789');
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id, MailingStreet='1 Main St.\n# E-203', MailingPostalCode='12345-6789');
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id, MailingStreet='1  MAIN ST', MailingPostalCode='12345');
		insert new List<Contact>{ c1, c2, c3 };

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'same street line and ZIP5 despite case, punctuation, line 2 and ZIP+4');
		system.assertEquals(1, memberCandidates().size());
		system.assertEquals(accts[0].Id, [SELECT AccountId FROM Contact WHERE Id=:c3.Id].AccountId, 'C3 moved to the kept household');
	}

	static testMethod void testHouseholdWithMembersRequireSameAddressBlankKeptNotMerged() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true, MergeHouseholdsRequireSameAddress__c=true);
		List<Account> accts = twoHouseholds();
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		Contact c3 = new Contact(FirstName='B', LastName='Three', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2, c3 };

		mergeContacts(c1, c2);

		system.assertEquals(true, accountExists(accts[1].Id), 'a kept contact without a street never matches');
		system.assertEquals(0, memberCandidates().size());
	}

	static testMethod void testHouseholdWithMembersStillMergesOrphans() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), MergeHouseholdsWithMembers__c=true, MergeHouseholdsRequireSameAddress__c=true, MergeHouseholdsMaxOtherMembers__c=0);
		List<Account> accts = twoHouseholds();
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'an emptied household is merged as before, whatever the member settings');
		system.assertEquals(1, orphanCandidates().size());
		system.assertEquals(0, memberCandidates().size());
	}

	static testMethod void testAddressKeyNormalization() {
		system.assertEquals('1 main st|12345', MRG_AccountMerge_SVC.addressKey('1 Main St.\r\n# E-203', '12345-6789'));
		system.assertEquals('1 main st|12345', MRG_AccountMerge_SVC.addressKey('  1   MAIN  ST ', '12345'));
		system.assertEquals('1 main st|', MRG_AccountMerge_SVC.addressKey('1 Main St', null));
		system.assertEquals(null, MRG_AccountMerge_SVC.addressKey(null, '12345'));
		system.assertEquals(null, MRG_AccountMerge_SVC.addressKey(' ', '12345'));
		system.assertEquals(null, MRG_AccountMerge_SVC.addressKey('---', '12345'));
	}

	static testMethod void testCanMergeWithMembersGuards() {
		Account household = new Account(Name='H');
		Contact kept = new Contact(LastName='Kept', MailingStreet='1 Main St', MailingPostalCode='12345');
		system.assertEquals(false, MRG_AccountMerge_SVC.canMergeWithMembers(household, kept, false, false, null), 'setting off');
		system.assertEquals(false, MRG_AccountMerge_SVC.canMergeWithMembers(household, null, true, false, null), 'no kept contact');
		system.assertEquals(false, MRG_AccountMerge_SVC.canMergeWithMembers(null, kept, true, false, null), 'no household');
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

	static testMethod void testOrphanedHouseholdMergeDisablesNpspTriggersWhenSet() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), DisableNpspTriggersOnOrphanMerge__c=true);
		MRG_Npsp_TEST.CallableMock npsp = MRG_Npsp_TEST.mockNpsp();
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'the orphaned household is merged away');
		system.assertEquals(new List<String>{ MRG_Npsp_SVC.ACTION_DISABLE_ALL_TRIGGERS }, npsp.actions,
			'NPSP triggers are disabled once before the Account merge');
	}

	static testMethod void testOrphanedHouseholdMergeLeavesNpspTriggersByDefault() {
		MRG_Npsp_TEST.CallableMock npsp = MRG_Npsp_TEST.mockNpsp();
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'the orphaned household is merged away');
		system.assertEquals(0, npsp.actions.size(), 'NPSP triggers are untouched when the setting is off');
	}

	static testMethod void testNoOrphanMergeLeavesNpspTriggers() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), DisableNpspTriggersOnOrphanMerge__c=true);
		MRG_Npsp_TEST.CallableMock npsp = MRG_Npsp_TEST.mockNpsp();
		List<Account> accts = MRG_TestFactory.accounts(1);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id);
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[0].Id);
		insert new List<Contact>{ c1, c2 };

		mergeContacts(c1, c2);

		system.assertEquals(0, npsp.actions.size(), 'NPSP triggers are only disabled when a household is merged');
	}

	static testMethod void testOrphanedHouseholdMergeResetsDefaultAddressWhenSet() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), DisableNpspTriggersOnOrphanMerge__c=true, ResetDefaultAddressOnOrphanMerge__c=true);
		MRG_Npsp_TEST.mockNpsp();
		MRG_NpspAddress_TEST.FakeStore store = MRG_NpspAddress_TEST.mockStore();
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id, MailingStreet='1 Kept St');
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };
		store.add(accts[0].Id, '9 Old Rd', true);
		MRG_NpspAddress_SVC.Address orphanAddress = store.add(accts[1].Id, '1 Kept St', true);

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'the orphaned household is merged away');
		system.assertEquals(false, orphanAddress.isDefault, 'the orphan household address is no longer default');
		List<MRG_NpspAddress_SVC.Address> defaults = new List<MRG_NpspAddress_SVC.Address>();
		for(MRG_NpspAddress_SVC.Address address:store.addresses) {
			if(address.accountId == accts[0].Id && address.isDefault == true)
				defaults.add(address);
		}
		system.assertEquals(1, defaults.size(), 'the kept household has a single default address');
		system.assertEquals('1 Kept St', defaults[0].street, 'the kept contact address is the default');
		system.assert(store.currentAddressByContactId.containsKey(c1.Id), 'the kept contact current address is set');
		system.assertEquals('1 Kept St', [SELECT BillingStreet FROM Account WHERE Id=:accts[0].Id].BillingStreet,
			'the household billing address follows the default address');
	}

	static testMethod void testOrphanedHouseholdMergeClearsOrphanDefaultOnly() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), DisableNpspTriggersOnOrphanMerge__c=true);
		MRG_Npsp_TEST.mockNpsp();
		MRG_NpspAddress_TEST.FakeStore store = MRG_NpspAddress_TEST.mockStore();
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id, MailingStreet='1 Kept St');
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };
		MRG_NpspAddress_SVC.Address keptAddress = store.add(accts[0].Id, '9 Old Rd', true);
		MRG_NpspAddress_SVC.Address orphanAddress = store.add(accts[1].Id, '1 Kept St', true);

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'the orphaned household is merged away');
		system.assertEquals(false, orphanAddress.isDefault, 'the orphan household default is cleared');
		system.assertEquals(true, keptAddress.isDefault, 'the kept household default is left as it was');
		system.assert(store.currentAddressByContactId.isEmpty(), 'the default address is not reset when the setting is off');
	}

	static testMethod void testOrphanedHouseholdMergeLeavesAddressesWhenNpspTriggersOn() {
		insert new MergeControlSettings__c(SetupOwnerId=UserInfo.getOrganizationId(), ResetDefaultAddressOnOrphanMerge__c=true);
		MRG_Npsp_TEST.mockNpsp();
		MRG_NpspAddress_TEST.FakeStore store = MRG_NpspAddress_TEST.mockStore();
		List<Account> accts = MRG_TestFactory.accounts(2);
		setRecordTypes(new Map<Id,String>{ accts[0].Id => 'HH_Account', accts[1].Id => 'HH_Account' });
		Contact c1 = new Contact(FirstName='A', LastName='One', AccountId=accts[0].Id, MailingStreet='1 Kept St');
		Contact c2 = new Contact(FirstName='A', LastName='Two', AccountId=accts[1].Id);
		insert new List<Contact>{ c1, c2 };
		store.add(accts[0].Id, '9 Old Rd', true);
		MRG_NpspAddress_SVC.Address orphanAddress = store.add(accts[1].Id, '1 Kept St', true);

		mergeContacts(c1, c2);

		system.assertEquals(false, accountExists(accts[1].Id), 'the orphaned household is merged away');
		system.assertEquals(true, orphanAddress.isDefault, 'addresses are untouched while the NPSP triggers run');
		system.assertEquals(0, store.saveCalls, 'nothing is saved while the NPSP triggers run');
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
