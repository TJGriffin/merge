@isTest
private class MRG_TriggerHandler_TEST {
@testSetup static void setup() {
		List<Account> accs = new List<Account>();
		accs.add(
			new Account(
				Name='test1'
			)
		);
		accs.add(
			new Account(
				Name='test2'
			)
		);
		insert accs;
		List<Contact> cons = new List<Contact>();
		cons.add(
			new Contact(
			FirstName='Test',
			LastName='Test',
			Email='test@test.com',
			MailingCity='Austin',
			MailingState='TX',
			MailingPostalCode='78751',
			Birthdate=Date.Today().addDays(-1200)
			)
		);	
		cons.add(new Contact(
			FirstName='Test1',
			LastName='Test1',
			Email='tes1t@test.com',
			MailingStreet='123 Main Street',
			MailingState='CA',
			MailingPostalCode='78754',
			HasOptedOutOfEmail=true,
			Birthdate=Date.Today().addDays(-500)
			)
		);	

		insert cons;
        MergeCandidate__c mc = new MergeCandidate__c(
            KeepRecordId__c = cons[0].Id,
            KeepName__c = 'Test',
            MergeRecordId__c = cons[1].Id,
            MergeName__c = 'Test 2',
            Object__c = 'Contact',
            Rule__c = 'test',
            Status__c = 'New',
            AutoMerge__c = true
        );
        insert mc;
	}
    static testMethod void testTrigger() {

        MergeCandidate__c mc = [SELECT Id,KeepRecordId__c,MergeRecordId__c,Status__c FROM MergeCandidate__c LIMIT 1];
        test.startTesT();
        mc.Status__c = 'Processed';
        update mc;
        test.stopTest();
    }
}
