/**
* @author tj@tjgriffin.com
* @group Merge
* @description covers every field-preservation rule for both Accounts and Contacts, driven through
* the production service path via MRG_TestFactory. Each test asserts the resulting kept value and,
* where the value changes, the recorded MergeFieldHistory__c entry.
*/
@isTest
private class MRG_Preservation_TEST {

	// ---- Contact rules ------------------------------------------------------------------------

	static testMethod void testContactOldest() {
		// keep is the NEWER record; Oldest rule should pull the older (merged) record's value
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;   // newer
		Id mergeId = cons[1].Id;  // older
		MRG_TestFactory.setCreatedDate(keepId, Datetime.now().addDays(-1));
		MRG_TestFactory.setCreatedDate(mergeId, Datetime.now().addDays(-30));
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='NEW'),
			new Contact(Id=mergeId, MailingState='OLD')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','MailingState','Preserve','Oldest')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('OLD', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'Oldest rule should keep the older record value');
		system.assert(MRG_TestFactory.historyByField(keepId).containsKey('mailingstate'),
			'changed preserved field should be tracked');
	}

	static testMethod void testContactNewest() {
		// keep is the OLDER record; Newest rule should pull the newer (merged) record's value
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;   // older
		Id mergeId = cons[1].Id;  // newer
		MRG_TestFactory.setCreatedDate(keepId, Datetime.now().addDays(-30));
		MRG_TestFactory.setCreatedDate(mergeId, Datetime.now().addDays(-1));
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='OLD'),
			new Contact(Id=mergeId, MailingState='NEW')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','MailingState','Preserve','Newest')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('NEW', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'Newest rule should keep the newer record value');
	}

	static testMethod void testContactLargestText() {
		// Largest text: merged value 'ZZZ' > kept 'AAA' so merged wins
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='AAA'),
			new Contact(Id=mergeId, MailingState='ZZZ')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','MailingState','Preserve','Largest')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('ZZZ', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'Largest rule should keep the lexically larger value');
	}

	static testMethod void testContactSmallestDate() {
		// Smallest date: merged Birthdate earlier than kept so merged wins
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, Birthdate=Date.newInstance(2000,1,1)),
			new Contact(Id=mergeId, Birthdate=Date.newInstance(1980,1,1))
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','Birthdate','Preserve','Smallest')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals(Date.newInstance(1980,1,1), (Date) MRG_TestFactory.keptValue(keepId,'Contact','Birthdate'),
			'Smallest rule should keep the earlier date');
	}

	static testMethod void testContactRelatedField() {
		// Related field: MailingState is the master (Newest), MailingPostalCode follows it from the
		// same (newer) record rather than being evaluated independently
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;   // older
		Id mergeId = cons[1].Id;  // newer
		MRG_TestFactory.setCreatedDate(keepId, Datetime.now().addDays(-30));
		MRG_TestFactory.setCreatedDate(mergeId, Datetime.now().addDays(-1));
		update new List<Contact>{
			new Contact(Id=keepId, MailingState='OLD', MailingPostalCode='00000'),
			new Contact(Id=mergeId, MailingState='NEW', MailingPostalCode='99999')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Contact','MailingState','Preserve','Newest'),
			MRG_TestFactory.mergeField('Contact','MailingPostalCode','Preserve','Related Field','MailingState')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('NEW', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'master field should take the newest value');
		system.assertEquals('99999', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingPostalCode'),
			'related field should follow the master record (same newer record)');
	}

	static testMethod void testContactDefaultFillsBlank() {
		// no setting for the field: a blank kept value is filled from the merged record
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, MailingState=null),
			new Contact(Id=mergeId, MailingState='FILLED')
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>());
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals('FILLED', (String) MRG_TestFactory.keptValue(keepId,'Contact','MailingState'),
			'blank kept value should be filled from the merged record by default');
	}

	static testMethod void testContactDefaultBooleanPreserved() {
		// no setting: a true on the merged record is preserved over false on the kept record
		List<Contact> cons = MRG_TestFactory.contacts(2);
		Id keepId = cons[0].Id;
		Id mergeId = cons[1].Id;
		update new List<Contact>{
			new Contact(Id=keepId, HasOptedOutOfEmail=false),
			new Contact(Id=mergeId, HasOptedOutOfEmail=true)
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>());
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Contact');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Contact');
		Test.stopTest();

		system.assertEquals(true, (Boolean) MRG_TestFactory.keptValue(keepId,'Contact','HasOptedOutOfEmail'),
			'a true boolean on the merged record should be preserved over a false kept value');
	}

	// ---- Account rules (numeric) --------------------------------------------------------------

	static testMethod void testAccountLargestNumber() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		Id keepId = accs[0].Id;
		Id mergeId = accs[1].Id;
		update new List<Account>{
			new Account(Id=keepId, NumberOfEmployees=10),
			new Account(Id=mergeId, NumberOfEmployees=500)
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Account','NumberOfEmployees','Preserve','Largest')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Account');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Account');
		Test.stopTest();

		system.assertEquals('500', String.valueOf(MRG_TestFactory.keptValue(keepId,'Account','NumberOfEmployees')),
			'Largest rule should keep the larger number');
	}

	static testMethod void testAccountSmallestNumber() {
		List<Account> accs = MRG_TestFactory.accounts(2);
		Id keepId = accs[0].Id;
		Id mergeId = accs[1].Id;
		update new List<Account>{
			new Account(Id=keepId, NumberOfEmployees=500),
			new Account(Id=mergeId, NumberOfEmployees=10)
		};
		MRG_TestFactory.registerMergeFields(new List<MergeFieldSetting__mdt>{
			MRG_TestFactory.mergeField('Account','NumberOfEmployees','Preserve','Smallest')
		});
		MergeCandidate__c mc = MRG_TestFactory.mergeCandidate(keepId, mergeId, 'Account');

		Test.startTest();
		MRG_TestFactory.runMerge(new List<MergeCandidate__c>{ mc }, 'Account');
		Test.stopTest();

		system.assertEquals('10', String.valueOf(MRG_TestFactory.keptValue(keepId,'Account','NumberOfEmployees')),
			'Smallest rule should keep the smaller number');
	}
}
