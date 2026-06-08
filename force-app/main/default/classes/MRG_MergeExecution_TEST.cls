/**
* @author tj@tjgriffin.com
* @group Merge
* @description covers merge execution for Accounts and Contacts through the production service path:
* basic merges with assertions, three-record merges, field tracking, manual overrides, and the
* status/MergeProcessDate transition. Built on MRG_TestFactory.
*/
@isTest
private class MRG_MergeExecution_TEST {

	static testMethod void testContactMergeDeletesLoserAndKeeps() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, LastName='Keep'),
			new Contact(Id=mergeId, LastName='Loser')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>());
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		// keep survives
		system.assertEquals(1, [SELECT count() FROM Contact WHERE Id=:keepId AND IsDeleted=false],
			'kept contact should survive');
		// loser is deleted and points at keep as master
		Contact loser = [SELECT IsDeleted, MasterRecordId FROM Contact WHERE Id=:mergeId ALL ROWS];
		system.assertEquals(true, loser.IsDeleted, 'merged contact should be deleted');
		system.assertEquals(keepId, loser.MasterRecordId, 'merged contact should point at the kept record');
	}

	static testMethod void testAccountMergeDeletesLoserAndKeeps() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		Id keepId = accs[0].Id;
		Id mergeId = accs[1].Id;
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>());
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Account');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Account');
		Test.stopTest();

		system.assertEquals(1, [SELECT count() FROM Account WHERE Id=:keepId AND IsDeleted=false],
			'kept account should survive');
		Account loser = [SELECT IsDeleted, MasterRecordId FROM Account WHERE Id=:mergeId ALL ROWS];
		system.assertEquals(true, loser.IsDeleted, 'merged account should be deleted');
		system.assertEquals(keepId, loser.MasterRecordId, 'merged account should point at the kept record');
	}

	static testMethod void testThreeRecordMerge() {
		List<Account> accs = MRG_TestFactory.accounts(3);
		Id keepId = accs[0].Id;
		Id mergeId = accs[1].Id;
		Id merge2Id = accs[2].Id;
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>());
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, merge2Id, 'Account');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Account');
		Test.stopTest();

		system.assertEquals(1, [SELECT count() FROM Account WHERE Id=:keepId AND IsDeleted=false],
			'kept account should survive');
		system.assertEquals(2, [SELECT count() FROM Account WHERE Id IN (:mergeId,:merge2Id) AND IsDeleted=true ALL ROWS],
			'both merged accounts should be deleted');
	}

	static testMethod void testTrackingWritesHistory() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, Email='keep@test.com'),
			new Contact(Id=mergeId, Email='merge@test.com')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','Email','Track', null)
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		Map<String, MergeFieldHistory__c> history = MRG_TestFactory.historyByField(keepId);
		system.assert(history.containsKey('email'), 'tracked Email change should be recorded');
		MergeFieldHistory__c emailHistory = history.get('email');
		system.assertEquals('keep@test.com', emailHistory.KeptValue__c, 'kept value recorded');
		system.assertEquals('merge@test.com', emailHistory.MergeValue__c, 'merged value recorded');
		system.assertEquals(keepId, emailHistory.KeptRecordId__c, 'kept record id recorded');
	}

	static testMethod void testManualOverrideAppliesAcrossTypes() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>());
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');
		MRG_TestFactory.setOverrides(mc, new List<MRG_MergeCandidate.fieldOverride>{
			MRG_TestFactory.override(keepId, 'MailingState', 'WA', 'STRING'),
			MRG_TestFactory.override(keepId, 'Birthdate', '1990-05-15', 'DATE'),
			MRG_TestFactory.override(keepId, 'HasOptedOutOfEmail', 'true', 'BOOLEAN')
		});
		// re-query so the candidate carries Override__c into the merge
		MergeCandidate__c withOverride = [
			SELECT Id, KeepRecordId__c, MergeRecordId__c, Merge2RecordId__c, Object__c, Status__c, Override__c
			FROM MergeCandidate__c WHERE Id=:mc.Id
		];

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ withOverride }, 'Contact');
		Test.stopTest();

		system.assertEquals('WA', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'string override applied');
		system.assertEquals(Date.newInstance(1990,5,15), (Date) MRG_TestFactory.keptValue(keepId,'Contact','Birthdate'),
			'date override applied from a raw date string (regression for #11)');
		system.assertEquals(true, (Boolean) MRG_TestFactory.keptValue(keepId,'Contact','HasOptedOutOfEmail'),
			'boolean override applied');
	}

	static testMethod void testStatusAndProcessDateTransition() {
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','LastName','Track', null)
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		MergeCandidate__c processed = [
			SELECT Status__c, Data__c, MergeProcessDate__c FROM MergeCandidate__c WHERE Id=:mc.Id
		];
		system.assertEquals('Processed', processed.Status__c, 'candidate should be Processed');
		system.assert(String.isNotBlank(processed.Data__c), 'Data__c should be populated with the merge result');
		system.assertEquals(Date.today(), processed.MergeProcessDate__c,
			'MergeProcessDate__c should be set by the MergeCandidate trigger on the Processed transition');
	}
}
