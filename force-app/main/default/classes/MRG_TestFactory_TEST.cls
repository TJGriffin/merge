/**
* @author tj@tjgriffin.com
* @group Merge
* @description exercises MRG_TestFactory end-to-end so the shared harness is self-covering and
* proves a merge can be driven through the production service path with assertable results.
*/
@isTest
private class MRG_TestFactory_TEST {

	static testMethod void testHarnessDrivesContactMergeThroughService() {
		// two contacts, oldest first; preserve LastName from the newest, track FirstName
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		MRG_TestFactory.setCreatedDate(keepId, Datetime.now().addDays(-10));
		MRG_TestFactory.setCreatedDate(mergeId, Datetime.now().addDays(-1));

		// give the records distinct values to merge/track
		update new List<Contact>{
			new Contact(Id=keepId, FirstName='Keep', LastName='KeepLast'),
			new Contact(Id=mergeId, FirstName='Merge', LastName='MergeLast')
		};

		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','FirstName','Track', null),
			MRG_TestFactory.mergeField('Contact','LastName','Preserve','Newest')
		});
		MRG_TestFactory.registerPreviewFields(new List<PreviewFields__mdt>{
			MRG_TestFactory.previewField('Contact','Email', true)
		});

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		// the kept record should now hold the newest LastName (preservation rule)
		system.assertEquals('MergeLast', (String) MRG_TestFactory.keptValue(keepId, 'Contact', 'LastName'),
			'Newest preservation rule should bring LastName from the newer record onto the kept record');

		// merge candidate should be processed
		MergeCandidate__c processed = [SELECT Status__c FROM MergeCandidate__c WHERE Id=:mc.Id];
		system.assertEquals('Processed', processed.Status__c, 'candidate should be marked Processed');

		// history helper should surface the tracked FirstName change
		Map<String, MergeFieldHistory__c> history = MRG_TestFactory.historyByField(keepId);
		system.assert(history.containsKey('firstname'), 'tracked FirstName change should be recorded');
	}

	static testMethod void testOverrideBuilders() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		Id keepId = accs[0].Id;

		MRG_MergeCandidate.fieldOverride o = MRG_TestFactory.fieldOverride(keepId, 'Name', 'Overridden', 'STRING');
		system.assertEquals(keepId, o.keepId);
		system.assertEquals('Name', o.fieldName);
		system.assertEquals('Overridden', o.fieldValue);
		system.assertEquals('STRING', o.fieldType);

		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, accs[1].Id, 'Account');
		MRG_TestFactory.setOverrides(mc, new List<MRG_MergeCandidate.fieldOverride>{ o });
		MergeCandidate__c reloaded = [SELECT Override__c FROM MergeCandidate__c WHERE Id=:mc.Id];
		system.assert(String.isNotBlank(reloaded.Override__c), 'override JSON should be persisted on the candidate');
	}

	static testMethod void testRelatedFieldBuilder() {
		// just exercises the related-field overload of mergeField
		MergeFieldSetting__mdt mf = MRG_TestFactory.mergeField('Contact','MailingState','Preserve','Related Field','MailingPostalCode');
		system.assertEquals('MailingState', mf.Field__r.QualifiedAPIName);
		system.assertEquals('MailingPostalCode', mf.RelatedField__r.QualifiedAPIName);
		system.assertEquals('Contact', mf.Object__r.QualifiedAPIName);
	}
}
